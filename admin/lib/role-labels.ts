// Members are the business's operational users. The backend (API, JWT, stored
// records) still identifies them with the role value "staff"; keep that value
// here only, and show "Member" everywhere in the UI.
export const MEMBER_ROLE = "staff"

export function isMemberRole(role: unknown): boolean {
  return role === MEMBER_ROLE
}

// Raw role values shown to admins (e.g. customer lists).
export function displayRole(role: string | null | undefined): string {
  if (!role) return ""
  return isMemberRole(role) ? "member" : role
}

// Notes/messages already stored by older backend versions may still say
// "Staff"; show them with the current wording.
export function displayActivityText(text: string | null | undefined): string {
  if (!text) return ""
  return text.replace(/\bSTAFF\b/g, "MEMBER").replace(/\bStaff\b/g, "Member").replace(/\bstaff\b/g, "member")
}
