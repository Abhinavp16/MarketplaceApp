const logger = require('../utils/logger');
const { AccountDeletionRequest } = require('../models');
const { notifyAdmins } = require('./adminNotificationService');

// Open deletion requests must be completed within 30 days. Admins get one
// reminder when a request is due within DUE_SOON_DAYS, and one when it is
// overdue. The alerts name no one; the request is on the Deletion Requests page.
const DUE_SOON_DAYS = 7;
const SWEEP_INTERVAL_MS = 6 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
const OPEN_STATUSES = ['pending', 'in_review'];

const dayLabel = (days) => (days === 1 ? '1 day' : `${days} days`);
const dateLabel = (date) => new Date(date).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' });

async function sendDeletionReminders({ now = new Date() } = {}) {
  const sent = { dueSoon: 0, overdue: 0 };

  const overdue = await AccountDeletionRequest.find({
    status: { $in: OPEN_STATUSES },
    dueAt: { $lte: now },
    'reminders.overdueAt': null,
  }).select('_id dueAt requestedAt source');
  for (const request of overdue) {
    await notifyAdmins({
      type: 'account_deletion_overdue',
      severity: 'urgent',
      title: 'Account deletion overdue',
      body: `A deletion request from ${dateLabel(request.requestedAt)} was due on ${dateLabel(request.dueAt)}. Please complete or reject it.`,
      link: '/account-deletion-requests',
      metadata: { requestId: String(request._id), source: request.source },
    });
    // dueSoonAt too: an overdue request needs no separate "due soon" alert.
    await AccountDeletionRequest.updateOne(
      { _id: request._id },
      { $set: { 'reminders.overdueAt': now, 'reminders.dueSoonAt': now } },
    );
    sent.overdue += 1;
  }

  const dueSoon = await AccountDeletionRequest.find({
    status: { $in: OPEN_STATUSES },
    dueAt: { $gt: now, $lte: new Date(now.getTime() + DUE_SOON_DAYS * DAY_MS) },
    'reminders.dueSoonAt': null,
  }).select('_id dueAt requestedAt source');
  for (const request of dueSoon) {
    const daysLeft = Math.max(1, Math.ceil((request.dueAt.getTime() - now.getTime()) / DAY_MS));
    await notifyAdmins({
      type: 'account_deletion_due_soon',
      severity: 'warning',
      title: `Account deletion due in ${dayLabel(daysLeft)}`,
      body: `A deletion request from ${dateLabel(request.requestedAt)} must be completed by ${dateLabel(request.dueAt)}.`,
      link: '/account-deletion-requests',
      metadata: { requestId: String(request._id), source: request.source },
    });
    await AccountDeletionRequest.updateOne({ _id: request._id }, { $set: { 'reminders.dueSoonAt': now } });
    sent.dueSoon += 1;
  }

  if (sent.dueSoon || sent.overdue) {
    logger.info(`[AccountDeletion] reminders sent: ${sent.dueSoon} due soon, ${sent.overdue} overdue`);
  }
  return sent;
}

let sweepHandle = null;

function startAccountDeletionReminderScheduler() {
  if (sweepHandle) return sweepHandle;
  const run = () => sendDeletionReminders().catch((error) => logger.error('Account deletion reminders failed:', error));
  sweepHandle = setInterval(run, SWEEP_INTERVAL_MS);
  sweepHandle.unref?.();
  setTimeout(run, 4 * 60 * 1000).unref?.();
  return sweepHandle;
}

module.exports = {
  DUE_SOON_DAYS,
  sendDeletionReminders,
  startAccountDeletionReminderScheduler,
};
