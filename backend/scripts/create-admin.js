#!/usr/bin/env node
/**
 * Creates the first admin (business owner) account in an EMPTY database and,
 * optionally, mints a one-time sign-in link for it.
 *
 *   node scripts/create-admin.js --email owner@example.com [--name "Owner"]
 *        [--link] [--link-minutes 30] [--print-password]
 *
 * Why a link: when DEMO_MODE is not "true" the API refuses password sign-in for
 * admins (auth/login) and only accepts the emailed magic link
 * (auth/magic-link/verify), which needs SMTP. This script stores the same kind
 * of single-use link token directly in the database (only its SHA-256 hash is
 * stored) and prints the URL, so no SMTP is needed to get in the first time.
 * Anyone able to run this script already has database access.
 *
 * - Idempotent: an existing admin with that email is left untouched.
 * - The account gets a random password (hashed by the User model). It cannot be
 *   used to sign in outside demo mode; it is printed only with --print-password.
 * - Never prints secrets other than what you explicitly ask for (--link,
 *   --print-password).
 */
require('dotenv').config();
const crypto = require('crypto');
const mongoose = require('mongoose');

const { USER_ROLES, AUTH_PROVIDERS } = require('../src/utils/constants');
const { currentLegalAcceptance } = require('../src/config/legalAcceptance');

function parseArgs(argv) {
  const args = { link: false, printPassword: false, linkMinutes: 30, name: 'Business Owner', email: '' };
  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    const next = () => {
      i += 1;
      if (i >= argv.length) throw new Error(`${arg} needs a value`);
      return argv[i];
    };
    if (arg === '--email') args.email = next().trim().toLowerCase();
    else if (arg === '--name') args.name = next().trim();
    else if (arg === '--link') args.link = true;
    else if (arg === '--link-minutes') args.linkMinutes = Number(next());
    else if (arg === '--print-password') args.printPassword = true;
    else if (arg === '--help' || arg === '-h') args.help = true;
    else throw new Error(`Unknown option: ${arg}`);
  }
  return args;
}

const USAGE = 'Usage: node scripts/create-admin.js --email <email> [--name "<name>"] [--link] [--link-minutes 30] [--print-password]';

async function main() {
  const args = parseArgs(process.argv.slice(2));
  if (args.help) {
    console.log(USAGE);
    return;
  }
  if (!/^\S+@\S+\.\S+$/.test(args.email)) throw new Error(`A valid --email is required. ${USAGE}`);
  if (!args.name || args.name.length > 100) throw new Error('--name must be 1-100 characters');
  if (!Number.isFinite(args.linkMinutes) || args.linkMinutes < 1 || args.linkMinutes > 24 * 60) {
    throw new Error('--link-minutes must be between 1 and 1440');
  }

  const uri = String(process.env.MONGODB_URI || '').trim().replace(/^['"]|['"]$/g, '');
  if (!uri) throw new Error('MONGODB_URI is not set');
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 15000, family: 4 });

  try {
    const { User } = require('../src/models');
    let user = await User.findOne({ email: args.email });
    let password = null;

    if (user) {
      if (user.role !== USER_ROLES.ADMIN) {
        throw new Error(`${args.email} already exists with role "${user.role}"; refusing to change it`);
      }
      console.log(`Admin ${args.email} already exists in database "${mongoose.connection.name}" (left unchanged).`);
    } else {
      password = `${crypto.randomBytes(18).toString('base64url')}Aa1!`;
      user = await User.create({
        name: args.name,
        email: args.email,
        role: USER_ROLES.ADMIN,
        authProvider: AUTH_PROVIDERS.EMAIL,
        passwordHash: password, // hashed by the User model's pre-save hook
        isActive: true,
        phoneVerified: false,
        ...currentLegalAcceptance(),
      });
      console.log(`Created admin ${args.email} in database "${mongoose.connection.name}".`);
      if (args.printPassword) console.log(`PASSWORD: ${password}`);
    }

    if (!user.isActive) throw new Error(`${args.email} is deactivated; no link issued`);

    if (args.link) {
      const { issueMagicLink } = require('../src/services/magicLinkService');
      const panelUrl = String(process.env.ADMIN_PANEL_URL || '').trim().replace(/\/+$/, '');
      if (!panelUrl) throw new Error('ADMIN_PANEL_URL is not set (needed to build the sign-in link)');
      let captured = null;
      await issueMagicLink({
        email: args.email,
        panelUrl,
        expiryMinutes: args.linkMinutes,
        // Do not email anything: hand the link to the operator instead.
        sendEmail: async (_to, link) => { captured = link; },
      });
      console.log(`SIGN_IN_LINK: ${captured}`);
      console.log(`(single use, valid for ${args.linkMinutes} minutes)`);
    }
  } finally {
    await mongoose.disconnect();
  }
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(`create-admin failed: ${error.message}`);
  process.exit(1);
});
