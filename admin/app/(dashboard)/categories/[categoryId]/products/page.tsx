"use client";
"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import {
  ArrowLeft,
  FolderTree,
  LayoutGrid,
  List,
  Loader2,
  Package,
  Pencil,
  Plus,
  Search,
  Trash2,
} from "@/components/hugeicons";
import { toast } from "sonner";
import { apiFetch } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Badge } from "@/components/ui/badge";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";

interface Category {
  _id: string;
  name: string;
  nameHindi?: string;
  slug: string;
  description?: string;
  image?: { url?: string };
  company?: { _id: string; name: string } | string | null;
  productCount?: number;
}

interface Product {
  _id: string;
  name: string;
  nameHindi?: string;
  sku?: string;
  retailPrice?: number;
  stock?: number;
  status: string;
  images?: Array<{ url?: string; isPrimary?: boolean }>;
}

function productImage(product: Product) {
  return product.images?.find((image) => image.isPrimary)?.url || product.images?.[0]?.url;
}

function isObjectId(value: string) {
  return /^[a-f\d]{24}$/i.test(value);
}

export default function CategoryProductsPage() {
  const router = useRouter();
  const params = useParams<{ categoryId: string | string[] }>();
  const categoryId = Array.isArray(params.categoryId)
    ? params.categoryId[0]
    : params.categoryId;
  const returnTo = categoryId ? `/categories/${categoryId}/products` : "/categories";

  const [category, setCategory] = useState<Category | null>(null);
  const [products, setProducts] = useState<Product[]>([]);
  const [searchInput, setSearchInput] = useState("");
  const [activeSearch, setActiveSearch] = useState("");
  const [page, setPage] = useState(1);
  const [totalProducts, setTotalProducts] = useState(0);
  const [hasMore, setHasMore] = useState(false);
  const [viewMode, setViewMode] = useState<"card" | "list">("card");
  const [isCategoryLoading, setIsCategoryLoading] = useState(true);
  const [isProductsLoading, setIsProductsLoading] = useState(true);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const fetchProducts = useCallback(
    async (nextPage: number, nextSearch: string, replace: boolean) => {
      if (!categoryId || !isObjectId(categoryId)) return;

      if (replace) {
        setIsProductsLoading(true);
      } else {
        setIsLoadingMore(true);
      }

      try {
        const query = new URLSearchParams({
          categoryId,
          page: String(nextPage),
          limit: "20",
        });
        if (nextSearch.trim()) query.set("search", nextSearch.trim());

        const response = await apiFetch(`/admin/products?${query.toString()}`);
        const data = await response.json();
        if (!response.ok) {
          throw new Error(data?.message || "Failed to load products");
        }

        const nextProducts = Array.isArray(data?.data) ? data.data : [];
        const pagination = data?.pagination || {};
        setProducts((current) => (replace ? nextProducts : [...current, ...nextProducts]));
        setPage(Number(pagination.page || nextPage));
        setTotalProducts(Number(pagination.total || nextProducts.length));
        setHasMore(Boolean(pagination.hasNext));
      } catch (fetchError: any) {
        toast.error(fetchError?.message || "Failed to load products");
        if (replace) setProducts([]);
      } finally {
        setIsProductsLoading(false);
        setIsLoadingMore(false);
      }
    },
    [categoryId],
  );

  useEffect(() => {
    if (!categoryId || !isObjectId(categoryId)) {
      setError("The category URL is invalid.");
      setIsCategoryLoading(false);
      setIsProductsLoading(false);
      return;
    }

    let isCurrent = true;
    setError(null);
    setCategory(null);
    setProducts([]);
    setActiveSearch("");
    setSearchInput("");
    setIsCategoryLoading(true);

    const loadCategory = async () => {
      try {
        const response = await apiFetch(`/categories/${categoryId}`, { skipAuth: true });
        const data = await response.json();
        if (!response.ok) {
          throw new Error(data?.message || "Category not found");
        }
        if (isCurrent) setCategory(data?.data || null);
      } catch (fetchError: any) {
        if (isCurrent) setError(fetchError?.message || "Failed to load category");
      } finally {
        if (isCurrent) setIsCategoryLoading(false);
      }
    };

    void loadCategory();
    void fetchProducts(1, "", true);

    return () => {
      isCurrent = false;
    };
  }, [categoryId, fetchProducts]);

  const submitSearch = (event: React.FormEvent) => {
    event.preventDefault();
    setActiveSearch(searchInput);
    void fetchProducts(1, searchInput, true);
  };

  const clearSearch = () => {
    setSearchInput("");
    setActiveSearch("");
    void fetchProducts(1, "", true);
  };

  const deleteProduct = async (productId: string) => {
    if (!window.confirm("Archive this product? It will no longer be visible in the app.")) return;

    try {
      const response = await apiFetch(`/admin/products/${productId}`, { method: "DELETE" });
      const data = await response.json();
      if (!response.ok) throw new Error(data?.message || "Failed to archive product");

      toast.success("Product archived successfully");
      void fetchProducts(1, activeSearch, true);
    } catch (deleteError: any) {
      toast.error(deleteError?.message || "Failed to archive product");
    }
  };

  if (error) {
    return (
      <div className="flex min-h-[420px] flex-col items-center justify-center rounded-xl border border-[#333] bg-[#161616] p-6 text-center">
        <FolderTree className="mb-4 h-12 w-12 text-red-400" />
        <h1 className="text-2xl font-semibold text-white">Category unavailable</h1>
        <p className="mt-2 text-sm text-gray-400">{error}</p>
        <Button onClick={() => router.push("/categories")} className="mt-5 bg-[#818cf8] text-black hover:bg-[#818cf8]/90">
          <ArrowLeft className="mr-2 h-4 w-4" /> Back to Categories
        </Button>
      </div>
    );
  }

  const categoryCompany = typeof category?.company === "object" ? category.company?.name : "";
  const addProductHref = `/products/add?categoryId=${encodeURIComponent(categoryId || "")}&returnTo=${encodeURIComponent(returnTo)}`;

  return (
    <div className="space-y-6">
      <nav className="flex items-center gap-2 text-sm text-gray-400" aria-label="Breadcrumb">
        <Link href="/" className="hover:text-white">Dashboard</Link>
        <span>/</span>
        <Link href="/categories" className="hover:text-white">Categories</Link>
        <span>/</span>
        <span className="truncate text-white">{category?.name || "Products"}</span>
      </nav>

      <section className="rounded-xl border border-[#333] bg-[#161616] p-5 sm:p-6">
        {isCategoryLoading ? (
          <div className="flex items-center gap-4">
            <div className="h-16 w-16 animate-pulse rounded-xl bg-[#242424]" />
            <div className="space-y-2">
              <div className="h-6 w-56 animate-pulse rounded bg-[#242424]" />
              <div className="h-4 w-36 animate-pulse rounded bg-[#242424]" />
            </div>
          </div>
        ) : (
          <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div className="flex min-w-0 items-start gap-4">
              {category?.image?.url ? (
                <img src={category.image.url} alt={category.name} className="h-16 w-16 rounded-xl object-cover" />
              ) : (
                <div className="flex h-16 w-16 shrink-0 items-center justify-center rounded-xl bg-[#0D0D0D]">
                  <FolderTree className="h-7 w-7 text-gray-500" />
                </div>
              )}
              <div className="min-w-0">
                <h1 className="text-2xl font-bold text-white">{category?.name}</h1>
                {category?.nameHindi ? <p className="mt-0.5 text-sm text-[#818cf8]">{category.nameHindi}</p> : null}
                {categoryCompany ? <p className="mt-1 text-sm text-gray-400">{categoryCompany}</p> : null}
                {category?.description ? <p className="mt-2 max-w-2xl text-sm text-gray-400">{category.description}</p> : null}
                <p className="mt-3 text-sm text-gray-300">
                  <span className="font-semibold text-white">{totalProducts}</span> product{totalProducts === 1 ? "" : "s"} in this category
                </p>
              </div>
            </div>
            <Link href="/categories" className="shrink-0">
              <Button variant="outline" className="border-[#333] bg-[#0D0D0D] text-gray-300 hover:bg-[#1A1A1A] hover:text-white">
                <ArrowLeft className="mr-2 h-4 w-4" /> All Categories
              </Button>
            </Link>
          </div>
        )}
      </section>

      <div className="flex flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <form onSubmit={submitSearch} className="flex w-full flex-col gap-2 sm:w-auto sm:flex-row">
          <div className="relative sm:w-80">
            <Search className="absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-gray-500" />
            <Input value={searchInput} onChange={(event) => setSearchInput(event.target.value)} placeholder="Search this category..." className="border-[#333] bg-[#161616] pl-9 text-white placeholder:text-gray-500" />
          </div>
          <Button type="submit" variant="outline" className="border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A]">Search</Button>
          {activeSearch ? <Button type="button" variant="ghost" onClick={clearSearch} className="text-gray-400 hover:text-white">Clear</Button> : null}
        </form>
        <div className="flex flex-col gap-2 sm:flex-row sm:items-center">
          <div className="hidden rounded-lg border border-[#333] bg-[#161616] p-1 md:flex">
            <button type="button" onClick={() => setViewMode("list")} aria-label="List view" className={`rounded-md p-2 ${viewMode === "list" ? "bg-[#818cf8] text-black" : "text-gray-400 hover:text-white"}`}><List className="h-4 w-4" /></button>
            <button type="button" onClick={() => setViewMode("card")} aria-label="Card view" className={`rounded-md p-2 ${viewMode === "card" ? "bg-[#818cf8] text-black" : "text-gray-400 hover:text-white"}`}><LayoutGrid className="h-4 w-4" /></button>
          </div>
          <Link href={addProductHref} className="inline-flex">
            <Button className="w-full bg-[#818cf8] text-black hover:bg-[#818cf8]/90 sm:w-auto"><Plus className="mr-2 h-4 w-4" /> Add Product</Button>
          </Link>
        </div>
      </div>

      {isProductsLoading ? (
        <div className="flex min-h-[320px] items-center justify-center rounded-xl border border-[#333] bg-[#161616]"><Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" /></div>
      ) : products.length === 0 ? (
        <div className="flex min-h-[320px] flex-col items-center justify-center rounded-xl border border-[#333] bg-[#161616] p-6 text-center">
          <Package className="mb-4 h-12 w-12 text-gray-600" />
          <h2 className="text-lg font-semibold text-white">No products found</h2>
          <p className="mt-1 text-sm text-gray-400">{activeSearch ? `No products match “${activeSearch}”.` : "Add the first product to this category."}</p>
          <Link href={addProductHref} className="mt-5"><Button className="bg-[#818cf8] text-black hover:bg-[#818cf8]/90"><Plus className="mr-2 h-4 w-4" /> Add Product</Button></Link>
        </div>
      ) : viewMode === "list" ? (
        <div className="overflow-hidden rounded-xl border border-[#333] bg-[#161616]">
          <Table>
            <TableHeader><TableRow className="border-[#333] hover:bg-transparent"><TableHead className="text-gray-400">Product</TableHead><TableHead className="text-gray-400">SKU</TableHead><TableHead className="text-right text-gray-400">Price</TableHead><TableHead className="text-right text-gray-400">Stock</TableHead><TableHead className="text-center text-gray-400">Status</TableHead><TableHead className="text-right text-gray-400">Actions</TableHead></TableRow></TableHeader>
            <TableBody>{products.map((product) => <TableRow key={product._id} className="border-[#333] hover:bg-[#1A1A1A]"><TableCell><p className="font-medium text-white">{product.name}</p>{product.nameHindi ? <p className="text-xs text-gray-400">{product.nameHindi}</p> : null}</TableCell><TableCell className="text-gray-400">{product.sku || "—"}</TableCell><TableCell className="text-right text-white">{typeof product.retailPrice === "number" ? `₹${product.retailPrice.toLocaleString("en-IN")}` : "—"}</TableCell><TableCell className="text-right text-white">{product.stock ?? 0}</TableCell><TableCell className="text-center"><Badge className={product.status === "active" ? "active-status-pill bg-black text-white" : "bg-gray-500/20 text-gray-300"}>{product.status}</Badge></TableCell><TableCell className="text-right"><div className="flex justify-end gap-1"><Link href={`/products/add?edit=${product._id}&returnTo=${encodeURIComponent(returnTo)}`}><Button size="icon" variant="ghost" className="h-8 w-8 text-blue-400 hover:text-blue-300"><Pencil className="h-4 w-4" /></Button></Link><Button size="icon" variant="ghost" onClick={() => void deleteProduct(product._id)} className="h-8 w-8 text-red-400 hover:bg-red-400/10 hover:text-red-300"><Trash2 className="h-4 w-4" /></Button></div></TableCell></TableRow>)}</TableBody>
          </Table>
        </div>
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
          {products.map((product) => {
            const image = productImage(product);
            return <article key={product._id} className="flex min-h-64 flex-col rounded-xl border border-[#333] bg-[#161616] p-4"><div className="mb-4 flex items-start justify-between gap-3">{image ? <img src={image} alt="" className="h-12 w-12 rounded-lg object-cover" /> : <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-[#0D0D0D]"><Package className="h-6 w-6 text-gray-500" /></div>}<div className="flex gap-1"><Link href={`/products/add?edit=${product._id}&returnTo=${encodeURIComponent(returnTo)}`}><Button size="icon" variant="ghost" className="h-8 w-8 text-blue-400 hover:text-blue-300"><Pencil className="h-4 w-4" /></Button></Link><Button size="icon" variant="ghost" onClick={() => void deleteProduct(product._id)} className="h-8 w-8 text-red-400 hover:bg-red-400/10 hover:text-red-300"><Trash2 className="h-4 w-4" /></Button></div></div><h2 className="line-clamp-2 font-semibold text-white">{product.name}</h2>{product.nameHindi ? <p className="mt-1 line-clamp-1 text-xs text-gray-400">{product.nameHindi}</p> : null}<p className="mt-2 text-xs text-gray-500">SKU: {product.sku || "—"}</p><div className="mt-auto flex items-end justify-between border-t border-[#333] pt-4"><div><p className="text-xs text-gray-500">Price</p><p className="font-semibold text-[#818cf8]">{typeof product.retailPrice === "number" ? `₹${product.retailPrice.toLocaleString("en-IN")}` : "—"}</p></div><div className="text-right"><p className="text-xs text-gray-500">Stock</p><p className="font-medium text-white">{product.stock ?? 0}</p></div></div></article>;
          })}
        </div>
      )}

      {hasMore ? <div className="flex justify-center"><Button onClick={() => void fetchProducts(page + 1, activeSearch, false)} disabled={isLoadingMore} variant="outline" className="min-w-48 border-[#333] bg-[#161616] text-white hover:bg-[#1A1A1A]">{isLoadingMore ? <><Loader2 className="mr-2 h-4 w-4 animate-spin" /> Loading…</> : `Load More (${products.length}/${totalProducts})`}</Button></div> : null}
    </div>
  );
}
