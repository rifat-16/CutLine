/* eslint-disable */
const admin = require('firebase-admin');

function parseArgs(argv) {
  const args = {};
  for (let i = 2; i < argv.length; i += 1) {
    const raw = argv[i];
    if (!raw.startsWith('--')) continue;
    const [key, value] = raw.replace(/^--/, '').split('=');
    args[key] = value === undefined ? true : value;
  }
  return args;
}

function getDateKey(data) {
  const completedAt = data.completedAt;
  if (completedAt && completedAt.toDate) {
    return formatDate(completedAt.toDate());
  }
  const dateTime = data.dateTime;
  if (dateTime && dateTime.toDate) {
    return formatDate(dateTime.toDate());
  }
  const rawDate = typeof data.date === 'string' ? data.date.trim() : '';
  return rawDate;
}

function formatDate(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

function inRange(dateKey, startKey, endKey) {
  if (!dateKey) return false;
  if (startKey && dateKey < startKey) return false;
  if (endKey && dateKey > endKey) return false;
  return true;
}

async function loadSalonIds(db, salonId) {
  if (salonId) return [salonId];
  const snap = await db.collection('salons').get();
  return snap.docs.map((doc) => doc.id);
}

async function backfillSalon(db, salonId, options) {
  console.log(`Processing salon: ${salonId}`);
  const statsByDate = new Map();
  let lastDoc = null;
  const bookingsRef = db.collection('salons').doc(salonId).collection('bookings');

  while (true) {
    let query = bookingsRef.orderBy(admin.firestore.FieldPath.documentId()).limit(400);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }
    const snap = await query.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      const data = doc.data() || {};
      const status = (data.status || '').toString().toLowerCase();
      if (status !== 'completed' && status !== 'done') continue;

      const dateKey = getDateKey(data);
      if (!inRange(dateKey, options.startDate, options.endDate)) continue;

      const total = Number(data.total || data.price || 0);
      const tip = Number(data.tipAmount || 0);
      const serviceCharge = Number(data.serviceCharge || 0);

      const existing = statsByDate.get(dateKey) || {
        dateKey,
        totalBookings: 0,
        completedBookings: 0,
        revenue: 0,
        tips: 0,
        serviceCharge: 0,
      };

      existing.totalBookings += 1;
      existing.completedBookings += 1;
      existing.revenue += total;
      existing.tips += tip;
      existing.serviceCharge += serviceCharge;
      statsByDate.set(dateKey, existing);
    }

    lastDoc = snap.docs[snap.docs.length - 1];
  }

  if (statsByDate.size === 0) {
    console.log(`No completed bookings found for ${salonId}.`);
    return;
  }

  if (options.dryRun) {
    console.log(`Dry run: ${statsByDate.size} stats docs prepared.`);
    return;
  }

  const batchSize = 400;
  const entries = Array.from(statsByDate.values());
  for (let i = 0; i < entries.length; i += batchSize) {
    const batch = db.batch();
    const chunk = entries.slice(i, i + batchSize);
    for (const stats of chunk) {
      const ref = db.collection('salons').doc(salonId)
        .collection('stats').doc(stats.dateKey);
      batch.set(ref, {
        ...stats,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    await batch.commit();
  }

  console.log(`Stats backfilled: ${statsByDate.size} docs for ${salonId}.`);
}

async function main() {
  const args = parseArgs(process.argv);
  const projectId = args.projectId;
  const serviceAccount = args.serviceAccount;
  if (!projectId || !serviceAccount) {
    console.log('Usage: node scripts/backfill_owner_stats.js --projectId=... --serviceAccount=... [--salonId=...] [--startDate=YYYY-MM-DD] [--endDate=YYYY-MM-DD] [--dryRun]');
    process.exit(1);
  }

  admin.initializeApp({
    credential: admin.credential.cert(require(serviceAccount)),
    projectId,
  });

  const db = admin.firestore();
  const salonIds = await loadSalonIds(db, args.salonId);
  const options = {
    startDate: typeof args.startDate === 'string' ? args.startDate : '',
    endDate: typeof args.endDate === 'string' ? args.endDate : '',
    dryRun: Boolean(args.dryRun),
  };

  for (const salonId of salonIds) {
    await backfillSalon(db, salonId, options);
  }
  console.log('Backfill done.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
