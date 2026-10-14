const assert = require('assert');
const crypto = require('crypto');

// firebase-admin starts and offers every call this API makes (push and file
// storage), with a throwaway key and no network: nothing is sent anywhere.
//
//   node tests/firebaseSetup.test.js

const { privateKey } = crypto.generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' },
});
process.env.FIREBASE_PROJECT_ID = 'throwaway-test-project';
process.env.FIREBASE_CLIENT_EMAIL = 'test@throwaway-test-project.iam.gserviceaccount.com';
// Stored with escaped newlines, like the hosting environment variables.
process.env.FIREBASE_PRIVATE_KEY = privateKey.replace(/\n/g, '\\n');
process.env.FIREBASE_STORAGE_BUCKET = 'throwaway-test-project.appspot.com';

const firebase = require('../src/config/firebase');

assert.ok(firebase.initializeFirebase(), 'Firebase starts');
const messaging = firebase.getMessaging();
const bucket = firebase.getStorage();
const file = bucket.file('products/example.webp');

assert.strictEqual(bucket.name, 'throwaway-test-project.appspot.com');
assert.strictEqual(firebase.getMessaging(), messaging, 'one messaging instance');

const required = {
  messaging: [messaging, ['send', 'sendEachForMulticast', 'subscribeToTopic', 'unsubscribeFromTopic']],
  bucket: [bucket, ['file', 'getFiles', 'deleteFiles', 'getMetadata']],
  file: [file, ['createWriteStream', 'makePublic', 'exists', 'delete', 'getSignedUrl']],
};
for (const [label, [target, methods]] of Object.entries(required)) {
  for (const method of methods) {
    assert.strictEqual(typeof target[method], 'function', `${label}.${method} exists`);
  }
}

console.log('Firebase setup test passed');
