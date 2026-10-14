const { initializeApp, cert } = require('firebase-admin/app');
const { getMessaging: getAppMessaging } = require('firebase-admin/messaging');
const { getStorage: getAppStorage } = require('firebase-admin/storage');

let firebaseApp = null;
let warnedNotConfigured = false;

const initializeFirebase = () => {
  if (firebaseApp) {
    return firebaseApp;
  }

  try {
    // Check if credentials are properly configured
    if (!process.env.FIREBASE_PROJECT_ID || 
        !process.env.FIREBASE_PRIVATE_KEY || 
        !process.env.FIREBASE_CLIENT_EMAIL) {
      if (!warnedNotConfigured) {
        warnedNotConfigured = true;
        console.warn('Firebase credentials not configured. Firebase features will be disabled.');
      }
      return null;
    }

    // Clean and format the private key
    let privateKey = process.env.FIREBASE_PRIVATE_KEY;
    if (privateKey) {
      // Drop wrapping quotes some hosts keep, then turn escaped \n sequences into real newlines
      privateKey = privateKey.trim().replace(/^(["'])([\s\S]*)\1$/, '$2');
      privateKey = privateKey.replace(/\\n/g, '\n');
      // Remove any leading/trailing whitespace
      privateKey = privateKey.trim();
      // Ensure proper PEM format
      if (!privateKey.includes('-----BEGIN PRIVATE KEY-----')) {
        privateKey = '-----BEGIN PRIVATE KEY-----\n' + privateKey;
      }
      if (!privateKey.includes('-----END PRIVATE KEY-----')) {
        privateKey = privateKey + '\n-----END PRIVATE KEY-----';
      }
    }
    firebaseApp = initializeApp({
      credential: cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        privateKey: privateKey,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
      }),
      storageBucket: process.env.FIREBASE_STORAGE_BUCKET,
    });

    console.log('Firebase initialized successfully');
    return firebaseApp;
  } catch (error) {
    console.error('Firebase initialization error:', error.message);
    return null;
  }
};

const getFirebaseApp = () => {
  if (!firebaseApp) {
    return initializeFirebase();
  }
  return firebaseApp;
};

const getStorage = () => {
  const app = getFirebaseApp();
  if (!app) return null;
  return getAppStorage(app).bucket();
};

const getMessaging = () => {
  const app = getFirebaseApp();
  if (!app) return null;
  return getAppMessaging(app);
};

module.exports = {
  initializeFirebase,
  getFirebaseApp,
  getStorage,
  getMessaging,
};
