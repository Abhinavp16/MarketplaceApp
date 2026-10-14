/* Build-time generator for public/sw.js (runs on `predev` and `prebuild`).
 *
 * Reads the NEXT_PUBLIC_FIREBASE_* variables (process env, .env.local, .env) and
 * writes public/sw.js from public/sw.template.js. These are public browser keys by
 * design, and public/sw.js is gitignored so they never end up in the repository.
 *
 * When the config is incomplete the worker is generated WITHOUT any Firebase code:
 * just the PWA offline shell.
 */
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, '..');

function loadDotEnvFile(filename) {
  const file = path.join(root, filename);
  if (!fs.existsSync(file)) return;
  for (const line of fs.readFileSync(file, 'utf8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    let value = trimmed.slice(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) || (value.startsWith("'") && value.endsWith("'"))) {
      value = value.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = value;
  }
}

loadDotEnvFile('.env.local');
loadDotEnvFile('.env');

const config = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || '',
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || '',
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || '',
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || '',
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || '',
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || '',
};

// Same rule as lib/firebase-client.ts: authDomain and storageBucket are optional.
const fcmEnabled = Boolean(config.apiKey && config.projectId && config.messagingSenderId && config.appId);
const version = new Date().toISOString().slice(0, 16).replace(/[-:T]/g, '');

const template = fs.readFileSync(path.join(root, 'public', 'sw.template.js'), 'utf8');

// The block between the markers is Firebase-only; drop it entirely when disabled.
const fcmBlock = /\/\/ @@FCM_START[\s\S]*?\/\/ @@FCM_END\n?/;
let output = template.replaceAll('__SW_VERSION__', version);
if (fcmEnabled) {
  output = output
    .replace('__FIREBASE_CONFIG_JSON__', () => JSON.stringify(config))
    .replace('// @@FCM_START\n', '')
    .replace('// @@FCM_END\n', '');
} else {
  output = output.replace(fcmBlock, '');
}

fs.writeFileSync(path.join(root, 'public', 'sw.js'), output);
console.log(`[generate-sw] public/sw.js written (fcm=${fcmEnabled ? 'enabled' : 'disabled'}, version=${version})`);
