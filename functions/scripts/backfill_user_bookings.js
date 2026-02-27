/* eslint-disable */

/**
 * Backfill users/{uid}/bookings from salons/{salonId}/bookings.
 *
 * Why: My Bookings now reads from the user mirror to avoid collectionGroup
 * reads. Older bookings won't exist in the mirror unless backfilled.
 *
 * Safety:
 * - Default is dry-run (no writes)
 * - Use --apply to perform writes
 *
 * Usage:
 *   node scripts/backfill_user_bookings.js --project <projectId> [--apply]
 *     [--service-account <path>] [--batch-size 250] [--limit 0]
 *
 * limit=0 means no limit (process all).
 */

const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i++) {
    const raw = argv[i];
    if (!raw.startsWith("--")) continue;
    const key = raw.slice(2);
    const next = argv[i + 1];
    if (next && !next.startsWith("--")) {
      args[key] = next;
      i++;
    } else {
      args[key] = true;
    }
  }
  return args;
}

function loadServiceAccount(serviceAccountPath) {
  const abs = path.resolve(process.cwd(), serviceAccountPath);
  const content = fs.readFileSync(abs, "utf8");
  return JSON.parse(content);
}

function mapServices(raw) {
  if (!Array.isArray(raw)) return [];
  return raw.map((e) => {
    if (e && typeof e === "object" && typeof e.name === "string") {
      return e.name.trim();
    }
    if (typeof e === "string") return e.trim();
    return "";
  }).filter((s) => s.length > 0);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const projectId = args.project ||
    process.env.FIREBASE_PROJECT ||
    process.env.GCLOUD_PROJECT;
  const serviceAccountPath = args["service-account"];
  const apply = Boolean(args.apply);
  const batchSize = Math.max(
      1,
      Math.min(500, Number(args["batch-size"] || 250)),
  );
  const limit = Number(args.limit || 0);

  if (!projectId) {
    console.error("Missing --project <projectId> (or set GCLOUD_PROJECT).");
    process.exitCode = 2;
    return;
  }

  if (serviceAccountPath) {
    const sa = loadServiceAccount(serviceAccountPath);
    admin.initializeApp({
      projectId,
      credential: admin.credential.cert(sa),
    });
  } else {
    admin.initializeApp({
      projectId,
      credential: admin.credential.applicationDefault(),
    });
  }

  const firestore = admin.firestore();
  console.log(`Project: ${projectId}`);
  console.log(`Mode: ${apply ? "APPLY" : "DRY-RUN"}`);
  console.log(`Batch size: ${batchSize}`);
  if (limit > 0) console.log(`Limit: ${limit}`);

  let processed = 0;
  let mirrored = 0;
  let skipped = 0;

  const salonsSnap = await firestore.collection("salons").get();
  for (const salonDoc of salonsSnap.docs) {
    const salonId = salonDoc.id;
    const bookingsSnap = await firestore
        .collection("salons")
        .doc(salonId)
        .collection("bookings")
        .get();

    let batch = firestore.batch();
    let batchCount = 0;

    for (const bookingDoc of bookingsSnap.docs) {
      processed++;
      if (limit > 0 && processed > limit) break;

      const data = bookingDoc.data() || {};
      const customerUid = (data.customerUid || data.userId || "").toString().trim();
      if (!customerUid) {
        skipped++;
        continue;
      }

      const payload = {
        salonId,
        salonName: (data.salonName || "Salon").toString().trim(),
        services: mapServices(data.services),
        barberName: (data.barberName || "").toString().trim(),
        date: (data.date || "").toString().trim(),
        time: (data.time || "").toString().trim(),
        status: (data.status || "upcoming").toString().trim(),
        customerUid,
        customerEmail: (data.customerEmail || data.email || "").toString().trim(),
        customerPhone: (data.customerPhone || data.phone || "").toString().trim(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (data.dateTime) payload.dateTime = data.dateTime;
      if (data.coverImageUrl) payload.coverImageUrl = data.coverImageUrl;
      if (data.coverPhoto) payload.coverPhoto = data.coverPhoto;
      if (data.customerAvatar) payload.customerAvatar = data.customerAvatar;
      if (data.barberId) payload.barberId = data.barberId;
      if (data.barberAvatar) payload.barberAvatar = data.barberAvatar;

      const mirrorRef = firestore
          .collection("users")
          .doc(customerUid)
          .collection("bookings")
          .doc(bookingDoc.id);

      batch.set(mirrorRef, payload, {merge: true});
      batchCount++;
      if (batchCount >= batchSize) {
        if (apply) await batch.commit();
        mirrored += batchCount;
        batch = firestore.batch();
        batchCount = 0;
      }
    }

    if (batchCount > 0) {
      if (apply) await batch.commit();
      mirrored += batchCount;
    }

    if (limit > 0 && processed > limit) break;
  }

  console.log("-----");
  console.log(`Processed bookings: ${processed}`);
  console.log(`Mirrored: ${mirrored}`);
  console.log(`Skipped (no customerUid): ${skipped}`);
  console.log("Done.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
