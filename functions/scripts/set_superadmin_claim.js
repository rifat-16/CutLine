#!/usr/bin/env node

/**
 * Set or unset the `superadmin` custom claim.
 *
 * Usage:
 *   node scripts/set_superadmin_claim.js --uid <uid> --enabled true
 *   node scripts/set_superadmin_claim.js --email <email> --enabled false
 */

const admin = require("firebase-admin");

/**
 * Read a CLI flag value by name.
 * @param {string} name
 * @return {string}
 */
function argValue(name) {
  const index = process.argv.indexOf(`--${name}`);
  if (index === -1 || index + 1 >= process.argv.length) return "";
  return process.argv[index + 1];
}

/**
 * Parse a boolean-like CLI flag.
 * @param {string} raw
 * @return {boolean}
 */
function parseEnabled(raw) {
  const value = raw.trim().toLowerCase();
  if (["true", "1", "yes", "on"].includes(value)) return true;
  if (["false", "0", "no", "off"].includes(value)) return false;
  throw new Error("--enabled must be true or false");
}

/**
 * Resolve a Firebase user by uid or email.
 * @param {Object} auth
 * @param {string} uid
 * @param {string} email
 * @return {Promise<admin.auth.UserRecord>}
 */
async function resolveUser(auth, uid, email) {
  if (uid) return auth.getUser(uid);
  if (email) return auth.getUserByEmail(email);
  throw new Error("Provide --uid or --email");
}

/**
 * CLI entrypoint.
 * @return {Promise<void>}
 */
async function main() {
  const uid = argValue("uid");
  const email = argValue("email");
  const enabled = parseEnabled(argValue("enabled"));

  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
  });

  const auth = admin.auth();
  const user = await resolveUser(auth, uid, email);
  const claims = user.customClaims || {};

  if (enabled) {
    claims.superadmin = true;
  } else {
    delete claims.superadmin;
  }

  await auth.setCustomUserClaims(user.uid, claims);
  const summary =
    `Updated superadmin claim for uid=${user.uid} ` +
    `email=${user.email || ""} enabled=${enabled}`;
  console.log(
      summary,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
