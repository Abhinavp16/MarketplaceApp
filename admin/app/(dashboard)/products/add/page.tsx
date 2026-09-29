"use client";

import { useState, useEffect } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import * as z from "zod";
import {
  Loader2,
  Plus,
  Building2,
  Flame,
  Star,
  ImagePlus,
  X,
  GripVertical,
  Crown,
  Upload,
  ArrowLeft,
  FolderPlus,
  Youtube,
  Truck,
  ChevronDown,
  Tags,
  Check,
} from "@/components/hugeicons";
import { useSearchParams } from "next/navigation";
import NextLink from "next/link";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import {
  Command,
  CommandEmpty,
  CommandInput,
  CommandItem,
  CommandList,
} from "@/components/ui/command";
import {
  Form,
  FormControl,
  FormDescription,
  FormField,
  FormItem,
  FormLabel,
  FormMessage,
} from "@/components/ui/form";
import { Input } from "@/components/ui/input";
import {
  Popover,
  PopoverContent,
  PopoverTrigger,
} from "@/components/ui/popover";
import { Textarea } from "@/components/ui/textarea";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Card, CardContent } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog";
import { toast } from "sonner";
import { useRouter } from "next/navigation";
import { apiFetch, buildApiUrl } from "@/lib/api";
import { EffectivePricePreview } from "@/components/effective-price-preview";
import { HINDI_AUTO_NOTE, SuggestHindiButton } from "@/components/hindi-name-tools";

interface Category {
  _id: string;
  name: string;
  slug: string;
  company?: { _id: string; name: string; slug: string } | string | null;
  parent?: { _id: string } | string | null;
  customerDiscountPercent?: number | null;
  wholesalerDiscountPercent?: number | null;
}

interface Company {
  _id: string;
  name: string;
  slug: string;
  customerDiscountPercent?: number | null;
  wholesalerDiscountPercent?: number | null;
}

interface ProductLabelOption {
  id: string;
  title: string;
  sourceType: "image" | "icon";
}

function labelMatches(value: string, label: ProductLabelOption) {
  const normalizedValue = String(value || "").trim();
  return normalizedValue === label.id || normalizedValue === label.title;
}

function normalizeSelectedLabelIds(
  values: string[],
  labels: ProductLabelOption[],
) {
  return [
    ...new Set(
      values
        .map((value) => {
          const normalizedValue = String(value || "").trim();
          const match = labels.find((label) =>
            labelMatches(normalizedValue, label),
          );
          return match?.id || normalizedValue;
        })
        .filter(Boolean),
    ),
  ];
}

type UploadStatus = "idle" | "converting" | "uploading" | "done";

const PRICE_UNIT_OPTIONS = [
  { value: "Piece", label: "Piece" },
  { value: "Mtr", label: "Meter" },
  { value: "Packet", label: "Packet" },
  { value: "Roll", label: "Roll" },
  { value: "Coil", label: "Coil" },
  { value: "Kg", label: "Kg" },
  { value: "Box", label: "Box" },
  { value: "Set", label: "Set" },
  { value: "Bundle", label: "Bundle" },
];

function isPresetPriceUnit(value?: string | null) {
  const normalizedValue = String(value || "")
    .trim()
    .toLowerCase();
  return PRICE_UNIT_OPTIONS.some(
    (option) => option.value.toLowerCase() === normalizedValue,
  );
}

function getSafeReturnPath(value: string | null) {
  return value?.startsWith("/") && !value.startsWith("//")
    ? value
    : "/products";
}

interface ProductImage {
  _id?: string;
  url: string;
  publicId: string;
  blurHash?: string | null;
  isPrimary: boolean;
  order: number;
  originalSize?: number;
  convertedSize?: number;
  savings?: string;
}

function resolvePreviewImageUrl(url: string) {
  const trimmed = String(url || "").trim();
  if (!trimmed) return "";

  if (/^https?:\/\//i.test(trimmed)) {
    return trimmed;
  }

  if (trimmed.startsWith("/")) {
    return buildApiUrl(trimmed).replace("/api/v1", "");
  }

  return buildApiUrl(`/${trimmed}`).replace("/api/v1", "");
}

function getImagePublicId(image: ProductImage) {
  const publicId = String(image.publicId || "").trim();
  if (publicId) return publicId;

  const imageId = String(image._id || "").trim();
  if (imageId) return imageId;

  const url = String(image.url || "").trim();
  if (url) return url;

  return `image-${Date.now()}`;
}

const numericString = z
  .string()
  .trim()
  .refine((val) => val === "" || !isNaN(Number(val)), "Must be a number");

const productSchema = z.object({
  name: z.string().min(2, "Name must be at least 2 characters"),
  nameHindi: z.string().optional().default(""),
  description: z.string().optional().default(""),
  shortDescription: z.string().optional(),
  bulletPoints: z.array(z.string()).optional(),
  category: z.string().min(1, "Category is required"),
  tags: z.string().optional().default(""),
  sku: z.string().optional().default(""),
  mrp: numericString.default(""),
  retailPrice: numericString.default(""),
  wholesalePrice: numericString.default(""),
  priceUnit: z.string().optional().default(""),
  packing: z.string().optional().default(""),
  priceChangeMode: z
    .enum(["schedule_24h", "immediate"])
    .default("schedule_24h"),
  stock: numericString.default("0"),
  lowStockThreshold: numericString.default("5"),
  minWholesaleQuantity: z
    .string()
    .refine((val) => !isNaN(Number(val)), "Must be a number"),
  negotiationEnabled: z.boolean().default(true),
  status: z.enum(["active", "draft", "archived"]),
  isFeatured: z.boolean().default(false),
  isHot: z.boolean().default(false),
  company: z.string().optional(),
  videoUrl: z.string().optional(),
  shippingTerms: z.string().optional(),
  labelIds: z.array(z.string()).default([]),
  rating: z
    .string()
    .refine((val) => !isNaN(Number(val)), "Must be a number")
    .default("4.5"),
  purchaseCountMin: z
    .string()
    .refine((val) => !isNaN(Number(val)), "Must be a number")
    .default("0"),
  purchaseCountMax: z
    .string()
    .refine((val) => !isNaN(Number(val)), "Must be a number")
    .default("0"),
});

export default function AddProductPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const editId = searchParams.get("edit");
  const isEditMode = !!editId;
  const requestedCategoryId = searchParams.get("categoryId");
  const returnPath = getSafeReturnPath(searchParams.get("returnTo"));

  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingProduct, setIsLoadingProduct] = useState(false);
  const [isInitialLoading, setIsInitialLoading] = useState(true);
  const [companies, setCompanies] = useState<Company[]>([]);
  const [categories, setCategories] = useState<Category[]>([]);
  const [availableLabels, setAvailableLabels] = useState<ProductLabelOption[]>(
    [],
  );
  const [isLoadingCategories, setIsLoadingCategories] = useState(true);
  const [isLoadingLabels, setIsLoadingLabels] = useState(true);
  const [showNewCategoryDialog, setShowNewCategoryDialog] = useState(false);
  const [newCategoryName, setNewCategoryName] = useState("");
  const [newCategoryCompanyId, setNewCategoryCompanyId] = useState("");
  const [isCreatingCategory, setIsCreatingCategory] = useState(false);
  const [images, setImages] = useState<ProductImage[]>([]);
  const [previewImageUrl, setPreviewImageUrl] = useState("");
  const [bulletPoints, setBulletPoints] = useState<string[]>([""]);
  const [isUploadingImage, setIsUploadingImage] = useState(false);
  const [uploadStatus, setUploadStatus] = useState<UploadStatus>("idle");
  const [isCustomPriceUnit, setIsCustomPriceUnit] = useState(false);
  const [lockedCategoryId, setLockedCategoryId] = useState<string | null>(null);
  const isCategoryLocked = !isEditMode && lockedCategoryId !== null;

  const form = useForm<z.infer<typeof productSchema>>({
    resolver: zodResolver(productSchema),
    defaultValues: {
      name: "",
      nameHindi: "",
      description: "",
      shortDescription: "",
      bulletPoints: [],
      category: "",
      tags: "",
      sku: "",
      mrp: "",
      retailPrice: "",
      wholesalePrice: "",
      priceUnit: "",
      packing: "",
      priceChangeMode: "schedule_24h",
      stock: "0",
      lowStockThreshold: "5",
      minWholesaleQuantity: "10",
      negotiationEnabled: true,
      status: "active",
      isFeatured: false,
      isHot: false,
      company: "",
      videoUrl: "",
      shippingTerms:
        "Delivery, payment, and return arrangements depend on the product, order, and location. Contact TradeHub Demo to confirm the applicable terms before payment or dispatch.",
      labelIds: [],
      rating: "4.5",
      purchaseCountMin: "0",
      purchaseCountMax: "0",
    },
  });

  useEffect(() => {
    const initData = async () => {
      setIsInitialLoading(true);

      // Fetch labels first - needed to display selected labels correctly
      await fetchLabels();

      // Fetch companies and categories in parallel
      const [, loadedCategories] = await Promise.all([
        fetchCompanies(),
        fetchCategories(),
      ]);

      if (!isEditMode && requestedCategoryId) {
        const selectedCategory = loadedCategories.find(
          (category) => category._id === requestedCategoryId,
        );

        if (selectedCategory) {
          const selectedCompanyId =
            typeof selectedCategory.company === "object" && selectedCategory.company
              ? selectedCategory.company._id
              : String(selectedCategory.company || "");
          form.setValue("category", selectedCategory._id);
          form.setValue("company", selectedCompanyId || "");
          setLockedCategoryId(selectedCategory._id);
        } else {
          setLockedCategoryId(null);
          toast.error("The selected category is no longer available.");
        }
      } else {
        setLockedCategoryId(null);
      }

      // Fetch product if in edit mode
      if (isEditMode && editId) {
        await fetchProduct(editId, loadedCategories);
      }

      setIsInitialLoading(false);
    };
    initData();
  }, [editId, isEditMode]);

  async function fetchProduct(
    id: string,
    loadedCategories: Category[] = categories,
  ) {
    setIsLoadingProduct(true);
    try {
      const res = await apiFetch(`/admin/products/${id}`);
      if (!res.ok) throw new Error("Product not found");

      const data = await res.json();
      const product = data.data;

      if (!product) throw new Error("Product data is empty");

      const productCompanyId = product.company?._id || product.company || "";
      const matchedCategory = loadedCategories.find((category) => {
        const categoryCompanyId =
          typeof category.company === "object" && category.company
            ? category.company._id
            : String(category.company || "");
        return (
          categoryCompanyId === productCompanyId &&
          (category.slug === product.category ||
            category.name === product.category)
        );
      });

      // Set form values
      setIsCustomPriceUnit(
        Boolean(product.priceUnit && !isPresetPriceUnit(product.priceUnit)),
      );
      form.reset({
        name: product.name || "",
        nameHindi: product.nameHindi || "",
        description: product.description || "",
        shortDescription: product.shortDescription || "",
        bulletPoints: [],
        category:
          product.categoryRef ||
          product.categoryId ||
          matchedCategory?._id ||
          "",
        tags: Array.isArray(product.tags) ? product.tags.join(", ") : "",
        sku: product.sku || "",
        mrp:
          product.mrp !== undefined && product.mrp !== null
            ? String(product.mrp)
            : "",
        retailPrice:
          product.pendingRetailPrice !== undefined &&
          product.pendingRetailPrice !== null
            ? String(product.pendingRetailPrice)
            : product.retailPrice !== undefined && product.retailPrice !== null
              ? String(product.retailPrice)
              : "",
        wholesalePrice:
          product.pendingWholesalePrice !== undefined &&
          product.pendingWholesalePrice !== null
            ? String(product.pendingWholesalePrice)
            : product.wholesalePrice !== undefined &&
                product.wholesalePrice !== null
              ? String(product.wholesalePrice)
              : "",
        priceUnit: product.priceUnit || "",
        packing: product.packing || "",
        priceChangeMode: "schedule_24h",
        stock: String(product.stock || "0"),
        lowStockThreshold: String(product.lowStockThreshold ?? "5"),
        minWholesaleQuantity: String(product.minWholesaleQuantity || "10"),
        negotiationEnabled: product.negotiationEnabled !== false,
        status: product.status || "draft",
        isFeatured: product.isFeatured || false,
        isHot: product.isHot || false,
        company: product.company?._id || product.company || "none",
        videoUrl: product.videoUrl || "",
        shippingTerms: product.shippingTerms || "",
        labelIds: Array.isArray(product.labelIds)
          ? product.labelIds.map((item: any) => String(item)).filter(Boolean)
          : [],
        rating: String(product.rating ?? "4.5"),
        purchaseCountMin: String(product.purchaseCountMin || "0"),
        purchaseCountMax: String(product.purchaseCountMax || "0"),
      });

      // Set images
      if (product.images && product.images.length > 0) {
        setImages(product.images);
      }

      // Set bullet points from specifications
      if (product.specifications && product.specifications.length > 0) {
        setBulletPoints(product.specifications.map((s: any) => s.value));
      }
    } catch (error) {
      console.error("Fetch product error:", error);
      toast.error("Failed to load product");
      router.push(returnPath);
    } finally {
      setIsLoadingProduct(false);
    }
  }

  async function fetchCategories(): Promise<Category[]> {
    try {
      // Authenticated so admin-only discount fields are included.
      const response = await apiFetch("/categories?page=1&limit=500");
      if (response.ok) {
        const data = await response.json();
        const nextCategories = Array.isArray(data.data) ? data.data : [];
        setCategories(nextCategories);
        return nextCategories;
      }
    } catch (error) {
      console.error("Failed to fetch categories:", error);
    } finally {
      setIsLoadingCategories(false);
    }
    return [];
  }

  async function fetchCompanies() {
    try {
      const response = await apiFetch("/companies?page=1&limit=500");
      if (response.ok) {
        const data = await response.json();
        const nextCompanies = Array.isArray(data.data) ? data.data : [];
        setCompanies(nextCompanies);
        setNewCategoryCompanyId(
          (current) => current || nextCompanies[0]?._id || "",
        );
      }
    } catch (error) {
      console.error("Failed to fetch companies:", error);
    }
  }

  async function fetchLabels() {
    try {
      const response = await apiFetch("/admin/website-settings");
      if (!response.ok) {
        throw new Error("Failed to load labels");
      }

      const data = await response.json();
      const nextLabels = Array.isArray(data?.data?.labels)
        ? data.data.labels
            .map((item: any, index: number) => {
              const labelId = String(item?.id || "").trim();
              return {
                // Only use actual ID, not title as fallback
                id: labelId || `label-${index}`,
                title: String(item?.title || "").trim(),
                sourceType: item?.sourceType === "image" ? "image" : "icon",
              };
            })
            .filter((item: ProductLabelOption) => item.title)
        : [];

      setAvailableLabels(nextLabels);
    } catch (error) {
      console.error("Failed to fetch labels:", error);
    } finally {
      setIsLoadingLabels(false);
    }
  }

  // Image management functions
  const formatBytes = (bytes: number) => {
    if (bytes === 0) return "0 B";
    const k = 1024;
    const sizes = ["B", "KB", "MB"];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + " " + sizes[i];
  };

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    setIsUploadingImage(true);
    setUploadStatus("converting");

    const formData = new FormData();

    // Upload multiple files
    for (let i = 0; i < files.length; i++) {
      formData.append("images", files[i]);
    }

    try {
      // Brief delay to show "converting" state
      await new Promise((r) => setTimeout(r, 300));
      setUploadStatus("uploading");

      const response = await apiFetch("/upload/images?folder=products", {
        method: "POST",
        body: formData,
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.message || "Upload failed");
      }

      const data = await response.json();

      setUploadStatus("done");

      if (data.success && data.data) {
        const newImages: ProductImage[] = data.data.map(
          (img: any, index: number) => ({
            url: img.url,
            publicId: img.publicId,
            isPrimary: images.length === 0 && index === 0,
            order: images.length + index,
            originalSize: img.originalSize,
            convertedSize: img.convertedSize,
            savings: img.savings,
          }),
        );
        setImages([...images, ...newImages]);

        // Show savings info
        const totalOriginal = data.data.reduce(
          (sum: number, img: any) => sum + (img.originalSize || 0),
          0,
        );
        const totalConverted = data.data.reduce(
          (sum: number, img: any) => sum + (img.convertedSize || 0),
          0,
        );
        if (totalOriginal > 0) {
          toast.success(
            `${newImages.length} image(s) converted to WebP & uploaded! Saved ${formatBytes(totalOriginal - totalConverted)} (${Math.round((1 - totalConverted / totalOriginal) * 100)}% smaller)`,
          );
        } else {
          toast.success(`${newImages.length} image(s) uploaded successfully`);
        }
      }

      // Keep "done" visible briefly
      await new Promise((r) => setTimeout(r, 1000));
    } catch (error: any) {
      console.error("Upload error:", error);
      toast.error(error.message || "Failed to upload images");
    } finally {
      setIsUploadingImage(false);
      setUploadStatus("idle");
      // Reset file input
      e.target.value = "";
    }
  };

  const removeImage = (index: number) => {
    const newImages = images.filter((_, i) => i !== index);
    // If we removed the primary image, make the first one primary
    if (images[index].isPrimary && newImages.length > 0) {
      newImages[0].isPrimary = true;
    }
    // Reorder
    newImages.forEach((img, i) => (img.order = i));
    setImages(newImages);
  };

  const setFeaturedImage = (index: number) => {
    const newImages = images.map((img, i) => ({
      ...img,
      isPrimary: i === index,
    }));
    setImages(newImages);
    toast.success("Featured image updated");
  };

  // Bullet points management
  const addBulletPoint = () => {
    setBulletPoints([...bulletPoints, ""]);
  };

  const updateBulletPoint = (index: number, value: string) => {
    const newPoints = [...bulletPoints];
    newPoints[index] = value;
    setBulletPoints(newPoints);
  };

  const removeBulletPoint = (index: number) => {
    if (bulletPoints.length === 1) return;
    setBulletPoints(bulletPoints.filter((_, i) => i !== index));
  };

  async function createNewCategory() {
    if (!newCategoryName.trim()) {
      toast.error("Category name is required");
      return;
    }

    if (!newCategoryCompanyId) {
      toast.error("Select a brand for this category");
      return;
    }

    setIsCreatingCategory(true);
    try {
      const response = await apiFetch("/categories", {
        method: "POST",
        body: JSON.stringify({
          name: newCategoryName.trim(),
          company: newCategoryCompanyId,
        }),
      });

      if (!response.ok) {
        const error = await response.json();
        throw new Error(error.message || "Failed to create category");
      }

      const data = await response.json();
      const newCategory = data.data;

      setCategories((prev) =>
        [...prev, newCategory].sort((a, b) => a.name.localeCompare(b.name)),
      );
      form.setValue("category", newCategory._id);
      form.setValue("company", newCategoryCompanyId);
      setNewCategoryName("");
      setShowNewCategoryDialog(false);
      toast.success(`Category "${newCategory.name}" created successfully`);
    } catch (error: any) {
      toast.error(error.message || "Failed to create category");
    } finally {
      setIsCreatingCategory(false);
    }
  }

  function getCategoryCompanyName(category: Category) {
    if (typeof category.company === "object" && category.company) {
      return category.company.name;
    }
    return (
      companies.find((company) => company._id === category.company)?.name ||
      "Brand not set"
    );
  }

  async function onSubmit(values: z.infer<typeof productSchema>) {
    setIsLoading(true);
    try {
      // Validate images
      if (images.length === 0) {
        toast.error("Please add at least one product image");
        setIsLoading(false);
        return;
      }

      // Filter out empty bullet points
      const validBulletPoints = bulletPoints.filter((bp) => bp.trim() !== "");
      const normalizedLabelIds = normalizeSelectedLabelIds(
        values.labelIds,
        availableLabels,
      );
      const normalizedTags = String(values.tags || "")
        .split(",")
        .map((tag) => tag.trim())
        .filter(Boolean);

      const normalizedImages = images.map((image, index) => ({
        url: String(image.url || "").trim(),
        publicId: getImagePublicId(image),
        isPrimary: image.isPrimary === true,
        order: Number.isFinite(Number(image.order))
          ? Number(image.order)
          : index,
      }));

      if (
        !values.sku.trim() ||
        values.mrp === "" ||
        values.retailPrice === "" ||
        values.wholesalePrice === ""
      ) {
        toast.error("Provide SKU, MRP, customer price, and wholesale price.");
        setIsLoading(false);
        return;
      }

      const selectedCategory = categories.find(
        (category) => category._id === values.category,
      );
      if (!selectedCategory) {
        toast.error("Select a valid category.");
        setIsLoading(false);
        return;
      }

      const selectedCategoryCompany =
        typeof selectedCategory.company === "object" && selectedCategory.company
          ? selectedCategory.company._id
          : String(selectedCategory.company || "");

      // Construct payload matching backend expectation
      const payload = {
        name: values.name.trim(),
        nameHindi: values.nameHindi?.trim() || null,
        description: values.description,
        shortDescription:
          values.shortDescription?.trim() ||
          values.description.substring(0, 200),
        category: selectedCategory.slug || selectedCategory.name,
        categoryId: selectedCategory._id,
        subCategory: null,
        tags: normalizedTags,
        sku: values.sku.trim() || undefined,
        status: values.status,
        mrp: values.mrp === "" ? undefined : Number(values.mrp),
        retailPrice:
          values.retailPrice === "" ? undefined : Number(values.retailPrice),
        wholesalePrice:
          values.wholesalePrice === ""
            ? undefined
            : Number(values.wholesalePrice),
        priceUnit: values.priceUnit?.trim() || null,
        packing: values.packing?.trim() || null,
        priceChangeMode: isEditMode ? values.priceChangeMode : undefined,
        stock: Number(values.stock),
        lowStockThreshold: Number(values.lowStockThreshold || 5),
        minWholesaleQuantity: Number(values.minWholesaleQuantity),
        negotiationEnabled: values.negotiationEnabled,
        isFeatured: values.isFeatured,
        isHot: values.isHot,
        company: selectedCategoryCompany || null,
        labelIds: normalizedLabelIds,
        images: normalizedImages,
        specifications: validBulletPoints.map((point, index) => ({
          key: `feature_${index + 1}`,
          value: point,
        })),
        videoUrl: values.videoUrl?.trim() || null,
        shippingTerms: values.shippingTerms?.trim() || null,
        rating: Number(values.rating),
        purchaseCountMin: Number(values.purchaseCountMin),
        purchaseCountMax: Number(values.purchaseCountMax),
        variants: [],
      };

      const endpoint = isEditMode
        ? `/admin/products/${editId}`
        : "/admin/products";

      const response = await apiFetch(endpoint, {
        method: isEditMode ? "PUT" : "POST",
        body: JSON.stringify(payload),
      });

      if (!response.ok) {
        let errorMessage = isEditMode
          ? "Failed to update product"
          : "Failed to create product";
        try {
          const errorData = await response.json();
          const validationDetails = errorData?.error?.details;
          errorMessage =
            (Array.isArray(validationDetails) && validationDetails.length > 0
              ? validationDetails
                  .map((detail: any) => detail?.message || detail?.field)
                  .filter(Boolean)
                  .join(", ")
              : "") ||
            errorData?.message ||
            errorData?.error?.message ||
            errorData?.errors?.[0]?.message ||
            errorMessage;
        } catch (_) {}

        throw new Error(errorMessage);
      }

      toast.success(
        isEditMode
          ? "Product updated successfully"
          : "Product created successfully",
      );
      router.push(returnPath);
    } catch (error: any) {
      console.error(error);
      toast.error(error?.message || "Something went wrong. Please try again.");
    } finally {
      setIsLoading(false);
    }
  }

  if (isInitialLoading) {
    return (
      <div className="flex justify-center items-center h-[400px]">
        <Loader2 className="h-8 w-8 animate-spin text-[#818cf8]" />
      </div>
    );
  }

  return (
    <div className="w-full max-w-none">
      <div className="sticky top-0 z-30 -mx-4 -mt-4 mb-6 flex flex-wrap items-center gap-3 border-b border-blue-100 bg-[#eff6ff]/95 px-4 py-3 backdrop-blur supports-[backdrop-filter]:bg-[#eff6ff]/85 sm:-mx-5 sm:-mt-5 sm:px-5 md:-mx-6 md:-mt-6 md:mb-8 md:px-6 dark:border-slate-800 dark:bg-slate-950/95">
        <NextLink href={returnPath}>
          <Button
            variant="ghost"
            size="icon"
            className="text-gray-400 hover:text-white"
          >
            <ArrowLeft className="h-5 w-5" />
          </Button>
        </NextLink>
        <div className="flex-1">
          <h1 className="text-3xl font-bold text-white">
            {isEditMode ? "Edit Product" : "Add New Product"}
          </h1>
        </div>
        <div className="flex items-center gap-3">
          <Button
            type="button"
            variant="ghost"
            className="text-gray-400 hover:text-white"
            onClick={() => router.push(returnPath)}
          >
            Cancel
          </Button>
          <Button
            onClick={() => form.handleSubmit(onSubmit)()}
            disabled={isLoading}
            className="px-8"
          >
            {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
            {isEditMode ? "Update" : "Create"}
          </Button>
        </div>
      </div>

      <Form {...form}>
        <form
          onSubmit={form.handleSubmit(onSubmit)}
          className="product-editor-form space-y-8"
        >
          <div className="grid grid-cols-1 items-start gap-8 md:grid-cols-2">
            <Card
              className="product-editor-left-card overflow-hidden bg-[#161616] border-[#333]"
              style={{ gap: 0, paddingBlock: 0 }}
            >
              <section className="product-editor-left-section">
                <CardContent className="pt-6">
                  <FormField
                    control={form.control}
                    name="name"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-white">
                          Product Name
                        </FormLabel>
                        <FormControl>
                          <Input
                            placeholder="Enter product name"
                            {...field}
                            className="bg-[#0D0D0D] border-[#333] text-white"
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="nameHindi"
                    render={({ field }) => (
                      <FormItem className="mt-4">
                        <div className="flex items-center justify-between gap-2">
                          <FormLabel className="text-white">
                            Product Name (Hindi)
                          </FormLabel>
                          <SuggestHindiButton
                            text={form.watch("name") || ""}
                            onSuggest={(hindi) => form.setValue("nameHindi", hindi, { shouldDirty: true })}
                            className="h-7 border-[#333] bg-[#0D0D0D] text-xs text-white hover:bg-[#1A1A1A]"
                          />
                        </div>
                        <FormControl>
                          <Input
                            placeholder="Leave empty to fill automatically"
                            {...field}
                            className="bg-[#0D0D0D] border-[#333] text-white"
                          />
                        </FormControl>
                        <FormDescription className="text-gray-500">
                          Shown in the app when Hindi is selected. {HINDI_AUTO_NOTE} A name you type here is never replaced.
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="description"
                    render={({ field }) => (
                      <FormItem className="mt-4">
                        <FormLabel className="text-white">
                          Description
                        </FormLabel>
                        <FormControl>
                          <Textarea
                            placeholder="Product description"
                            {...field}
                            className="bg-[#0D0D0D] border-[#333] text-white min-h-[100px]"
                          />
                        </FormControl>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="shortDescription"
                    render={({ field }) => (
                      <FormItem className="mt-4">
                        <FormLabel className="text-white">
                          Short Description
                        </FormLabel>
                        <FormControl>
                          <Textarea
                            placeholder="Optional short summary for cards and previews"
                            {...field}
                            className="bg-[#0D0D0D] border-[#333] text-white min-h-[90px]"
                          />
                        </FormControl>
                        <FormDescription className="text-gray-500">
                          If left empty, the backend will derive it from the
                          full description.
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <div className="grid gap-4 mt-4">
                    <FormField
                      control={form.control}
                      name="category"
                      render={({ field }) => (
                        <FormItem className="product-floating-exempt">
                          <FormLabel className="text-white">Category</FormLabel>
                          <div className="flex gap-2">
                            <Popover>
                              <PopoverTrigger asChild>
                                <FormControl>
                                  <Button
                                    type="button"
                                    variant="outline"
                                    disabled={isCategoryLocked}
                                    className="flex-1 justify-between border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A] disabled:cursor-not-allowed disabled:opacity-70"
                                  >
                                    <span className="truncate">
                                      {field.value
                                        ? categories.find(
                                            (category) =>
                                              category._id === field.value,
                                          )?.name || field.value
                                        : isLoadingCategories
                                          ? "Loading categories..."
                                          : "Select category"}
                                    </span>
                                    <ChevronDown className="ml-2 h-4 w-4 shrink-0 text-[#8d8d8d]" />
                                  </Button>
                                </FormControl>
                              </PopoverTrigger>
                              <PopoverContent
                                align="start"
                                className="w-[360px] border-[#333] bg-[#111] p-0 text-white"
                              >
                                <Command className="bg-[#111] text-white">
                                  <CommandInput
                                    placeholder="Search categories..."
                                    className="text-white placeholder:text-[#7d7d7d]"
                                  />
                                  <CommandList>
                                    <CommandEmpty className="text-[#8d8d8d]">
                                      No category found.
                                    </CommandEmpty>
                                    {categories.map((category) => (
                                      <CommandItem
                                        key={category._id}
                                        value={`${category.name} ${category.slug} ${getCategoryCompanyName(category)}`}
                                        onSelect={() => {
                                          field.onChange(category._id);
                                          const companyId =
                                            typeof category.company ===
                                              "object" && category.company
                                              ? category.company._id
                                              : String(category.company || "");
                                          form.setValue(
                                            "company",
                                            companyId || "none",
                                          );
                                        }}
                                        className="flex items-center justify-between rounded-none px-3 py-2 text-white aria-selected:bg-[#1A1A1A]"
                                      >
                                        <div className="min-w-0">
                                          <p className="truncate text-sm font-medium">
                                            {category.name}
                                          </p>
                                          <p className="truncate text-xs text-[#7d7d7d]">
                                            {getCategoryCompanyName(category)} /{" "}
                                            {category.slug}
                                          </p>
                                        </div>
                                        <Check
                                          className={`h-4 w-4 ${field.value === category._id ? "text-[#818cf8]" : "text-transparent"}`}
                                        />
                                      </CommandItem>
                                    ))}
                                  </CommandList>
                                </Command>
                              </PopoverContent>
                            </Popover>
                            <Dialog
                              open={showNewCategoryDialog}
                              onOpenChange={setShowNewCategoryDialog}
                            >
                              <DialogTrigger asChild>
                                <Button
                                  type="button"
                                  variant="outline"
                                  size="icon"
                                  disabled={isCategoryLocked}
                                  className="border-[#333] bg-[#1A1A1A] text-white hover:bg-[#333] disabled:cursor-not-allowed disabled:opacity-50"
                                >
                                  <Plus className="h-4 w-4" />
                                </Button>
                              </DialogTrigger>
                              <DialogContent className="bg-[#161616] border-[#333]">
                                <DialogHeader>
                                  <DialogTitle className="text-white">
                                    Add New Category
                                  </DialogTitle>
                                  <DialogDescription className="text-gray-400">
                                    Create a new category for your products.
                                  </DialogDescription>
                                </DialogHeader>
                                <div className="space-y-4 py-4">
                                  <div>
                                    <label className="text-sm font-medium text-white mb-2 block">
                                      Brand *
                                    </label>
                                    <Select
                                      value={newCategoryCompanyId}
                                      onValueChange={setNewCategoryCompanyId}
                                    >
                                      <SelectTrigger className="bg-[#0D0D0D] border-[#333] text-white">
                                        <SelectValue placeholder="Select brand" />
                                      </SelectTrigger>
                                      <SelectContent className="product-editor-select-content border-blue-200! bg-white! text-slate-900! dark:border-[#333]! dark:bg-[#0D0D0D]! dark:text-white! bg-[#0D0D0D] border-[#333]">
                                        {companies.map((company) => (
                                          <SelectItem
                                            key={company._id}
                                            value={company._id}
                                          >
                                            {company.name}
                                          </SelectItem>
                                        ))}
                                      </SelectContent>
                                    </Select>
                                  </div>
                                  <Input
                                    placeholder="Category name (e.g., Machinery, Seeds)"
                                    value={newCategoryName}
                                    onChange={(e) =>
                                      setNewCategoryName(e.target.value)
                                    }
                                    className="bg-[#0D0D0D] border-[#333] text-white"
                                  />
                                </div>
                                <DialogFooter>
                                  <Button
                                    type="button"
                                    variant="outline"
                                    onClick={() =>
                                      setShowNewCategoryDialog(false)
                                    }
                                    className="border-[#333] text-gray-400 hover:text-white"
                                  >
                                    Cancel
                                  </Button>
                                  <Button
                                    type="button"
                                    onClick={createNewCategory}
                                    disabled={isCreatingCategory}
                                  >
                                    {isCreatingCategory && (
                                      <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                                    )}
                                    Create Category
                                  </Button>
                                </DialogFooter>
                              </DialogContent>
                            </Dialog>
                          </div>
                          <FormDescription className="text-gray-500">
                            {isCategoryLocked
                              ? "This category was selected from its product page and cannot be changed here."
                              : "Pick the brand-specific category. Brand is assigned from the selected category."}
                          </FormDescription>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>

                  <div className="mt-4">
                    <FormField
                      control={form.control}
                      name="tags"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">Tags</FormLabel>
                          <FormControl>
                            <Input
                              placeholder="cable, copper, 3-core"
                              {...field}
                              className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                          </FormControl>
                          <FormDescription className="text-gray-500">
                            Comma-separated tags used for search and filtering.
                          </FormDescription>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>
                </CardContent>
              </section>

              {/* Product Images Card */}
              <section className="product-editor-left-section product-editor-image-section border-t border-blue-100 dark:border-slate-700">
                <CardContent className="p-4">
                  <div className="mb-3">
                    <h3 className="flex items-center gap-2 font-medium text-white">
                      <ImagePlus className="h-4 w-4" />
                      Product Images
                    </h3>
                  </div>

                  <div className="mb-3">
                    <label
                        className={`flex flex-col items-center justify-center w-full border-2 border-dashed rounded-lg transition-colors ${
                          isUploadingImage
                            ? "border-[#818cf8]/50 bg-[#818cf8]/5 cursor-wait"
                            : "border-[#333] bg-[#0D0D0D] hover:bg-[#1a1a1a] cursor-pointer"
                        } ${isUploadingImage ? "h-24" : "h-20"}`}
                      >
                        <div className="flex flex-col items-center justify-center py-2">
                          {isUploadingImage ? (
                            <div className="flex flex-col items-center gap-2 w-full px-6">
                              {/* Step indicators */}
                              <div className="flex items-center gap-1 text-xs">
                                <span
                                  className={`flex items-center gap-1 px-2 py-0.5 rounded-full ${
                                    uploadStatus === "converting"
                                      ? "bg-yellow-500/20 text-yellow-400"
                                      : uploadStatus === "uploading" ||
                                          uploadStatus === "done"
                                        ? "bg-green-500/20 text-green-400"
                                        : "bg-gray-500/20 text-gray-500"
                                  }`}
                                >
                                  {uploadStatus === "converting" ? (
                                    <Loader2 className="h-3 w-3 animate-spin" />
                                  ) : (
                                    <span className="text-[10px]">✓</span>
                                  )}
                                  Converting to WebP
                                </span>
                                <span className="text-gray-600">→</span>
                                <span
                                  className={`flex items-center gap-1 px-2 py-0.5 rounded-full ${
                                    uploadStatus === "uploading"
                                      ? "bg-blue-500/20 text-blue-400"
                                      : uploadStatus === "done"
                                        ? "bg-green-500/20 text-green-400"
                                        : "bg-gray-500/20 text-gray-500"
                                  }`}
                                >
                                  {uploadStatus === "uploading" ? (
                                    <Loader2 className="h-3 w-3 animate-spin" />
                                  ) : uploadStatus === "done" ? (
                                    <span className="text-[10px]">✓</span>
                                  ) : (
                                    <span className="text-[10px]">○</span>
                                  )}
                                  Uploading
                                </span>
                                <span className="text-gray-600">→</span>
                                <span
                                  className={`flex items-center gap-1 px-2 py-0.5 rounded-full ${
                                    uploadStatus === "done"
                                      ? "bg-green-500/20 text-green-400"
                                      : "bg-gray-500/20 text-gray-500"
                                  }`}
                                >
                                  {uploadStatus === "done" ? (
                                    <span className="text-[10px]">✓</span>
                                  ) : (
                                    <span className="text-[10px]">○</span>
                                  )}
                                  Done
                                </span>
                              </div>
                              {/* Progress bar */}
                              <div className="w-full bg-[#333] rounded-full h-1.5">
                                <div
                                  className={`h-1.5 rounded-full transition-all duration-500 ${
                                    uploadStatus === "converting"
                                      ? "w-1/3 bg-yellow-500"
                                      : uploadStatus === "uploading"
                                        ? "w-2/3 bg-blue-500"
                                        : "w-full bg-green-500"
                                  }`}
                                />
                              </div>
                              <p className="text-xs text-gray-500">
                                {uploadStatus === "converting" &&
                                  "Converting images to WebP for smaller file sizes..."}
                                {uploadStatus === "uploading" &&
                                  "Uploading optimized images to storage..."}
                                {uploadStatus === "done" && "Upload complete!"}
                              </p>
                            </div>
                          ) : (
                            <>
                              <Upload className="h-6 w-6 text-gray-400 mb-2" />
                              <p className="text-sm text-gray-400">
                                <span className="text-[#818cf8]">
                                  Click to upload
                                </span>{" "}
                                or drag and drop
                              </p>
                              <p className="text-xs text-gray-500">
                                PNG, JPG, GIF, WebP (max 5MB) — auto-converted
                                to WebP
                              </p>
                            </>
                          )}
                        </div>
                        <input
                          type="file"
                          className="hidden"
                          accept="image/jpeg,image/png,image/gif,image/webp"
                          multiple
                          onChange={handleFileUpload}
                          disabled={isUploadingImage}
                        />
                      </label>
                  </div>

                  {/* Images Grid */}
                  {images.length > 0 ? (
                    <div className="flex flex-wrap gap-2">
                      {images.map((img, index) => (
                        <div
                          key={index}
                          className={`relative h-24 w-24 group rounded-lg overflow-hidden border-2 ${
                            img.isPrimary ? "border-[#818cf8]" : "border-[#333]"
                          }`}
                        >
                          <img
                            src={resolvePreviewImageUrl(img.url)}
                            alt={`Product ${index + 1}`}
                            className="h-full w-full cursor-zoom-in object-cover"
                            onClick={() =>
                              setPreviewImageUrl(resolvePreviewImageUrl(img.url))
                            }
                            onError={(e) => {
                              (e.target as HTMLImageElement).src =
                                "https://placehold.co/200x200/1a1a1a/666?text=Error";
                            }}
                          />
                          {/* Featured Badge */}
                          {img.isPrimary && (
                            <div className="absolute top-1 left-1 is-active text-[10px] px-1.5 py-0.5 rounded flex items-center gap-1">
                              <Crown className="h-3 w-3" />
                              Featured
                            </div>
                          )}
                          {/* WebP savings badge */}
                          {img.savings && (
                            <div className="absolute bottom-1 left-1 bg-blue-600/80 text-white text-[9px] px-1.5 py-0.5 rounded">
                              WebP {img.savings} saved
                            </div>
                          )}
                          {/* Actions Overlay */}
                          <div className="absolute inset-0 bg-black/60 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2">
                            {!img.isPrimary && (
                              <Button
                                type="button"
                                size="sm"
                                variant="outline"
                                onClick={() => setFeaturedImage(index)}
                                className="h-7 text-xs border-[#818cf8] text-[#818cf8] hover:bg-[#818cf8]/20"
                              >
                                <Crown className="h-3 w-3 mr-1" />
                                Set Featured
                              </Button>
                            )}
                            <Button
                              type="button"
                              size="sm"
                              variant="destructive"
                              onClick={() => removeImage(index)}
                              className="h-7 w-7 p-0"
                            >
                              <X className="h-3 w-3" />
                            </Button>
                          </div>
                        </div>
                      ))}
                    </div>
                  ) : (
                    <div className="border-2 border-dashed border-[#333] rounded-lg p-4 text-center">
                      <ImagePlus className="h-6 w-6 mx-auto text-gray-500 mb-2" />
                      <p className="text-gray-500 text-sm">
                        No images added yet
                      </p>
                      <p className="text-gray-600 text-xs mt-1">
                        Upload one or more product images above
                      </p>
                    </div>
                  )}
                  <p className="text-gray-500 text-xs mt-2">
                    First image will be featured by default. Click "Set
                    Featured" to change.
                  </p>
                </CardContent>
              </section>

              {/* Bullet Points / Features Card */}
              <section className="product-editor-left-section border-t border-blue-100 dark:border-slate-700">
                <CardContent className="p-4">
                  <div className="flex items-center justify-between mb-3">
                    <h3 className="text-white font-medium">
                      Key Features / Bullet Points
                    </h3>
                    <Button
                      type="button"
                      size="sm"
                      variant="outline"
                      onClick={addBulletPoint}
                      className="border-[#333]"
                    >
                      <Plus className="h-3 w-3 mr-1" />
                      Add Point
                    </Button>
                  </div>
                  <div className="space-y-2">
                    {bulletPoints.map((point, index) => (
                      <div key={index} className="flex gap-2 items-center">
                        <span className="text-[#818cf8] text-sm">•</span>
                        <Input
                          placeholder={`Feature ${index + 1}...`}
                          value={point}
                          onChange={(e) =>
                            updateBulletPoint(index, e.target.value)
                          }
                          className="bg-[#0D0D0D] border-[#333] text-white flex-1"
                        />
                        <Button
                          type="button"
                          size="sm"
                          variant="ghost"
                          onClick={() => removeBulletPoint(index)}
                          disabled={bulletPoints.length === 1}
                          className="h-8 w-8 p-0 text-gray-500 hover:text-red-400"
                        >
                          <X className="h-4 w-4" />
                        </Button>
                      </div>
                    ))}
                  </div>
                  <p className="text-gray-500 text-xs mt-2">
                    Add key features that will be displayed as bullet points on
                    the product page.
                  </p>
                </CardContent>
              </section>

              {/* YouTube Video URL */}
              <section className="product-editor-left-section border-t border-blue-100 dark:border-slate-700">
                <CardContent className="p-4">
                  <FormField
                    control={form.control}
                    name="videoUrl"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-white flex items-center gap-2">
                          <Youtube className="h-4 w-4 text-red-500" />
                          Product Demo Video (YouTube)
                        </FormLabel>
                        <FormControl>
                          <Input
                            placeholder="https://www.youtube.com/watch?v=..."
                            {...field}
                            className="bg-[#0D0D0D] border-[#333] text-white"
                          />
                        </FormControl>
                        <FormDescription className="text-gray-500">
                          Paste a YouTube video link. Supports
                          youtube.com/watch, youtu.be, and shorts URLs. This
                          will be shown as a playable video on the product page.
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </CardContent>
              </section>

              {/* Shipping & Return Terms */}
              <section className="product-editor-left-section border-t border-blue-100 dark:border-slate-700">
                <CardContent className="p-4">
                  <FormField
                    control={form.control}
                    name="shippingTerms"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-white flex items-center gap-2">
                          <Truck className="h-4 w-4 text-blue-400" />
                          Shipping & Return Terms
                        </FormLabel>
                        <FormControl>
                          <Textarea
                            placeholder="Enter shipping and return policy..."
                            {...field}
                            className="bg-[#0D0D0D] border-[#333] text-white min-h-[96px]"
                          />
                        </FormControl>
                        <FormDescription className="text-gray-500">
                          Pre-filled with default terms. Edit to customize for
                          this product. Displayed under &quot;Shipping &amp;
                          Returns&quot; on the product page.
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />
                </CardContent>
              </section>
            </Card>

            <div className="space-y-8">
              <Card className="bg-[#161616] border-[#333]">
                <CardContent className="pt-6 space-y-4">
                  <div className="space-y-1">
                    <h3 className="text-white font-medium">
                      Base Pricing & Inventory
                    </h3>
                    <p className="text-xs text-gray-500">
                      These fields control the product price, stock, packing,
                      and unit shown in the app.
                    </p>
                  </div>

                  {isEditMode ? (
                    <FormField
                      control={form.control}
                      name="priceChangeMode"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">
                            Price Change Mode
                          </FormLabel>
                          <Select
                            onValueChange={field.onChange}
                            value={field.value}
                          >
                            <FormControl>
                              <SelectTrigger className="bg-[#0D0D0D] border-[#333] text-white">
                                <SelectValue placeholder="Select price change mode" />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent className="product-editor-select-content border-blue-200! bg-white! text-slate-900! dark:border-[#333]! dark:bg-[#0D0D0D]! dark:text-white! bg-[#111111] border-[#333] text-white">
                              <SelectItem value="schedule_24h">
                                Schedule after 24 hours
                              </SelectItem>
                              <SelectItem value="immediate">
                                Immediate change
                              </SelectItem>
                            </SelectContent>
                          </Select>
                          <FormDescription className="text-gray-500">
                            Scheduled changes notify users and show a countdown
                            in the app. Immediate changes go live now and clear
                            any pending schedule for this save.
                          </FormDescription>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  ) : null}

                  <FormField
                    control={form.control}
                    name="sku"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-white">Base SKU</FormLabel>
                        <FormControl>
                          <Input
                            placeholder="PROD-001"
                            {...field}
                            className="bg-[#0D0D0D] border-[#333] text-white"
                          />
                        </FormControl>
                        <FormDescription className="text-gray-500">
                          Main product stock code shown in admin and app.
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="mrp"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-white">MRP (₹)</FormLabel>
                        <FormControl>
                          <Input
                            type="number"
                            placeholder="0.00"
                            {...field}
                            className="bg-[#0D0D0D] border-[#333] text-white"
                          />
                        </FormControl>
                        <FormDescription className="text-gray-500">
                          Maximum Retail Price - shown as original price
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <div className="grid grid-cols-2 gap-4">
                    <FormField
                      control={form.control}
                      name="retailPrice"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">
                            Customer Price (₹)
                          </FormLabel>
                          <FormControl>
                            <Input
                              type="number"
                              placeholder="0.00"
                              {...field}
                              className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                          </FormControl>
                          <FormDescription className="text-gray-500">
                            Price shown to regular customers
                          </FormDescription>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="wholesalePrice"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">
                            Wholesale Price (₹)
                          </FormLabel>
                          <FormControl>
                            <Input
                              type="number"
                              placeholder="0.00"
                              {...field}
                              className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                          </FormControl>
                          <FormDescription className="text-gray-500">
                            Price shown to wholesalers only
                          </FormDescription>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>

                  {(() => {
                    const selectedCategory = categories.find(
                      (category) => category._id === form.watch("category"),
                    );
                    const brandId = selectedCategory
                      ? typeof selectedCategory.company === "object" && selectedCategory.company
                        ? selectedCategory.company._id
                        : String(selectedCategory.company || "")
                      : "";
                    return (
                      <EffectivePricePreview
                        mrp={form.watch("mrp")}
                        retailPrice={form.watch("retailPrice")}
                        wholesalePrice={form.watch("wholesalePrice")}
                        brand={companies.find((company) => company._id === brandId) || null}
                        categoryId={selectedCategory?._id ?? null}
                        categories={categories}
                      />
                    );
                  })()}

                  <div className="grid grid-cols-2 gap-4">
                    <FormField
                      control={form.control}
                      name="priceUnit"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">
                            Price Unit
                          </FormLabel>
                          <Select
                            value={
                              isCustomPriceUnit
                                ? "__custom"
                                : field.value || undefined
                            }
                            onValueChange={(value) => {
                              if (value === "__custom") {
                                setIsCustomPriceUnit(true);
                                field.onChange("");
                                return;
                              }

                              setIsCustomPriceUnit(false);
                              field.onChange(value);
                            }}
                          >
                            <FormControl>
                              <SelectTrigger className="bg-[#0D0D0D] border-[#333] text-white">
                                <SelectValue placeholder="Select price unit" />
                              </SelectTrigger>
                            </FormControl>
                            <SelectContent className="product-editor-select-content border-blue-200! bg-white! text-slate-900! dark:border-[#333]! dark:bg-[#0D0D0D]! dark:text-white! bg-[#161616] border-[#333] text-white">
                              {PRICE_UNIT_OPTIONS.map((option) => (
                                <SelectItem
                                  key={option.value}
                                  value={option.value}
                                >
                                  {option.label}
                                </SelectItem>
                              ))}
                              <SelectItem value="__custom">
                                Add new unit
                              </SelectItem>
                            </SelectContent>
                          </Select>
                          {isCustomPriceUnit && (
                            <FormControl>
                              <Input
                                placeholder="Enter new unit"
                                value={field.value || ""}
                                onChange={field.onChange}
                                onBlur={field.onBlur}
                                name={field.name}
                                ref={field.ref}
                                className="mt-3 bg-[#0D0D0D] border-[#333] text-white"
                              />
                            </FormControl>
                          )}
                          <FormDescription className="text-gray-500">
                            Select the billing unit, or add a custom one.
                          </FormDescription>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="packing"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">Packing</FormLabel>
                          <FormControl>
                            <Input
                              placeholder="e.g. 90m coil, 30 pcs/box"
                              {...field}
                              className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                          </FormControl>
                          <FormDescription className="text-gray-500">
                            Packaging or pack size shown to customers.
                          </FormDescription>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <FormField
                      control={form.control}
                      name="stock"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">Stock</FormLabel>
                          <FormControl>
                            <Input
                              type="number"
                              placeholder="0"
                              {...field}
                              className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="lowStockThreshold"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">
                            Low Stock Threshold
                          </FormLabel>
                          <FormControl>
                            <Input
                              type="number"
                              placeholder="5"
                              {...field}
                              className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>

                  <div className="grid grid-cols-2 gap-4">
                    <FormField
                      control={form.control}
                      name="minWholesaleQuantity"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">
                            Min Wholesale Qty
                          </FormLabel>
                          <FormControl>
                            <Input
                              type="number"
                              placeholder="10"
                              {...field}
                              className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="negotiationEnabled"
                      render={({ field }) => (
                        <FormItem className="flex items-center justify-between rounded-lg border border-[#333] p-3 bg-[#0D0D0D] self-end">
                          <div className="space-y-0.5">
                            <FormLabel className="text-white">
                              Wholesaler Negotiation
                            </FormLabel>
                            <FormDescription className="text-xs text-gray-500">
                              Allow negotiation requests for this product.
                            </FormDescription>
                          </div>
                          <FormControl>
                            <Switch
                              checked={field.value}
                              onCheckedChange={field.onChange}
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                  </div>

                  <FormField
                    control={form.control}
                    name="status"
                    render={({ field }) => (
                      <FormItem>
                        <FormLabel className="text-white">Status</FormLabel>
                        <Select
                          onValueChange={field.onChange}
                          defaultValue={field.value}
                        >
                          <FormControl>
                            <SelectTrigger className="bg-[#0D0D0D] border-[#333] text-white">
                              <SelectValue placeholder="Select status" />
                            </SelectTrigger>
                          </FormControl>
                          <SelectContent className="product-editor-select-content border-blue-200! bg-white! text-slate-900! dark:border-[#333]! dark:bg-[#0D0D0D]! dark:text-white! bg-[#0D0D0D] border-[#333]">
                            <SelectItem value="active">Active</SelectItem>
                            <SelectItem value="draft">Draft</SelectItem>
                            <SelectItem value="archived">Archived</SelectItem>
                          </SelectContent>
                        </Select>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <FormField
                    control={form.control}
                    name="rating"
                    render={({ field }) => (
                      <FormItem className="mt-4">
                        <FormLabel className="text-white flex items-center gap-2">
                          <Star className="h-4 w-4 text-yellow-500" />
                          Admin Rating (0-5)
                        </FormLabel>
                        <FormControl>
                          <Input
                            type="number"
                            step="0.1"
                            min="0"
                            max="5"
                            placeholder="4.5"
                            {...field}
                            className="bg-[#0D0D0D] border-[#333] text-white"
                          />
                        </FormControl>
                        <FormDescription className="text-gray-500">
                          Initial rating for the product visibility.
                        </FormDescription>
                        <FormMessage />
                      </FormItem>
                    )}
                  />

                  <div className="grid grid-cols-2 gap-4 mt-4">
                    <FormField
                      control={form.control}
                      name="purchaseCountMin"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">
                            Min Purchase Count
                          </FormLabel>
                          <FormControl>
                            <Input
                              type="number"
                              placeholder="0"
                              {...field}
                              className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="purchaseCountMax"
                      render={({ field }) => (
                        <FormItem>
                          <FormLabel className="text-white">
                            Max Purchase Count
                          </FormLabel>
                          <FormControl>
                            <Input
                              type="number"
                              placeholder="50"
                              {...field}
                              className="bg-[#0D0D0D] border-[#333] text-white"
                            />
                          </FormControl>
                          <FormMessage />
                        </FormItem>
                      )}
                    />
                  </div>
                  <FormDescription className="text-gray-500 mt-1">
                    A random number between these two values will be shown as
                    live purchases, changing every 24 hours.
                  </FormDescription>
                </CardContent>
              </Card>

              {/* Company & Product Flags */}
              <Card className="bg-[#161616] border-[#333]">
                <CardContent className="pt-6 space-y-4">
                  <h3 className="text-white font-medium mb-4">
                    Company & Visibility
                  </h3>

                  <div className="rounded-lg border border-[#333] bg-[#0D0D0D] p-3">
                    <div className="flex items-center gap-2 text-sm font-medium text-white">
                      <Building2 className="h-4 w-4 text-[#818cf8]" />
                      Brand is assigned by category
                    </div>
                    <p className="mt-1 text-sm text-gray-400">
                      {(() => {
                        const selectedCategory = categories.find(
                          (category) => category._id === form.watch("category"),
                        );
                        return selectedCategory
                          ? getCategoryCompanyName(selectedCategory)
                          : "Select a category to set the brand automatically.";
                      })()}
                    </p>
                  </div>

                  <FormField
                    control={form.control}
                    name="labelIds"
                    render={({ field }) => {
                      const selectedIds = Array.isArray(field.value)
                        ? field.value
                        : [];
                      const selectedLabels = availableLabels.filter((label) =>
                        selectedIds.some((value) => labelMatches(value, label)),
                      );

                      const toggleLabel = (
                        labelId: string,
                        checked: boolean,
                      ) => {
                        const targetLabel = availableLabels.find(
                          (label) => label.id === labelId,
                        );
                        const nextValue = checked
                          ? targetLabel &&
                            selectedIds.some((value) =>
                              labelMatches(value, targetLabel),
                            )
                            ? selectedIds
                            : [...selectedIds, labelId]
                          : targetLabel
                            ? selectedIds.filter(
                                (item) => !labelMatches(item, targetLabel),
                              )
                            : selectedIds.filter((item) => item !== labelId);
                        field.onChange(nextValue);
                      };

                      return (
                        <FormItem className="product-floating-exempt">
                          <FormLabel className="text-white flex items-center gap-2">
                            <Tags className="h-4 w-4 text-[#818cf8]" />
                            Product Labels
                          </FormLabel>
                          <Popover>
                            <PopoverTrigger asChild>
                              <FormControl>
                                <Button
                                  type="button"
                                  variant="outline"
                                  className="w-full justify-between border-[#333] bg-[#0D0D0D] text-white hover:bg-[#1A1A1A]"
                                >
                                  <span className="truncate text-left">
                                    {isLoadingLabels
                                      ? "Loading labels..."
                                      : selectedLabels.length > 0
                                        ? selectedLabels
                                            .map((label) => label.title)
                                            .join(", ")
                                        : availableLabels.length > 0
                                          ? "Select product labels"
                                          : "No labels created yet"}
                                  </span>
                                  <ChevronDown className="ml-2 h-4 w-4 shrink-0 text-[#8d8d8d]" />
                                </Button>
                              </FormControl>
                            </PopoverTrigger>
                            <PopoverContent
                              align="start"
                              className="w-[340px] border-[#333] bg-[#111] p-2 text-white"
                            >
                              {availableLabels.length === 0 ? (
                                <p className="px-2 py-3 text-sm text-[#8d8d8d]">
                                  Create labels first in the Labels page, then
                                  come back here to assign them.
                                </p>
                              ) : (
                                <div className="max-h-72 space-y-1 overflow-y-auto">
                                  {availableLabels.map((label) => {
                                    const isChecked = selectedIds.some(
                                      (value) => labelMatches(value, label),
                                    );

                                    return (
                                      <label
                                        key={label.id}
                                        className="flex cursor-pointer items-start gap-3 rounded-xl border border-transparent px-3 py-2 transition-colors hover:border-[#2d2d2d] hover:bg-[#1A1A1A]"
                                      >
                                        <Checkbox
                                          checked={isChecked}
                                          onCheckedChange={(checked) =>
                                            toggleLabel(
                                              label.id,
                                              checked === true,
                                            )
                                          }
                                          className="mt-0.5 border-[#4d4d4d] data-[state=checked]:border-[#818cf8] data-[state=checked]:bg-[#818cf8] data-[state=checked]:text-black"
                                        />
                                        <div className="min-w-0">
                                          <p className="truncate text-sm font-medium text-white">
                                            {label.title}
                                          </p>
                                          <p className="text-xs text-[#7d7d7d]">
                                            {label.sourceType === "image"
                                              ? "Image label"
                                              : "Icon label"}
                                          </p>
                                        </div>
                                      </label>
                                    );
                                  })}
                                </div>
                              )}
                            </PopoverContent>
                          </Popover>
                          <FormDescription className="text-gray-500">
                            Selected labels will be available on the product
                            detail page in the app.
                          </FormDescription>
                          {selectedLabels.length > 0 && (
                            <div className="flex flex-wrap gap-2 pt-1">
                              {selectedLabels.map((label) => (
                                <span
                                  key={label.id}
                                  className="product-label-pill rounded-full border border-blue-300! bg-blue-100! px-2.5 py-1 text-xs font-medium text-blue-950! dark:border-blue-600! dark:bg-blue-950! dark:text-blue-100!"
                                >
                                  {label.title}
                                </span>
                              ))}
                            </div>
                          )}
                          <FormMessage />
                        </FormItem>
                      );
                    }}
                  />

                  {/* Featured & Hot Product Toggles */}
                  <div className="grid grid-cols-2 gap-4 pt-2">
                    <FormField
                      control={form.control}
                      name="isFeatured"
                      render={({ field }) => (
                        <FormItem className="flex items-center justify-between rounded-lg border border-[#333] p-3 bg-[#0D0D0D]">
                          <div className="space-y-0.5">
                            <FormLabel className="text-white flex items-center gap-2">
                              <Star className="h-4 w-4 text-yellow-500" />
                              Featured
                            </FormLabel>
                            <FormDescription className="text-xs text-gray-500">
                              Show on homepage
                            </FormDescription>
                          </div>
                          <FormControl>
                            <Switch
                              checked={field.value}
                              onCheckedChange={field.onChange}
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                    <FormField
                      control={form.control}
                      name="isHot"
                      render={({ field }) => (
                        <FormItem className="flex items-center justify-between rounded-lg border border-[#333] p-3 bg-[#0D0D0D]">
                          <div className="space-y-0.5">
                            <FormLabel className="text-white flex items-center gap-2">
                              <Flame className="h-4 w-4 text-orange-500" />
                              Hot Product
                            </FormLabel>
                            <FormDescription className="text-xs text-gray-500">
                              Mark as trending
                            </FormDescription>
                          </div>
                          <FormControl>
                            <Switch
                              checked={field.value}
                              onCheckedChange={field.onChange}
                            />
                          </FormControl>
                        </FormItem>
                      )}
                    />
                  </div>
                </CardContent>
              </Card>

            </div>
          </div>
        </form>
      </Form>

      <Dialog
        open={Boolean(previewImageUrl)}
        onOpenChange={(open) => {
          if (!open) setPreviewImageUrl("");
        }}
      >
        <DialogContent className="max-w-4xl border-[#333] bg-[#161616] p-3">
          <DialogHeader className="sr-only">
            <DialogTitle>Product image preview</DialogTitle>
          </DialogHeader>
          {previewImageUrl && (
            <img
              src={previewImageUrl}
              alt="Enlarged product image"
              className="max-h-[80vh] w-full object-contain"
            />
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
