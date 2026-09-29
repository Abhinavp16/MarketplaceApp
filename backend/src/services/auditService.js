const { AuditLog } = require('../models');

async function recordAudit({ actorId, action, entityType, entityId, metadata = {}, session = null }) {
  if (!actorId || !entityId) return null;

  const records = await AuditLog.create([{
    actorId,
    action,
    entityType,
    entityId,
    metadata,
  }], session ? { session } : undefined);
  return records[0];
}

module.exports = { recordAudit };
