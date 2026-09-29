// Members are stored with the role value "staff". Older records may carry
// "Staff" in free-text notes; show them with the current "Member" wording.
const displayActivityText = (text) => {
  if (typeof text !== 'string' || !text) return text;
  return text
    .replace(/\bSTAFF\b/g, 'MEMBER')
    .replace(/\bStaff\b/g, 'Member')
    .replace(/\bstaff\b/g, 'member');
};

const withDisplayNotes = (statusHistory) => (Array.isArray(statusHistory)
  ? statusHistory.map((entry) => ({ ...entry, note: displayActivityText(entry?.note) }))
  : statusHistory);

module.exports = { displayActivityText, withDisplayNotes };
