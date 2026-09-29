// Brand/category discounts: % off MRP, separately for customers and wholesalers.
// Resolution per role: brand -> product's category -> parent categories.
// The backend (backend product discount utility) is authoritative;
// this mirror is only used for live previews in forms.

export type DiscountRole = "buyer" | "wholesaler"

export interface DiscountEntity {
  _id?: string
  name?: string
  customerDiscountPercent?: number | null
  wholesalerDiscountPercent?: number | null
}

export interface DiscountCategory extends DiscountEntity {
  _id: string
  parent?: string | { _id: string } | null
}

export interface DiscountFormValues {
  customerDiscountPercent: string
  wholesalerDiscountPercent: string
}

export interface ResolvedDiscount {
  percent: number
  source: "brand" | "category"
  sourceName: string
}

export interface EffectiveRolePricing {
  price: number
  basePrice: number
  discountPercent: number | null
  discountSource: "brand" | "category" | null
  discountSourceName: string | null
}

export interface EffectivePricing {
  buyer: EffectiveRolePricing
  wholesaler: EffectiveRolePricing
}

const FIELD: Record<DiscountRole, keyof DiscountEntity> = {
  buyer: "customerDiscountPercent",
  wholesaler: "wholesalerDiscountPercent",
}

export const EMPTY_DISCOUNT_FORM: DiscountFormValues = {
  customerDiscountPercent: "",
  wholesalerDiscountPercent: "",
}

export function activePercent(value: unknown): number | null {
  const number = Number(value)
  return Number.isFinite(number) && number > 0 && number <= 100 ? number : null
}

// The backend always sends both keys (null when unset) to admins. If they are
// missing, the admin session wasn't recognised (e.g. expired token) and the
// form must not overwrite the stored discounts.
export function hasDiscountFields(entity?: DiscountEntity | null): boolean {
  return Boolean(entity) && "customerDiscountPercent" in (entity as object) && "wholesalerDiscountPercent" in (entity as object)
}

export function toDiscountFormValues(entity?: DiscountEntity | null): DiscountFormValues {
  return {
    customerDiscountPercent: activePercent(entity?.customerDiscountPercent)?.toString() ?? "",
    wholesalerDiscountPercent: activePercent(entity?.wholesalerDiscountPercent)?.toString() ?? "",
  }
}

export function validateDiscountValues(values: DiscountFormValues): string | null {
  for (const [label, raw] of [
    ["Customer discount", values.customerDiscountPercent],
    ["Wholesaler discount", values.wholesalerDiscountPercent],
  ] as const) {
    if (raw.trim() === "") continue
    const number = Number(raw)
    if (!Number.isFinite(number) || number < 0 || number > 100) {
      return `${label} must be between 0 and 100`
    }
  }
  return null
}

// Empty or 0 clears the discount (sent as null).
export function toDiscountPayload(values: DiscountFormValues) {
  const parse = (raw: string) => {
    if (raw.trim() === "") return null
    const number = Math.round(Number(raw) * 100) / 100
    return number > 0 ? number : null
  }
  return {
    customerDiscountPercent: parse(values.customerDiscountPercent),
    wholesalerDiscountPercent: parse(values.wholesalerDiscountPercent),
  }
}

export function formatDiscountSummary(entity?: DiscountEntity | null): string | null {
  const customer = activePercent(entity?.customerDiscountPercent)
  const wholesaler = activePercent(entity?.wholesalerDiscountPercent)
  const parts = [
    customer !== null ? `Customer ${customer}%` : null,
    wholesaler !== null ? `Dealer ${wholesaler}%` : null,
  ].filter(Boolean)
  return parts.length > 0 ? parts.join(" · ") : null
}

export function applyMrpDiscount(mrp: number, percent: number): number {
  return Math.round(mrp * (1 - percent / 100) * 100) / 100
}

const idOf = (value: unknown): string => {
  if (!value) return ""
  if (typeof value === "object" && value !== null && "_id" in value) {
    return String((value as { _id: string })._id)
  }
  return String(value)
}

export function resolveDiscountPreview({
  role,
  brand,
  categoryId,
  categories,
}: {
  role: DiscountRole
  brand?: DiscountEntity | null
  categoryId?: string | null
  categories: DiscountCategory[]
}): ResolvedDiscount | null {
  const field = FIELD[role]
  const brandPercent = activePercent(brand?.[field])
  if (brandPercent !== null) {
    return { percent: brandPercent, source: "brand", sourceName: brand?.name || "Brand" }
  }

  const byId = new Map(categories.map((category) => [String(category._id), category]))
  const visited = new Set<string>()
  let current = categoryId ? byId.get(String(categoryId)) : undefined
  while (current && !visited.has(String(current._id))) {
    visited.add(String(current._id))
    const percent = activePercent(current[field])
    if (percent !== null) {
      return { percent, source: "category", sourceName: current.name || "Category" }
    }
    const parentId = idOf(current.parent)
    current = parentId ? byId.get(parentId) : undefined
  }
  return null
}

export function describeDiscountSource(pricing?: EffectiveRolePricing | null): string | null {
  if (!pricing?.discountPercent || !pricing.discountSource) return null
  const kind = pricing.discountSource === "brand" ? "Brand" : "Category"
  return `${kind} ${pricing.discountSourceName ?? ""} · ${pricing.discountPercent}% off MRP`.replace(/\s+·/, " ·")
}

// Hints shown under the category discount inputs: brand overrides, or which
// parent the category inherits from when left empty.
export function buildCategoryDiscountNotes({
  brand,
  parentId,
  categories,
  values,
}: {
  brand?: DiscountEntity | null
  parentId?: string | null
  categories: DiscountCategory[]
  values: DiscountFormValues
}): { customerNote: string | null; wholesalerNote: string | null } {
  const noteFor = (role: DiscountRole, raw: string) => {
    const field = FIELD[role]
    const brandPercent = activePercent(brand?.[field])
    if (brandPercent !== null) {
      return `Brand ${brand?.name ?? ""} has ${brandPercent}% — it overrides this.`.replace("Brand  has", "Brand has")
    }
    if (activePercent(raw) !== null) return null
    const inherited = parentId ? resolveDiscountPreview({ role, categoryId: parentId, categories }) : null
    return inherited ? `Empty: uses ${inherited.sourceName} (${inherited.percent}%).` : null
  }
  return {
    customerNote: noteFor("buyer", values.customerDiscountPercent),
    wholesalerNote: noteFor("wholesaler", values.wholesalerDiscountPercent),
  }
}
