export default function VariantAwareSkuChip({ sku }) {
    if (!sku) return null;

    return (
        <span className="rounded-full border border-gray-200 bg-white px-4 py-2 font-semibold text-gray-600">
            SKU: {sku}
        </span>
    );
}
