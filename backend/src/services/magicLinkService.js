const crypto = require('crypto');
const { MagicLinkToken } = require('../models');
const { sendMagicLinkEmail } = require('./emailService');

const hashMagicToken = (token) => crypto.createHash('sha256').update(token).digest('hex');

async function issueMagicLink({
  email,
  panelUrl,
  expiryMinutes,
  tokenStore = MagicLinkToken,
  sendEmail = sendMagicLinkEmail,
  randomBytes = crypto.randomBytes,
}) {
  const rawToken = randomBytes(32).toString('hex');
  const expiresAt = new Date(Date.now() + expiryMinutes * 60 * 1000);
  const candidate = await tokenStore.create({
    email,
    tokenHash: hashMagicToken(rawToken),
    expiresAt,
  });
  const link = `${panelUrl}/login/verify?token=${rawToken}`;

  try {
    await sendEmail(email, link, expiryMinutes);
  } catch (error) {
    await tokenStore.deleteOne({ _id: candidate._id });
    throw error;
  }

  const deliveredAt = new Date();
  await tokenStore.updateOne(
    { _id: candidate._id },
    { $set: { deliveredAt } },
  );
  candidate.deliveredAt = deliveredAt;

  await tokenStore.deleteMany({
    email,
    used: false,
    deliveredAt: { $ne: null },
    _id: { $lt: candidate._id },
  });

  return candidate;
}

function consumeMagicLink(rawToken, tokenStore = MagicLinkToken) {
  return tokenStore.findOneAndDelete({
    tokenHash: hashMagicToken(rawToken),
    used: false,
    expiresAt: { $gt: new Date() },
  });
}

module.exports = {
  consumeMagicLink,
  hashMagicToken,
  issueMagicLink,
};
