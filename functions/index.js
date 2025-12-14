/**
 * Firebase Cloud Functions for CutLine FCM Notifications
 *
 * Handles:
 * 1. onBookingCreate - Notifies salon owner when new booking is created
 * 2. onBookingUpdate - Notifies user and barber when booking status changes
 */

const {onDocumentCreated, onDocumentUpdated} =
  require("firebase-functions/v2/firestore");
const {onSchedule} = require("firebase-functions/v2/scheduler");
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

      // Handle turn_ready status change
      if (beforeStatus !== "waiting" && afterStatus === "turn_ready") {
        logger.log(
            `Booking ${bookingId} status change: ` +
            `${beforeStatus} -> ${afterStatus}, sending turn_ready notification`,
        );
        try {
          const customerUid = afterData.customerUid ||
            afterData.customerId ||
            afterData.uid;
          if (customerUid) {
            await notifyTurnReady(customerUid, bookingId, salonId);
          }
          // Set turnReadyAt timestamp and schedule auto-cancel
          await admin.firestore()
              .collection("salons")
              .doc(salonId)
              .collection("bookings")
              .doc(bookingId)
              .update({
                turnReadyAt: admin.firestore.FieldValue.serverTimestamp(),
              });
          // Also update queue if exists
          await admin.firestore()
              .collection("salons")
              .doc(salonId)
              .collection("queue")
              .doc(bookingId)
              .set({
                turnReadyAt: admin.firestore.FieldValue.serverTimestamp(),
              }, {merge: true});
        } catch (error) {
          logger.error("Error in turn_ready notification:", error);
        }
        return null;
      }

      // Handle arrived status change
      if (beforeStatus === "turn_ready" && afterStatus === "arrived") {
        logger.log(
            `Booking ${bookingId} status change: ` +
            `${beforeStatus} -> ${afterStatus}, customer arrived`,
        );
        try {
          // Set arrivalTime timestamp
          await admin.firestore()
              .collection("salons")
              .doc(salonId)
              .collection("bookings")
              .doc(bookingId)
              .update({
                arrived: true,
                arrivalTime: admin.firestore.FieldValue.serverTimestamp(),
              });
          // Also update queue if exists
          await admin.firestore()
              .collection("salons")
              .doc(salonId)
              .collection("queue")
              .doc(bookingId)
              .set({
                arrived: true,
                arrivalTime: admin.firestore.FieldValue.serverTimestamp(),
              }, {merge: true});
        } catch (error) {
          logger.error("Error updating arrived status:", error);
        }
        return null;
      }

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
 * Notify customer when their turn is ready
 * @param {string} customerUid - The customer's user ID
 * @param {string} bookingId - The booking ID
 * @param {string} salonId - The salon ID
 */
async function notifyTurnReady(customerUid, bookingId, salonId) {
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

    // Get salon name
    const salonDoc = await admin.firestore()
        .collection("salons")
        .doc(salonId)
        .get();
    const salonName = salonDoc.exists ? (salonDoc.data().name || "Salon") : "Salon";

    // Save notification to Firestore
    await admin.firestore().collection("notifications").add({
      userId: customerUid,
      type: "turn_ready",
      title: "Your turn is ready",
      body: "Confirm within 3 minutes.",
      bookingId: bookingId,
      salonId: salonId,
      salonName: salonName,
      isRead: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const message = {
      notification: {
        title: "Your turn is ready",
        body: "Confirm within 3 minutes.",
      },
      data: {
        type: "turn_ready",
        bookingId: bookingId,
        salonId: salonId,
        salonName: salonName,
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
        `Sent turn_ready notification to user ${customerUid}: ` +
        `${response.successCount} successful, ${response.failureCount} failed`,
    );
  } catch (error) {
    logger.error(`Error notifying turn_ready to user ${customerUid}:`, error);
  }
}

/**
 * Auto-cancel bookings that haven't been confirmed within 3 minutes
 * Runs every minute to check for expired turn_ready bookings
 */
exports.checkTurnReadyExpiry = onSchedule("every 1 minutes", async (event) => {
  try {
    logger.log("Checking for expired turn_ready bookings...");
    const now = admin.firestore.Timestamp.now();
    const threeMinutesAgo = admin.firestore.Timestamp.fromMillis(
        now.toMillis() - 3 * 60 * 1000,
    );

    // Query all salons' bookings with turn_ready status
    const salonsSnapshot = await admin.firestore()
        .collection("salons")
        .get();

    let cancelledCount = 0;
    for (const salonDoc of salonsSnapshot.docs) {
      const salonId = salonDoc.id;
      const bookingsSnapshot = await admin.firestore()
          .collection("salons")
          .doc(salonId)
          .collection("bookings")
          .where("status", "==", "turn_ready")
          .get();

      for (const bookingDoc of bookingsSnapshot.docs) {
        const bookingData = bookingDoc.data();
        const turnReadyAt = bookingData.turnReadyAt;

        if (turnReadyAt && turnReadyAt.toMillis() < threeMinutesAgo.toMillis()) {
          // Check if customer has not arrived
          if (!bookingData.arrived) {
            logger.log(
                `Auto-cancelling booking ${bookingDoc.id} - no response within 3 minutes`,
            );
            await cancelBookingAndPromoteNext(salonId, bookingDoc.id, "no_show");
            cancelledCount++;
          }
        }
      }
    }

    logger.log(`Auto-cancelled ${cancelledCount} expired turn_ready bookings`);
    return null;
  } catch (error) {
    logger.error("Error in checkTurnReadyExpiry:", error);
    return null;
  }
});

/**
 * Auto-cancel bookings where customer arrived but wasn't served within 10 minutes
 * Runs every minute to check for expired arrived bookings
 */
exports.checkArrivalExpiry = onSchedule("every 1 minutes", async (event) => {
  try {
    logger.log("Checking for expired arrived bookings...");
    const now = admin.firestore.Timestamp.now();
    const tenMinutesAgo = admin.firestore.Timestamp.fromMillis(
        now.toMillis() - 10 * 60 * 1000,
    );

    // Query all salons' bookings with arrived status
    const salonsSnapshot = await admin.firestore()
        .collection("salons")
        .get();

    let cancelledCount = 0;
    for (const salonDoc of salonsSnapshot.docs) {
      const salonId = salonDoc.id;
      const bookingsSnapshot = await admin.firestore()
          .collection("salons")
          .doc(salonId)
          .collection("bookings")
          .where("status", "==", "arrived")
          .get();

      for (const bookingDoc of bookingsSnapshot.docs) {
        const bookingData = bookingDoc.data();
        const arrivalTime = bookingData.arrivalTime;

        if (arrivalTime && arrivalTime.toMillis() < tenMinutesAgo.toMillis()) {
          // Check if not yet served
          if (bookingData.status === "arrived" && !bookingData.served) {
            logger.log(
                `Auto-cancelling booking ${bookingDoc.id} - not served within 10 minutes`,
            );
            await cancelBookingAndPromoteNext(salonId, bookingDoc.id, "no_show");
            cancelledCount++;
          }
        }
      }
    }

    logger.log(`Auto-cancelled ${cancelledCount} expired arrived bookings`);
    return null;
  } catch (error) {
    logger.error("Error in checkArrivalExpiry:", error);
    return null;
  }
});

/**
 * Cancel a booking and promote the next customer in queue
 * @param {string} salonId - The salon ID
 * @param {string} bookingId - The booking ID to cancel
 * @param {string} reason - The cancellation reason (e.g., "no_show")
 */
async function cancelBookingAndPromoteNext(salonId, bookingId, reason) {
  try {
    // Update booking status to no_show
    await admin.firestore()
        .collection("salons")
        .doc(salonId)
        .collection("bookings")
        .doc(bookingId)
        .update({
          status: "no_show",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancellationReason: reason,
        });

    // Update queue status
    await admin.firestore()
        .collection("salons")
        .doc(salonId)
        .collection("queue")
        .doc(bookingId)
        .update({
          status: "no_show",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        });

    // Find the next waiting customer and promote to turn_ready
    const nextBookingSnapshot = await admin.firestore()
        .collection("salons")
        .doc(salonId)
        .collection("bookings")
        .where("status", "==", "waiting")
        .orderBy("dateTime", "asc")
        .limit(1)
        .get();

    if (!nextBookingSnapshot.empty) {
      const nextBooking = nextBookingSnapshot.docs[0];
      const nextBookingId = nextBooking.id;

      logger.log(`Promoting booking ${nextBookingId} to turn_ready`);

      // Update to turn_ready
      await admin.firestore()
          .collection("salons")
          .doc(salonId)
          .collection("bookings")
          .doc(nextBookingId)
          .update({
            status: "turn_ready",
            turnReadyAt: admin.firestore.FieldValue.serverTimestamp(),
          });

      // Update queue
      await admin.firestore()
          .collection("salons")
          .doc(salonId)
          .collection("queue")
          .doc(nextBookingId)
          .set({
            status: "turn_ready",
            turnReadyAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});

      // Send notification to next customer
      const nextBookingData = nextBooking.data();
      const customerUid = nextBookingData.customerUid ||
        nextBookingData.customerId ||
        nextBookingData.uid;
      if (customerUid) {
        await notifyTurnReady(customerUid, nextBookingId, salonId);
      }
    } else {
      logger.log("No next customer to promote");
    }
  } catch (error) {
    logger.error(`Error cancelling booking and promoting next:`, error);
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
