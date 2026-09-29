const TERMS_VERSION = '2026-08-17';
const PRIVACY_POLICY_VERSION = '2026-08-17';

const legalAcceptanceValidation = {
  termsAccepted: true,
  privacyPolicyAccepted: true,
  termsVersion: TERMS_VERSION,
  privacyPolicyVersion: PRIVACY_POLICY_VERSION,
};

const currentLegalAcceptance = () => {
  const acceptedAt = new Date();
  return {
    termsAcceptedAt: acceptedAt,
    termsVersion: TERMS_VERSION,
    privacyPolicyAcceptedAt: acceptedAt,
    privacyPolicyVersion: PRIVACY_POLICY_VERSION,
  };
};

module.exports = {
  TERMS_VERSION,
  PRIVACY_POLICY_VERSION,
  legalAcceptanceValidation,
  currentLegalAcceptance,
};
