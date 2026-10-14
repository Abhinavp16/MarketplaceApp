import { initializeApp, getApps, type FirebaseApp } from "firebase/app"

// Browser alerts (Firebase Cloud Messaging) are optional. Every value comes from
// NEXT_PUBLIC_FIREBASE_* environment variables (see .env.example). They are all
// empty by default, which keeps push switched off.
// NOTE: each variable must be read as a literal process.env.NEXT_PUBLIC_* so Next.js can inline it.

let cachedApp: FirebaseApp | null = null

export function getFirebaseWebConfig() {
    return {
        apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "",
        authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || "",
        projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "",
        storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || "",
        messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || "",
        appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "",
    }
}

export function getVapidKey(): string {
    return process.env.NEXT_PUBLIC_FIREBASE_VAPID_KEY || ""
}

// Messaging needs these four (authDomain and storageBucket are optional).
export function isFirebaseWebConfigured(): boolean {
    const config = getFirebaseWebConfig()
    return Boolean(config.apiKey && config.projectId && config.messagingSenderId && config.appId)
}

// True when browser alerts can work at all: Firebase web config plus a Web Push (VAPID) key.
export function isAdminPushConfigured(): boolean {
    return isFirebaseWebConfigured() && Boolean(getVapidKey())
}

export function getFirebaseApp(): FirebaseApp | null {
    if (cachedApp) return cachedApp
    if (!isFirebaseWebConfigured()) return null
    cachedApp = getApps().length ? getApps()[0]! : initializeApp(getFirebaseWebConfig())
    return cachedApp
}
