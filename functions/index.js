/**
 * Firebase Cloud Functions for CutLine FCM Notifications
 *
 * Handles:
 * 1. onBookingCreate - Notifies salon owner when new booking is created
 * 2. onBookingUpdate - Notifies user and barber when booking status changes
 */

const {onDocumentCreated, onDocumentUpdated, onDocumentWritten} =
  require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");
const admin = require("firebase-admin");
const logger = require("firebase-functions/logger");

admin.initializeApp();

// Set global options for all functions
setGlobalOptions({maxInstances: 10});

/**
 * Enforce unique ownership of FCM tokens across user documents.
 *
 * If the same device token is present on multiple users (e.g. shared phone,
 * stale token not removed on logout), push notifications can reach the wrong
 * account. This trigger removes the token from all other users whenever a user
 * writes/updates their token.
 */
exports.onUserFcmTokenWrite = onDocumentWritten(
    "users/{userId}",
    async (event) => {
      const userId = event.params.userId;
      const after = event.data.after;
      if (!after.exists) return null;

      const data = after.data() || {};
      const rawTokens = Array.isArray(data.fcmTokens) ? data.fcmTokens : [];
      const tokens = rawTokens
          .filter((t) => typeof t === "string" && t.length > 0)
          .slice(0, 5); // sanity cap

      // If no array tokens, fall back to single token field.
      if (tokens.length === 0 &&
          typeof data.fcmToken === "string" &&
          data.fcmToken.length > 0) {
        tokens.push(data.fcmToken);
      }

      if (tokens.length === 0) return null;

      try {
        const firestore = admin.firestore();
        const batch = firestore.batch();
        // otherUserId -> {remove:Set, deleteSingle:Set}
        const toClean = new Map();

        for (const token of tokens) {
          const bySingle = await firestore
              .collection("users")
              .where("fcmToken", "==", token)
              .get();
          const byArray = await firestore
              .collection("users")
              .where("fcmTokens", "array-contains", token)
              .get();

          const candidates = [...bySingle.docs, ...byArray.docs];
          for (const doc of candidates) {
            if (doc.id === userId) continue;
            const otherData = doc.data() || {};

            const entry = toClean.get(doc.id) || {
              remove: new Set(),
              deleteSingle: new Set(),
              hasTokensArray: Array.isArray(otherData.fcmTokens),
            };
            entry.remove.add(token);
            if (otherData.fcmToken === token) entry.deleteSingle.add(token);
            toClean.set(doc.id, entry);
          }
        }

        if (toClean.size === 0) return null;

        for (const [otherUserId, entry] of toClean.entries()) {
          const ref = firestore.collection("users").doc(otherUserId);
          const update = {
            fcmTokens: admin.firestore.FieldValue.arrayRemove(
                ...Array.from(entry.remove),
            ),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          // If their single-token field matches one we removed, delete it.
          if (entry.deleteSingle.size > 0) {
            update.fcmToken = admin.firestore.FieldValue.delete();
          }
          batch.update(ref, update);
        }

        await batch.commit();
        logger.log(
            `Deduped FCM token(s) for userId=${userId}; ` +
            `cleaned=${toClean.size}`,
        );
        return null;
      } catch (error) {
        logger.error("Error in onUserFcmTokenWrite:", error);
        return null;
      }
    },
);

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

      // Manual entries are operational queue mirrors; skip push notifications.
      if (
        (bookingData.entrySource || "").toString().toLowerCase() === "manual"
      ) {
        logger.log(
            "Booking " +
            `${bookingId} is manual entry, skipping create notification`,
        );
        return null;
      }

      // Only notify for bookings with status "upcoming"
      if (bookingData.status !== "upcoming") {
        logger.log(
            `Booking ${bookingId} has status ${bookingData.status}, ` +
            "skipping notification",
        );
        return null;
      }

      try {
        const firestore = admin.firestore();

        // Source of truth for routing: the booking path param.
        const bookingSalonId = salonId;
        const bookingSalonIdFromData = bookingData.salonId;
        if (bookingSalonIdFromData &&
            bookingSalonIdFromData !== bookingSalonId) {
          logger.warn(
              `Booking salonId mismatch: path=${bookingSalonId} ` +
              `data=${bookingSalonIdFromData} bookingId=${bookingId}`,
          );
        }

        // Determine the salon owner. Never rely on `users.salonId` as primary,
        // because it can be stale and cause cross-salon notifications.
        let ownerDocs = [];
        let resolvedOwnerId = null;

        // 1) Prefer salon document's ownerId (works for both docId=ownerUid
        // and docId=random where ownerId is stored as a field).
        const salonDoc = await firestore.collection("salons")
            .doc(bookingSalonId)
            .get();
        if (salonDoc.exists) {
          const salonData = salonDoc.data() || {};
          if (salonData.ownerId &&
              typeof salonData.ownerId === "string" &&
              salonData.ownerId.length > 0) {
            resolvedOwnerId = salonData.ownerId;
          }
        } else {
          logger.warn(
              `Salon ${bookingSalonId} not found for bookingId=${bookingId}`,
          );
        }

        // 2) If no ownerId field, try the common pattern docId==ownerUid.
        if (!resolvedOwnerId) {
          resolvedOwnerId = bookingSalonId;
        }

        // 3) Lookup users/{ownerId}.
        const ownerDoc = await firestore.collection("users")
            .doc(resolvedOwnerId)
            .get();
        if (ownerDoc.exists) {
          const data = ownerDoc.data() || {};
          if ((data.role || "").toString().toLowerCase() === "owner") {
            ownerDocs = [ownerDoc];
          } else {
            logger.warn(
                `Resolved ownerId=${resolvedOwnerId} is not role=owner ` +
                `(role=${data.role || "unknown"}) salonId=${bookingSalonId}`,
            );
          }
        } else {
          logger.warn(
              `Owner user doc not found for ownerId=${resolvedOwnerId} ` +
              `(salonId=${bookingSalonId})`,
          );
        }

        // 4) Last resort: legacy mapping users where salonId==salonId.
        // Only used when the above couldn't resolve, to avoid stale mappings.
        if (ownerDocs.length === 0) {
          const ownersBySalonSnap = await firestore
              .collection("users")
              .where("salonId", "==", bookingSalonId)
              .get();
          ownerDocs = ownersBySalonSnap.docs.filter((doc) => {
            const data = doc.data() || {};
            return (data.role || "").toString().toLowerCase() === "owner";
          });
        }

        const customerName = bookingData.customerName || "A customer";
        const title = "New Booking Request";
        const body = `${customerName} has requested a booking`;
        const dataPayload = {
          type: "booking_request",
          bookingId: bookingId,
          salonId: bookingSalonId,
          customerName: customerName || "",
        };

        // Send to each owner doc separately so token cleanup stays correct per
        // owner.
        const results = [];
        logger.log(
            `Resolved booking owners for salonId=${bookingSalonId}:`,
            ownerDocs.map((d) => d.id),
        );
        for (const doc of ownerDocs) {
          const ownerId = doc.id;
          const ownerData = doc.data() || {};
          const fcmTokens = ownerData.fcmTokens ||
            (ownerData.fcmToken ? [ownerData.fcmToken] : []);

          const validTokens = Array.isArray(fcmTokens) ?
            fcmTokens.filter(
                (token) =>
                  token &&
                  typeof token === "string" &&
                  token.length > 0,
            ) :
            [];

          if (validTokens.length === 0) {
            logger.log(
                `No valid FCM tokens for owner ${ownerId} ` +
                `(salonId=${bookingSalonId})`,
            );
            continue;
          }

          // Save notification to Firestore (per owner).
          await firestore.collection("notifications").add({
            userId: ownerId,
            type: "booking_request",
            title,
            body,
            bookingId: bookingId,
            salonId: bookingSalonId,
            customerName: customerName || "",
            isRead: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const message = {
            notification: {title, body},
            data: dataPayload,
            tokens: validTokens,
          };

          const response = await admin.messaging()
              .sendEachForMulticast(message);
          results.push({ownerId, response, validTokens});

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
        }

        if (results.length === 0) {
          logger.log(
              `No owners with tokens to notify for salonId=${bookingSalonId} ` +
              `(bookingId=${bookingId})`,
          );
          return null;
        }

        const successCount = results.reduce(
            (sum, r) => sum + (r.response.successCount || 0),
            0,
        );
        const failureCount = results.reduce(
            (sum, r) => sum + (r.response.failureCount || 0),
            0,
        );

        logger.log(
            "Sent booking request notification:",
            `salonId=${bookingSalonId}`,
            `success=${successCount}`,
            `failed=${failureCount}`,
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

      // Manual entries are queue mirrors, no customer-facing push flow.
      const beforeSource =
        (beforeData.entrySource || "").toString().toLowerCase();
      const afterSource =
        (afterData.entrySource || "").toString().toLowerCase();
      if (beforeSource === "manual" || afterSource === "manual") {
        logger.log(
            "Booking " +
            `${bookingId} is manual entry, skipping update notifications`,
        );
        return null;
      }

      const beforeStatus = (beforeData.status || "").toString().toLowerCase();
      const afterStatus = (afterData.status || "").toString().toLowerCase();

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

// NOTE: Scheduled auto-expiry functions are temporarily removed to avoid
// high read costs. If needed later, reintroduce them with optimized queries.

/**
 * Cancel a booking and promote the next customer in queue
 * @param {string} salonId - The salon ID
 * @param {string} bookingId - The booking ID to cancel
 * @param {string} reason - The cancellation reason (e.g., "no_show")
 */
// cancelBookingAndPromoteNext removed with scheduled expiry functions.

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
