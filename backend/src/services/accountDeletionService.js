const {
  AccountDeletionRequest,
  Cart,
  DeviceToken,
  MagicLinkToken,
  Negotiation,
  Notification,
  RefreshToken,
  User,
} = require('../models');
const { deleteDirectory } = require('../config/storage');
const { BadRequestError, ConflictError, NotFoundError } = require('../utils/errors');

const REQUEST_WINDOW_MS = 30 * 24 * 60 * 60 * 1000;
const ACTIVE_STATUSES = ['pending', 'in_review'];

const dateAfter = (milliseconds) => new Date(Date.now() + milliseconds);

async function findActiveRequest(userId) {
  return AccountDeletionRequest.findOne({
    userId,
    status: { $in: ACTIVE_STATUSES },
  }).sort({ createdAt: -1 });
}

async function createRequestForUser({ user, source }) {
  if (!user || !user.isActive) {
    throw new NotFoundError('Active account not found', 'ACCOUNT_NOT_FOUND');
  }

  const existing = await findActiveRequest(user._id);
  if (existing) {
    return { request: existing, alreadyPending: true };
  }

  const request = await AccountDeletionRequest.create({
    userId: user._id,
    source,
    dueAt: dateAfter(REQUEST_WINDOW_MS),
    events: [{
      action: 'requested',
      byUserId: user._id,
      note: source === 'app' ? 'Submitted by the authenticated account holder.' : 'Submitted through the public deletion page; Member identity verification is required.',
    }],
  });

  return { request, alreadyPending: false };
}

async function completeRequest({ requestId, adminUserId, staffNote = '' }) {
  const request = await AccountDeletionRequest.findById(requestId);
  if (!request) {
    throw new NotFoundError('Deletion request not found', 'DELETION_REQUEST_NOT_FOUND');
  }
  if (!ACTIVE_STATUSES.includes(request.status)) {
    throw new ConflictError('Only pending or in-review requests can be completed', 'DELETION_REQUEST_NOT_ACTIONABLE');
  }

  if (request.source === 'website' && !request.identityVerification?.verifiedAt) {
    throw new BadRequestError(
      'A website deletion request must be verified by a Member before completion',
      'DELETION_REQUEST_VERIFICATION_REQUIRED'
    );
  }

  const user = await User.findById(request.userId).select('+passwordHash');
  if (!user || user.role === 'admin') {
    throw new BadRequestError('The account cannot be processed through this workflow', 'DELETION_REQUEST_INVALID_ACCOUNT');
  }

  const userId = user._id;
  const originalEmail = user.email;
  const completedAt = new Date();
  const anonymizedIdentifier = String(userId);

  // Delete data that is not needed for financial, tax, fraud, or security records.
  await Promise.all([
    Cart.deleteMany({ userId }),
    DeviceToken.deleteMany({ userId }),
    Notification.deleteMany({ userId }),
    Negotiation.deleteMany({ wholesalerId: userId }),
    RefreshToken.updateMany({ userId }, { isRevoked: true }),
    originalEmail ? MagicLinkToken.deleteMany({ email: originalEmail }) : Promise.resolve(),
    deleteDirectory(`avatars/${anonymizedIdentifier}`),
    deleteDirectory(`private/proofs/${anonymizedIdentifier}`),
  ]);

  // Orders and payments are intentionally retained as restricted financial records.
  // The inactive, anonymized account cannot be used to access those records normally.
  user.name = 'Deleted account';
  user.email = `deleted-${anonymizedIdentifier}@deleted.invalid`;
  user.phone = `deleted-${anonymizedIdentifier}`;
  user.address = null;
  user.avatar = null;
  user.googleId = undefined;
  user.passwordHash = undefined;
  user.fcmTokens = [];
  user.phoneVerified = false;
  user.marketingConsent = false;
  user.consentTimestamp = null;
  user.termsAcceptedAt = null;
  user.termsVersion = null;
  user.privacyPolicyAcceptedAt = null;
  user.privacyPolicyVersion = null;
  user.businessInfo = {
    businessName: null,
    gstNumber: null,
    businessAddress: null,
    contactPerson: null,
    shopLocation: {
      lat: null,
      lng: null,
      placeLabel: null,
      capturedAt: null,
    },
    status: 'none',
    verified: false,
    verifiedAt: null,
    excludedCategories: [],
    proofImages: [],
  };
  user.isActive = false;
  await user.save();

  request.status = 'completed';
  request.completedAt = completedAt;
  request.processedBy = adminUserId;
  request.staffNote = staffNote || null;
  request.events.push({
    action: 'completed',
    byUserId: adminUserId,
    note: 'Account access revoked and direct profile, cart, device-token, notification, negotiation, avatar, and business-proof data removed or anonymized. Financial records are retained under the approved retention schedule.',
  });
  await request.save();

  return request;
}

module.exports = {
  ACTIVE_STATUSES,
  createRequestForUser,
  completeRequest,
  findActiveRequest,
};
