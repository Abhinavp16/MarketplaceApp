"use client";

import Link from "next/link";
import {
  Plus,
  Loader2,
  Pencil,
  Trash2,
  Eye,
  LayoutGrid,
  List,
  Package,
  Star,
  Search,
} from "@/components/hugeicons";
import { useEffect, useState, useCallback } from "react";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";
import { apiFetch } from "@/lib/api";
import { HindiNameBatchButtons } from "@/components/hindi-name-tools";
import { describeDiscountSource, type EffectivePricing } from "@/lib/discount";

interface ProductCategory {
  name?: string;
  slug?: string;
}

interface Product {
  _id: string;
  name: string;
  nameHindi?: string;
  category?: string | ProductCategory;
  retailPrice?: number;
  stock?: number;
  status: string;
  sku?: string;
  rating: number;
  isFeatured?: boolean;
  isHot?: boolean;
  effectivePricing?: EffectivePricing;
}

function getProductRating(product: any): number | null {
  const candidates = [
    product?.rating,
    product?.averageRating,
    product?.ratings?.average,
  ];

  for (const candidate of candidates) {
    const value = Number(candidate);
    if (Number.isFinite(value)) {
      return value;
    }
  }

  return null;
}

function getCategoryLabel(category: Product["category"]): string {
  if (!category) return "Uncategorized";
  if (typeof category === "string") return category;
  return category.name || category.slug || "Uncategorized";
}

function getDisplaySku(product: Product): string {
  return product.sku || "-";
}

// Customer price after any brand/category discount (from the backend).
function getDisplayPrice(product: Product): number | null {
  const effective = product.effectivePricing?.buyer?.price;
  if (typeof effective === "number" && Number.isFinite(effective) && effective > 0) {
    return effective;
  }
  if (
    typeof product.retailPrice === "number" &&
    Number.isFinite(product.retailPrice)
  ) {
    return product.retailPrice;
  }
  return null;
}

function DiscountHint({ product }: { product: Product }) {
  const customer = describeDiscountSource(product.effectivePricing?.buyer);
  const dealer = describeDiscountSource(product.effectivePricing?.wholesaler);
  if (!customer && !dealer) return null;
  return (
    <div className="mt-0.5 space-y-0.5 text-[11px] font-medium text-amber-600">
      {customer && <p>Customer: {customer}</p>}
      {dealer && (
        <p>
          Dealer Rs {product.effectivePricing?.wholesaler.price.toLocaleString()}: {dealer}
        </p>
      )}
    </div>
  );
}

function getTotalStock(product: Product): number {
  return Number(product.stock || 0);
}

function ProductCard({
  product,
  onDelete,
}: {
  product: Product;
  onDelete: (productId: string) => void;
}) {
  const displayPrice = getDisplayPrice(product);
  const totalStock = getTotalStock(product);

  return (
    <div
      className="catalog-card-borderless flex h-full flex-col rounded-[28px] bg-white/92 p-4"
      style={{ border: "none", boxShadow: "none" }}
    >
      <div className="mb-3 flex items-start justify-between gap-3">
        <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-2xl bg-[#eaeaf6]">
          <Package className="h-6 w-6 text-slate-500" />
        </div>
        <div className="flex shrink-0 gap-1">
          <Button
            size="icon"
            variant="ghost"
            className="h-7 w-7 text-slate-500 hover:bg-[#e8e8f5] hover:text-slate-900"
          >
            <Eye className="h-3.5 w-3.5" />
          </Button>
          <Link href={`/products/edit/${product._id}`}>
            <Button
              size="icon"
              variant="ghost"
              className="h-7 w-7 text-blue-400 hover:text-blue-300"
            >
              <Pencil className="h-3.5 w-3.5" />
            </Button>
          </Link>
          <Button
            size="icon"
            variant="ghost"
            className="h-7 w-7 text-red-400 hover:bg-red-400/10 hover:text-red-300"
            onClick={() => onDelete(product._id)}
          >
            <Trash2 className="h-3.5 w-3.5" />
          </Button>
        </div>
      </div>

      <div className="min-w-0">
        <h3 className="mb-1 line-clamp-1 text-base font-semibold text-slate-900">
          {product.name}
        </h3>
        {product.nameHindi ? (
          <p className="mb-1 line-clamp-1 text-xs text-slate-500">
            {product.nameHindi}
          </p>
        ) : null}
        <p className="mb-3 line-clamp-1 text-xs text-slate-500">
          SKU: {getDisplaySku(product)}
        </p>
      </div>

      <div className="mb-3 flex flex-wrap items-center gap-2">
        <Badge
          variant="outline"
          className="max-w-full border-[#cacbdf] bg-[#f3f3fa] text-xs text-slate-700"
        >
          <span className="truncate">{getCategoryLabel(product.category)}</span>
        </Badge>
        <Badge
          className={
            product.status === "active"
              ? "active-status-pill text-xs bg-black text-white"
              : "text-xs bg-slate-500/10 text-slate-500"
          }
        >
          {product.status}
        </Badge>
        <Badge
          variant="outline"
          className="border-yellow-200 bg-yellow-50 text-xs font-medium text-yellow-700"
        >
          <Star className="mr-1 h-3 w-3 fill-current" />
          {product.rating > 0 ? product.rating : "-"}
        </Badge>
      </div>

      <div className="mb-4 flex flex-wrap gap-2 text-xs">
        {product.isFeatured ? (
          <Badge className="bg-yellow-500/12 text-yellow-700 hover:bg-yellow-500/20">
            Featured
          </Badge>
        ) : null}
        {product.isHot ? (
          <Badge className="bg-orange-500/10 text-orange-600 hover:bg-orange-500/20">
            Hot
          </Badge>
        ) : null}
      </div>

      <div className="mt-auto flex items-end justify-between gap-4 border-t border-[#e2e2f0] pt-3">
        <div className="min-w-0">
          <p className="text-lg font-bold text-[#818cf8]">
            {displayPrice !== null
              ? `Rs ${displayPrice.toLocaleString()}`
              : "-"}
          </p>
          <DiscountHint product={product} />
        </div>
        <div className="shrink-0 text-right">
          <p className="text-xs text-slate-500">Stock</p>
          <p className="font-medium text-slate-900">{totalStock}</p>
        </div>
      </div>
    </div>
  );
}

export default function ProductsPage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [viewMode, setViewMode] = useState<"list" | "card">("card");

  const [searchQuery, setSearchQuery] = useState("");
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [totalProducts, setTotalProducts] = useState(0);
  const [hasMore, setHasMore] = useState(false);

  useEffect(() => {
    fetchProducts(1, true);
  }, []);

  async function fetchProducts(pageNum: number = 1, reset: boolean = false) {
    if (reset) {
      setIsLoading(true);
      setPage(1);
    } else {
      setIsLoadingMore(true);
    }

    try {
      const params = new URLSearchParams();
      params.append("page", pageNum.toString());
      params.append("limit", "20");
      if (searchQuery.trim()) {
        params.append("search", searchQuery.trim());
      }

      const res = await apiFetch(`/admin/products?${params.toString()}`);
      const data = await res.json();
      if (res.ok) {
        const items = Array.isArray(data.data) ? data.data : [];
        const pagination = data.pagination || {};

        if (reset || pageNum === 1) {
          const missingRatingIds = items
            .filter((product: any) => getProductRating(product) === null)
            .map((product: any) => String(product?._id || ""))
            .filter(Boolean);

          let ratingsById: Record<string, number> = {};

          if (missingRatingIds.length > 0) {
            const detailResults = await Promise.all(
              missingRatingIds.map(async (productId: string) => {
                try {
                  const detailRes = await apiFetch(
                    `/admin/products/${productId}`,
                  );
                  const detailData = await detailRes.json();
                  if (!detailRes.ok) return null;
                  const detailedProduct = detailData?.data;
                  const rating = getProductRating(detailedProduct);
                  return rating === null ? null : { productId, rating };
                } catch {
                  return null;
                }
              }),
            );

            ratingsById = detailResults.reduce(
              (acc, item) => {
                if (item) acc[item.productId] = item.rating;
                return acc;
              },
              {} as Record<string, number>,
            );
          }

          const productsWithRatings = items.map((product: any) => ({
            ...product,
            rating:
              getProductRating(product) ??
              ratingsById[String(product?._id || "")] ??
              0,
          }));

          setProducts(productsWithRatings);
        } else {
          const missingRatingIds = items
            .filter((product: any) => getProductRating(product) === null)
            .map((product: any) => String(product?._id || ""))
            .filter(Boolean);

          let ratingsById: Record<string, number> = {};

          if (missingRatingIds.length > 0) {
            const detailResults = await Promise.all(
              missingRatingIds.map(async (productId: string) => {
                try {
                  const detailRes = await apiFetch(
                    `/admin/products/${productId}`,
                  );
                  const detailData = await detailRes.json();
                  if (!detailRes.ok) return null;
                  const detailedProduct = detailData?.data;
                  const rating = getProductRating(detailedProduct);
                  return rating === null ? null : { productId, rating };
                } catch {
                  return null;
                }
              }),
            );

            ratingsById = detailResults.reduce(
              (acc, item) => {
                if (item) acc[item.productId] = item.rating;
                return acc;
              },
              {} as Record<string, number>,
            );
          }

          const newProducts = items.map((product: any) => ({
            ...product,
            rating:
              getProductRating(product) ??
              ratingsById[String(product?._id || "")] ??
              0,
          }));

          setProducts((prev) => [...prev, ...newProducts]);
        }

        setTotalPages(pagination.totalPages || 1);
        setTotalProducts(pagination.total || items.length);
        setHasMore((pagination.page || 1) < (pagination.totalPages || 1));
      } else {
        toast.error("Failed to fetch products");
      }
    } catch (error) {
      console.error(error);
      toast.error("Error connecting to server");
    } finally {
      setIsLoading(false);
      setIsLoadingMore(false);
    }
  }

  const handleSearch = useCallback(
    (e: React.FormEvent) => {
      e.preventDefault();
      fetchProducts(1, true);
    },
    [searchQuery],
  );

  const loadMore = useCallback(() => {
    if (hasMore && !isLoadingMore) {
      const nextPage = page + 1;
      setPage(nextPage);
      fetchProducts(nextPage, false);
    }
  }, [hasMore, isLoadingMore, page]);

  async function deleteProduct(productId: string) {
    const confirmed = window.confirm(
      "Are you sure you want to archive this product? It will no longer be visible in the app.",
    );
    if (!confirmed) return;

    try {
      const res = await apiFetch(`/admin/products/${productId}`, {
        method: "DELETE",
      });
      const data = await res.json();

      if (res.ok) {
        toast.success("Product archived successfully");
        setProducts((prev) =>
          prev.filter((product) => product._id !== productId),
        );
        setTotalProducts((prev) => Math.max(0, prev - 1));
        fetchProducts(1, true);
      } else {
        toast.error(data.message || "Failed to delete product");
      }
    } catch (error) {
      console.error(error);
      toast.error("Error connecting to server");
    }
  }

  return (
    <div className="flex flex-col gap-6">
      <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
        <div>
          <h1 className="text-3xl font-bold text-slate-900">Products</h1>
          <p className="text-slate-500">
            Manage your product catalog.{" "}
            {totalProducts > 0 && `(${totalProducts} products)`}
          </p>
        </div>
        <div className="flex flex-col gap-3 sm:flex-row sm:flex-wrap sm:items-center sm:justify-start lg:justify-end">
          <HindiNameBatchButtons
            endpoint="/admin/products/hindi-names/generate-missing"
            entityLabel="products"
            onDone={() => fetchProducts()}
            buttonClassName="w-full border-[#cacbdf] bg-white text-slate-700 hover:bg-[#efeff8] hover:text-slate-900 sm:w-auto"
          />
          <div className="hidden items-center rounded-xl border border-[#cacbdf] bg-[#eaeaf6] p-1 md:flex">
            <button
              onClick={() => setViewMode("list")}
              className={`rounded-lg p-2 transition-colors ${viewMode === "list" ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-900"}`}
            >
              <List className="h-4 w-4" />
            </button>
            <button
              onClick={() => setViewMode("card")}
              className={`rounded-lg p-2 transition-colors ${viewMode === "card" ? "bg-white text-slate-900 shadow-sm" : "text-slate-500 hover:text-slate-900"}`}
            >
              <LayoutGrid className="h-4 w-4" />
            </button>
          </div>
          <Link
            href="/products/add"
            className="inline-flex h-10 w-full items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground shadow-sm transition-colors hover:bg-sky-300 sm:w-auto"
          >
            <Plus className="mr-2 h-4 w-4" /> Add Product
          </Link>
        </div>
      </div>

      <form
        onSubmit={handleSearch}
        className="flex flex-col gap-3 sm:flex-row sm:items-center"
      >
        <div className="relative w-full sm:max-w-md sm:flex-1">
          <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-400" />
          <Input
            type="text"
            placeholder="Search products by name or SKU..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="border-[#cacbdf] bg-white pl-10 text-slate-900 placeholder:text-slate-400 focus-visible:ring-[#818cf8]"
          />
        </div>
        <Button
          type="submit"
          variant="outline"
          className="w-full border-[#cacbdf] bg-white text-slate-700 hover:bg-[#efeff8] hover:text-slate-900 sm:w-auto"
        >
          Search
        </Button>
        {searchQuery ? (
          <Button
            type="button"
            variant="ghost"
            onClick={() => {
              setSearchQuery("");
              fetchProducts(1, true);
            }}
            className="w-full text-slate-500 hover:bg-[#efeff8] hover:text-slate-900 sm:w-auto"
          >
            Clear
          </Button>
        ) : null}
      </form>

      {isLoading ? (
        <div className="flex min-h-[400px] items-center justify-center rounded-[28px] border border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)]">
          <Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" />
        </div>
      ) : products.length === 0 ? (
        <div className="flex min-h-[400px] flex-col items-center justify-center rounded-[28px] border border-[#d0d1e3] bg-white/92 text-slate-500 shadow-[0_24px_60px_rgba(50,58,110,0.08)]">
          <Package className="mb-4 h-12 w-12 opacity-50" />
          <p>No products found</p>
          <p className="text-sm">Add your first product to get started</p>
        </div>
      ) : viewMode === "list" ? (
        <>
          <div className="grid grid-cols-1 gap-4 md:hidden">
            {products.map((product) => {
              return (
                <ProductCard
                  key={product._id}
                  product={product}
                  onDelete={deleteProduct}
                />
              );
            })}
          </div>
          <div className="hidden overflow-hidden rounded-[28px] border border-[#d0d1e3] bg-white/92 shadow-[0_24px_60px_rgba(50,58,110,0.08)] md:block">
            <Table>
              <TableHeader>
                <TableRow className="border-[#e2e2f0] hover:bg-[#f3f3fa]">
                  <TableHead className="text-slate-500">Name</TableHead>
                  <TableHead className="text-slate-500">SKU</TableHead>
                  <TableHead className="text-slate-500">Category</TableHead>
                  <TableHead className="text-right text-slate-500">
                    Price
                  </TableHead>
                  <TableHead className="text-right text-slate-500">
                    Stock
                  </TableHead>
                  <TableHead className="text-center text-slate-500">
                    Rating
                  </TableHead>
                  <TableHead className="text-center text-slate-500">
                    Status
                  </TableHead>
                  <TableHead className="text-right text-slate-500">
                    Actions
                  </TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {products.map((product) => {
                  const displayPrice = getDisplayPrice(product);
                  const totalStock = getTotalStock(product);

                  return (
                    <TableRow
                      key={product._id}
                      className="border-[#e2e2f0] hover:bg-[#f3f3fa]"
                    >
                      <TableCell>
                        <div>
                          <p className="font-medium text-slate-900">
                            {product.name}
                          </p>
                          {product.nameHindi ? (
                            <p className="text-xs text-slate-500">
                              {product.nameHindi}
                            </p>
                          ) : null}
                        </div>
                      </TableCell>
                      <TableCell className="text-slate-500">
                        {getDisplaySku(product)}
                      </TableCell>
                      <TableCell className="text-slate-900">
                        <Badge
                          variant="outline"
                          className="border-[#cacbdf] bg-[#f3f3fa] text-slate-700"
                        >
                          {getCategoryLabel(product.category)}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right text-slate-900">
                        {displayPrice !== null
                          ? `Rs ${displayPrice.toLocaleString()}`
                          : "-"}
                        <DiscountHint product={product} />
                      </TableCell>
                      <TableCell className="text-right text-slate-900">
                        {totalStock}
                      </TableCell>
                      <TableCell className="text-center">
                        <div className="flex items-center justify-center gap-1 text-yellow-500">
                          <Star className="h-3 w-3 fill-current" />
                          <span className="text-xs">
                            {product.rating > 0 ? product.rating : "-"}
                          </span>
                        </div>
                      </TableCell>
                      <TableCell className="text-center">
                        <Badge
                          className={
                            product.status === "active"
                              ? "active-status-pill bg-black text-white hover:bg-slate-800"
                              : "bg-slate-500/10 text-slate-500 hover:bg-slate-500/20"
                          }
                        >
                          {product.status}
                        </Badge>
                      </TableCell>
                      <TableCell className="text-right">
                        <div className="flex justify-end gap-2">
                          <Button
                            size="icon"
                            variant="ghost"
                            className="h-8 w-8 text-slate-500 hover:bg-[#e8e8f5] hover:text-slate-900"
                          >
                            <Eye className="h-4 w-4" />
                          </Button>
                          <Link href={`/products/edit/${product._id}`}>
                            <Button
                              size="icon"
                              variant="ghost"
                              className="h-8 w-8 text-blue-400 hover:bg-blue-400/10 hover:text-blue-300"
                            >
                              <Pencil className="h-4 w-4" />
                            </Button>
                          </Link>
                          <Button
                            size="icon"
                            variant="ghost"
                            className="h-8 w-8 text-red-400 hover:bg-red-400/10 hover:text-red-300"
                            onClick={() => deleteProduct(product._id)}
                          >
                            <Trash2 className="h-4 w-4" />
                          </Button>
                        </div>
                      </TableCell>
                    </TableRow>
                  );
                })}
              </TableBody>
            </Table>
          </div>
        </>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {products.map((product) => {
            return (
              <ProductCard
                key={product._id}
                product={product}
                onDelete={deleteProduct}
              />
            );
          })}
        </div>
      )}

      {hasMore && products.length > 0 ? (
        <div className="flex justify-center pt-4">
          <Button
            onClick={loadMore}
            disabled={isLoadingMore}
            variant="outline"
            className="min-w-[200px] border-[#cacbdf] bg-white text-slate-700 hover:bg-[#efeff8] hover:text-slate-900"
          >
            {isLoadingMore ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Loading...
              </>
            ) : (
              `Load More (${products.length}/${totalProducts})`
            )}
          </Button>
        </div>
      ) : null}
    </div>
  );
}
