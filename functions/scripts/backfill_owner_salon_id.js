/* eslint-disable no-console */

/**
 * Backfill `users/{ownerUid}.salonId` for owner accounts.
 *
 * Why: Targeted FCM notifications use `.where('salonId' == bookingSalonId)`
 * to find the correct salon owner(s). Older owner profiles may be missing
 * `salonId`.
 *
 * Safety:
 * - Default is dry-run (no writes)
 * - Use `--apply` to perform writes
 *
 * Usage:
 *   node scripts/backfill_owner_salon_id.js --project <projectId> [--apply]
 *     [--service-account <path>] [--batch-size 250]
 *
 * Credentials:
 * - Preferred: `--service-account path/to/serviceAccount.json`
 * - Or set `GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json`
 */

const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");

/**
 * Parse CLI args like `--key value` and `--flag`.
 * @param {string[]} argv
 * @return {Object<string, (string|boolean)>}
 */
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

/**
 * Load a service-account JSON file.
 * @param {string} serviceAccountPath
 * @return {Object}
 */
function loadServiceAccount(serviceAccountPath) {
  const abs = path.resolve(process.cwd(), serviceAccountPath);
  const content = fs.readFileSync(abs, "utf8");
  return JSON.parse(content);
}

/**
 * Entrypoint.
 * @return {Promise<void>}
 */
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
  const modeLabel = apply ? "APPLY (writes enabled)" : "DRY-RUN (no writes)";
  console.log(`Mode: ${modeLabel}`);
  console.log(`Batch size: ${batchSize}`);

  let scanned = 0;
  let toUpdate = 0;
  let updated = 0;
  let skippedAlreadySet = 0;

  let lastDoc = null;

  // Paginate through owners to avoid loading everything at once.
  // Order by docId so `startAfter` is stable.
  let hasMore = true;
  while (hasMore) {
    let query = firestore.collection("users")
        .where("role", "==", "owner")
        .orderBy(admin.firestore.FieldPath.documentId())
        .limit(batchSize);

    if (lastDoc) query = query.startAfter(lastDoc);

    const snap = await query.get();
    if (snap.empty) {
      hasMore = false;
      break;
    }

    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data() || {};
      const currentSalonId = (data.salonId || "").toString().trim();
      const desiredSalonId = doc.id;

      if (currentSalonId === desiredSalonId) {
        skippedAlreadySet++;
        continue;
      }

      // Only backfill when missing/empty by default; allow overwrite via
      // --force.
      if (currentSalonId && !args.force) {
        console.log(
            `SKIP (has salonId): owner=${doc.id} salonId=${currentSalonId}`,
        );
        continue;
      }

      toUpdate++;
      console.log(
          `${apply ? "UPDATE" : "WOULD UPDATE"}: ` +
          `owner=${doc.id} salonId=${desiredSalonId}`,
      );

      if (apply) {
        await firestore.collection("users").doc(doc.id).set(
            {
              salonId: desiredSalonId,
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            {merge: true},
        );
        updated++;
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
  }

  console.log("-----");
  console.log(`Owners scanned: ${scanned}`);
  console.log(`Already correct: ${skippedAlreadySet}`);
  console.log(`Needs update: ${toUpdate}`);
  console.log(`Updated: ${updated}`);
  console.log("Done.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
