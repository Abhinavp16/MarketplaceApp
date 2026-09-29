import { CONTACT_EMAIL, CONTACT_PHONE } from '@/lib/site-config';

// Demo build: nothing is ever sent anywhere. Inquiry forms simply show a confirmation.
export const DEMO_INQUIRY_CONFIRMATION = 'Inquiry received (demo — no message sent)';

export const DEMO_CONTACT = {
    email: CONTACT_EMAIL,
    phone: CONTACT_PHONE,
};

export const DEMO_CONTACT_HINT = `Demo contact: ${CONTACT_EMAIL} / ${CONTACT_PHONE}`;
