/**
 * Firebase Cloud Functions for CutLine FCM Notifications
 *
 * Handles:
 * 1. onBookingCreate - Notifies salon owner when new booking is created
 * 2. onBookingUpdate - Notifies user and barber when booking status changes
 */

const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();

// Set global options for all functions
setGlobalOptions({maxInstances: 10});

/**
 * Triggered when a new booking is created.
 * Path: salons/{salonId}/bookings/{bookingId}
 * Sends notification to the salon owner
 */
exports.onBookingCreate = onDocumentCreated(
    "salons/{salonId}/bookings/{bookingId}",
    async (event) => {
      const bookingData = event.data.data();
      const salonId = event.params.salonId;
      const bookingId = event.params.bookingId;

      // Only notify for bookings with status "upcoming"
      if (bookingData.status !== "upcoming") {
        logger.log(
            `Booking ${bookingId} has status ${bookingData.status}, ` +
            "skipping notification",
        );
        return null;
      }

      try {
        // Get salon document to find ownerId
        const salonDoc = await admin.firestore()
            .collection("salons")
            .doc(salonId)
            .get();
        if (!salonDoc.exists) {
          logger.error(`Salon ${salonId} not found`);
          return null;
        }

        const salonData = salonDoc.data();
        // Fallback to salonId if ownerId not set
        const ownerId = salonData.ownerId || salonId;

        // Get owner's FCM tokens
        const ownerDoc = await admin.firestore()
            .collection("users")
            .doc(ownerId)
            .get();
        if (!ownerDoc.exists) {
          logger.error(`Owner ${ownerId} not found`);
          return null;
        }

        const ownerData = ownerDoc.data();
        const fcmTokens = ownerData.fcmTokens ||
          (ownerData.fcmToken ? [ownerData.fcmToken] : []);

        if (!fcmTokens || fcmTokens.length === 0) {
          logger.log(`No FCM tokens found for owner ${ownerId}`);
          return null;
        }

        // Filter out invalid tokens
        const validTokens = fcmTokens.filter(
            (token) => token && typeof token === "string" && token.length > 0,
        );

        if (validTokens.length === 0) {
          logger.log(`No valid FCM tokens for owner ${ownerId}`);
          return null;
        }

        // Prepare notification payload
        const customerName = bookingData.customerName || "A customer";

        const message = {
          notification: {
            title: "New Booking Request",
            body: `${customerName} has requested a booking`,
          },
          data: {
            type: "booking_request",
            bookingId: bookingId,
            salonId: salonId,
            customerName: customerName || "",
          },
          tokens: validTokens,
        };

        // Save notification to Firestore
        await admin.firestore().collection("notifications").add({
          userId: ownerId,
          type: "booking_request",
          title: "New Booking Request",
          body: `${customerName} has requested a booking`,
          bookingId: bookingId,
          salonId: salonId,
          customerName: customerName || "",
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Send notification
        const response = await admin.messaging().sendEachForMulticast(message);

        // Clean up invalid tokens
        if (response.failureCount > 0) {
          const invalidTokens = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              invalidTokens.push(validTokens[idx]);
            }
          });

          if (invalidTokens.length > 0) {
            await cleanupInvalidTokens(ownerId, invalidTokens);
          }
        }

        logger.log(
            `Sent booking request notification to owner ${ownerId}: ` +
            `${response.successCount} successful, ` +
            `${response.failureCount} failed`,
        );
        return null;
      } catch (error) {
        logger.error("Error in onBookingCreate:", error);
        return null;
      }
    },
);

/**
 * Triggered when a booking is updated.
 * Path: salons/{salonId}/bookings/{bookingId}
 * Sends notifications to user and barber when status changes
 * from "upcoming" to "waiting"
 */
exports.onBookingUpdate = onDocumentUpdated(
    "salons/{salonId}/bookings/{bookingId}",
    async (event) => {
      const beforeData = event.data.before.data();
      const afterData = event.data.after.data();
      const salonId = event.params.salonId;
      const bookingId = event.params.bookingId;

      const beforeStatus = beforeData.status;
      const afterStatus = afterData.status;

      // Only notify when status changes from "upcoming" to "waiting"
      if (beforeStatus !== "upcoming" || afterStatus !== "waiting") {
        logger.log(
            `Booking ${bookingId} status change: ` +
            `${beforeStatus} -> ${afterStatus}, skipping notification`,
        );
        return null;
      }

      try {
        const promises = [];

        // 1. Notify the user (customer)
        const customerUid = afterData.customerUid ||
          afterData.customerId ||
          afterData.uid;
        if (customerUid) {
          promises.push(notifyUser(customerUid, bookingId, salonId));
        }

        // 2. Notify the assigned barber
        const barberName = afterData.barberName;
        if (barberName && barberName !== "Any" && barberName.trim() !== "") {
          promises.push(notifyBarber(salonId, barberName, bookingId));
        }

        await Promise.all(promises);
        logger.log(
            `Sent notifications for booking ${bookingId} ` +
            "status change to waiting",
        );
        return null;
      } catch (error) {
        logger.error("Error in onBookingUpdate:", error);
        return null;
      }
    },
);

/**
 * Notify user when booking is accepted
 * @param {string} customerUid - The customer's user ID
 * @param {string} bookingId - The booking ID
 * @param {string} salonId - The salon ID
 */
async function notifyUser(customerUid, bookingId, salonId) {
  try {
    const userDoc = await admin.firestore()
        .collection("users")
        .doc(customerUid)
        .get();
    if (!userDoc.exists) {
      logger.log(`User ${customerUid} not found`);
      return;
    }

    const userData = userDoc.data();
    const fcmTokens = userData.fcmTokens ||
      (userData.fcmToken ? [userData.fcmToken] : []);

    if (!fcmTokens || fcmTokens.length === 0) {
      logger.log(`No FCM tokens found for user ${customerUid}`);
      return;
    }

    const validTokens = fcmTokens.filter(
        (token) => token && typeof token === "string" && token.length > 0,
    );

    if (validTokens.length === 0) {
      logger.log(`No valid FCM tokens for user ${customerUid}`);
      return;
    }

    // Save notification to Firestore
    await admin.firestore().collection("notifications").add({
      userId: customerUid,
      type: "booking_accepted",
      title: "Booking Accepted",
      body: "Your booking has been accepted!",
      bookingId: bookingId,
      salonId: salonId,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const message = {
      notification: {
        title: "Booking Accepted",
        body: "Your booking has been accepted!",
      },
      data: {
        type: "booking_accepted",
        bookingId: bookingId,
        salonId: salonId,
      },
      tokens: validTokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          invalidTokens.push(validTokens[idx]);
        }
      });

      if (invalidTokens.length > 0) {
        await cleanupInvalidTokens(customerUid, invalidTokens);
      }
    }

    logger.log(
        `Sent booking_accepted notification to user ${customerUid}: ` +
        `${response.successCount} successful, ${response.failureCount} failed`,
    );
  } catch (error) {
    logger.error(`Error notifying user ${customerUid}:`, error);
  }
}

/**
 * Notify barber when booking status changes to waiting
 * @param {string} salonId - The salon ID
 * @param {string} barberName - The barber's name
 * @param {string} bookingId - The booking ID
 */
async function notifyBarber(salonId, barberName, bookingId) {
  try {
    // Get salon document to find ownerId
    const salonDoc = await admin.firestore()
        .collection("salons")
        .doc(salonId)
        .get();
    if (!salonDoc.exists) {
      logger.log(`Salon ${salonId} not found`);
      return;
    }

    const salonData = salonDoc.data();
    const ownerId = salonData.ownerId || salonId;

    // Find barber by name in users collection
    // Barbers have role='barber' and ownerId matching the salon owner
    const barbersSnapshot = await admin.firestore()
        .collection("users")
        .where("role", "==", "barber")
        .where("ownerId", "==", ownerId)
        .get();

    let barberUid = null;
    for (const doc of barbersSnapshot.docs) {
      const barberData = doc.data();
      const name = barberData.name || "";
      // Case-insensitive name matching
      if (name.toLowerCase().trim() === barberName.toLowerCase().trim()) {
        barberUid = doc.id;
        break;
      }
    }

    if (!barberUid) {
      logger.log(`Barber "${barberName}" not found for salon ${salonId}`);
      return;
    }

    // Get barber's FCM tokens
    const barberDoc = await admin.firestore()
        .collection("users")
        .doc(barberUid)
        .get();
    if (!barberDoc.exists) {
      logger.log(`Barber document ${barberUid} not found`);
      return;
    }

    const barberData = barberDoc.data();
    const fcmTokens = barberData.fcmTokens ||
      (barberData.fcmToken ? [barberData.fcmToken] : []);

    if (!fcmTokens || fcmTokens.length === 0) {
      logger.log(`No FCM tokens found for barber ${barberUid}`);
      return;
    }

    const validTokens = fcmTokens.filter(
        (token) => token && typeof token === "string" && token.length > 0,
    );

    if (validTokens.length === 0) {
      logger.log(`No valid FCM tokens for barber ${barberUid}`);
      return;
    }

    // Save notification to Firestore
    await admin.firestore().collection("notifications").add({
      userId: barberUid,
      type: "barber_waiting",
      title: "New Customer Waiting",
      body: "A customer is waiting for you",
      bookingId: bookingId,
      salonId: salonId,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const message = {
      notification: {
        title: "New Customer Waiting",
        body: "A customer is waiting for you",
      },
      data: {
        type: "barber_waiting",
        bookingId: bookingId,
        salonId: salonId,
      },
      tokens: validTokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    // Clean up invalid tokens
    if (response.failureCount > 0) {
      const invalidTokens = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          invalidTokens.push(validTokens[idx]);
        }
      });

      if (invalidTokens.length > 0) {
        await cleanupInvalidTokens(barberUid, invalidTokens);
      }
    }

    logger.log(
        `Sent barber_waiting notification to barber ${barberUid}: ` +
        `${response.successCount} successful, ${response.failureCount} failed`,
    );
  } catch (error) {
    logger.error(`Error notifying barber "${barberName}":`, error);
  }
}

/**
 * Clean up invalid FCM tokens from user document
 * @param {string} userId - The user ID
 * @param {Array<string>} invalidTokens - Array of invalid tokens to remove
 */
async function cleanupInvalidTokens(userId, invalidTokens) {
  try {
    const userDoc = await admin.firestore()
        .collection("users")
        .doc(userId)
        .get();
    if (!userDoc.exists) {
      return;
    }

    const userData = userDoc.data();
    const currentTokens = userData.fcmTokens ||
      (userData.fcmToken ? [userData.fcmToken] : []);

    if (!Array.isArray(currentTokens)) {
      return;
    }

    // Remove invalid tokens
    const updatedTokens = currentTokens.filter(
        (token) => !invalidTokens.includes(token),
    );

    // Update document
    await admin.firestore().collection("users").doc(userId).update({
      fcmTokens: updatedTokens,
    });

    logger.log(
        `Cleaned up ${invalidTokens.length} invalid tokens ` +
        `for user ${userId}`,
    );
  } catch (error) {
    logger.error(`Error cleaning up tokens for user ${userId}:`, error);
  }
}
