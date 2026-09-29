"use client"

import { useEffect, useState, useCallback } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Badge } from "@/components/ui/badge"
import { Loader2, TrendingUp, ShoppingCart, IndianRupee, Activity, Users, Eye, Package, Flame, AlertTriangle, ArrowUpRight, ArrowDownRight } from "@/components/hugeicons"
import { toast } from "sonner"
import { apiFetch } from "@/lib/api"
import { ChartSkeleton, DashboardPageSkeleton } from "@/components/ui/skeleton"
import {
    AreaChart,
    Area,
    BarChart,
    Bar,
    XAxis,
    YAxis,
    CartesianGrid,
    Tooltip,
    ResponsiveContainer,
    PieChart,
    Pie,
    Cell,
    Legend
} from 'recharts'

interface SalesData {
    summary: {
        totalRevenue: number
        totalOrders: number
        averageOrderValue: number
        retailOrders: number
        wholesaleOrders: number
    }
    timeline: { date: string; orders: number; revenue: number }[]
    byCategory: { category: string; orders: number; revenue: number }[]
}

interface ProductAnalytics {
    productId: string
    name: string
    sku: string
    stock: number
    price: number
    views: number
    cartAdds: number
    orders: number
    revenue: number
    conversionRate: number
}

interface DemandData {
    highDemandProducts: { productId: string; name: string; sku: string; stock: number; recentViews: number; recentNegotiations: number; alert: string }[]
    lowStockAlerts: { _id: string; name: string; sku: string; stock: number; lowStockThreshold: number }[]
    trendingProducts: { productId: string; name: string; views: number; stock: number }[]
}

const COLORS = ['#0088FE', '#0a10ba', '#FFBB28', '#FF8042', '#8884d8', '#8284ca', '#ffc658', '#ff7f7f'];
const BAR_COLORS = { views: '#3b82f6', orders: '#2563eb', revenue: '#f59e0b', demand: '#ef4444' };

export default function AnalyticsPage() {
    const [salesData, setSalesData] = useState<SalesData | null>(null)
    const [productData, setProductData] = useState<ProductAnalytics[]>([])
    const [demandData, setDemandData] = useState<DemandData | null>(null)
    const [isLoading, setIsLoading] = useState(true)
    const [isProductLoading, setIsProductLoading] = useState(true)
    const [period, setPeriod] = useState("30d")
    const [productSort, setProductSort] = useState("views")
    const [activeTab, setActiveTab] = useState("sales")

    const fetchSalesAnalytics = useCallback(async () => {
        setIsLoading(true)
        try {
            const res = await apiFetch(`/admin/analytics/sales?period=${period}`)
            const data = await res.json()
            if (res.ok) setSalesData(data.data)
            else toast.error("Failed to load sales analytics")
        } catch {
            toast.error("Connection error")
        } finally {
            setIsLoading(false)
        }
    }, [period])

    const fetchProductAnalytics = useCallback(async () => {
        setIsProductLoading(true)
        try {
            const res = await apiFetch(`/admin/analytics/products?period=${period}&sortBy=${productSort}`)
            const data = await res.json()
            if (res.ok) setProductData(data.data)
            else toast.error("Failed to load product analytics")
        } catch {
            toast.error("Connection error")
        } finally {
            setIsProductLoading(false)
        }
    }, [period, productSort])

    const fetchDemandInsights = useCallback(async () => {
        try {
            const res = await apiFetch(`/admin/analytics/demand`)
            const data = await res.json()
            if (res.ok) setDemandData(data.data)
        } catch {
            console.error("Failed to load demand insights")
        }
    }, [])

    useEffect(() => { fetchSalesAnalytics() }, [fetchSalesAnalytics])
    useEffect(() => { fetchProductAnalytics() }, [fetchProductAnalytics])
    useEffect(() => { fetchDemandInsights() }, [fetchDemandInsights])

    if (isLoading && !salesData && isProductLoading && productData.length === 0) {
        return <DashboardPageSkeleton />
    }

    const topViewed = [...productData].sort((a, b) => b.views - a.views).slice(0, 10)
    const topBought = [...productData].sort((a, b) => b.orders - a.orders).slice(0, 10)
    const topRevenue = [...productData].sort((a, b) => b.revenue - a.revenue).slice(0, 10)

    return (
        <div className="flex flex-col gap-6">
            <div className="flex justify-between items-center">
                <h1 className="text-3xl font-bold text-white">Analytics</h1>
                <Select value={period} onValueChange={setPeriod}>
                    <SelectTrigger className="w-[180px] bg-[#161616] border-[#333] text-white">
                        <SelectValue placeholder="Select period" />
                    </SelectTrigger>
                    <SelectContent className="bg-[#161616] border-[#333] text-white">
                        <SelectItem value="7d">Last 7 Days</SelectItem>
                        <SelectItem value="30d">Last 30 Days</SelectItem>
                        <SelectItem value="90d">Last 3 Months</SelectItem>
                        <SelectItem value="1y">Last Year</SelectItem>
                    </SelectContent>
                </Select>
            </div>

            {/* Main Tabs */}
            <Tabs value={activeTab} onValueChange={setActiveTab} className="w-full">
                <TabsList className="bg-[#161616] border border-[#333]">
                    <TabsTrigger value="sales" className="data-[state=active]:bg-[#222] data-[state=active]:text-white text-gray-400">
                        <IndianRupee className="w-4 h-4 mr-2" /> Sales Overview
                    </TabsTrigger>
                    <TabsTrigger value="products" className="data-[state=active]:bg-[#222] data-[state=active]:text-white text-gray-400">
                        <Package className="w-4 h-4 mr-2" /> Product Analytics
                    </TabsTrigger>
                    <TabsTrigger value="demand" className="data-[state=active]:bg-[#222] data-[state=active]:text-white text-gray-400">
                        <Flame className="w-4 h-4 mr-2" /> Demand Insights
                    </TabsTrigger>
                </TabsList>

                {/* ─── SALES TAB ─── */}
                <TabsContent value="sales" className="flex flex-col gap-6 mt-6">
                    {/* Summary Cards */}
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                        <Card className="bg-[#161616] border-[#333]">
                            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                                <CardTitle className="text-sm font-medium text-gray-400">Total Revenue</CardTitle>
                                <IndianRupee className="h-4 w-4 text-blue-500" />
                            </CardHeader>
                            <CardContent>
                                <div className="text-2xl font-bold text-white">₹{salesData?.summary.totalRevenue.toLocaleString()}</div>
                                <p className="text-xs text-gray-500 flex items-center gap-1 mt-1">
                                    <TrendingUp className="w-3 h-3 text-blue-500" />
                                    +20.1% from last period
                                </p>
                            </CardContent>
                        </Card>
                        <Card className="bg-[#161616] border-[#333]">
                            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                                <CardTitle className="text-sm font-medium text-gray-400">Total Orders</CardTitle>
                                <ShoppingCart className="h-4 w-4 text-blue-500" />
                            </CardHeader>
                            <CardContent>
                                <div className="text-2xl font-bold text-white">{salesData?.summary.totalOrders}</div>
                                <div className="text-xs text-gray-500 mt-1">
                                    <span className="text-blue-400">{salesData?.summary.retailOrders} Retail</span>
                                    {" · "}
                                    <span className="text-purple-400">{salesData?.summary.wholesaleOrders} Wholesale</span>
                                </div>
                            </CardContent>
                        </Card>
                        <Card className="bg-[#161616] border-[#333]">
                            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                                <CardTitle className="text-sm font-medium text-gray-400">Avg. Order Value</CardTitle>
                                <Activity className="h-4 w-4 text-yellow-500" />
                            </CardHeader>
                            <CardContent>
                                <div className="text-2xl font-bold text-white">₹{salesData?.summary.averageOrderValue.toLocaleString()}</div>
                                <p className="text-xs text-gray-500 mt-1">Average spend per customer</p>
                            </CardContent>
                        </Card>
                        <Card className="bg-[#161616] border-[#333]">
                            <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                                <CardTitle className="text-sm font-medium text-gray-400">Conversion Rate</CardTitle>
                                <Users className="h-4 w-4 text-purple-500" />
                            </CardHeader>
                            <CardContent>
                                <div className="text-2xl font-bold text-white">3.2%</div>
                                <p className="text-xs text-gray-500 mt-1">Visits to order conversion</p>
                            </CardContent>
                        </Card>
                    </div>

                    {/* Charts Section */}
                    <div className="grid grid-cols-1 lg:grid-cols-7 gap-6">
                        <Card className="bg-[#161616] border-[#333] lg:col-span-4">
                            <CardHeader>
                                <CardTitle className="text-white">Revenue Overview</CardTitle>
                                <CardDescription>Daily revenue trends for the selected period</CardDescription>
                            </CardHeader>
                            <CardContent>
                                <div className="h-[300px] w-full">
                                    <ResponsiveContainer width="100%" height="100%">
                                        <AreaChart data={salesData?.timeline}>
                                            <defs>
                                                <linearGradient id="colorRevenue" x1="0" y1="0" x2="0" y2="1">
                                                    <stop offset="5%" stopColor="#2563eb" stopOpacity={0.3} />
                                                    <stop offset="95%" stopColor="#2563eb" stopOpacity={0} />
                                                </linearGradient>
                                            </defs>
                                            <CartesianGrid strokeDasharray="3 3" stroke="#333" vertical={false} />
                                            <XAxis dataKey="date" stroke="#666" tickFormatter={(v) => new Date(v).toLocaleDateString(undefined, { month: 'short', day: 'numeric' })} tickLine={false} axisLine={false} />
                                            <YAxis stroke="#666" tickFormatter={(v) => `₹${v / 1000}k`} tickLine={false} axisLine={false} />
                                            <Tooltip contentStyle={{ backgroundColor: '#1F1F1F', border: '1px solid #333', borderRadius: '8px' }} labelStyle={{ color: '#aaa' }} />
                                            <Area type="monotone" dataKey="revenue" stroke="#2563eb" fillOpacity={1} fill="url(#colorRevenue)" />
                                        </AreaChart>
                                    </ResponsiveContainer>
                                </div>
                            </CardContent>
                        </Card>
                        <Card className="bg-[#161616] border-[#333] lg:col-span-3">
                            <CardHeader>
                                <CardTitle className="text-white">Sales by Category</CardTitle>
                                <CardDescription>Revenue distribution across categories</CardDescription>
                            </CardHeader>
                            <CardContent>
                                <div className="h-[300px] w-full">
                                    <ResponsiveContainer width="100%" height="100%">
                                        <PieChart>
                                            <Pie data={salesData?.byCategory} cx="50%" cy="50%" innerRadius={60} outerRadius={100} paddingAngle={5} dataKey="revenue">
                                                {salesData?.byCategory.map((_, index) => (
                                                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                                                ))}
                                            </Pie>
                                            <Tooltip formatter={(value: number) => `₹${value.toLocaleString()}`} contentStyle={{ backgroundColor: '#1F1F1F', border: '1px solid #333', borderRadius: '8px' }} itemStyle={{ color: '#fff' }} />
                                            <Legend iconType="circle" />
                                        </PieChart>
                                    </ResponsiveContainer>
                                </div>
                            </CardContent>
                        </Card>
                    </div>
                </TabsContent>

                {/* ─── PRODUCT ANALYTICS TAB ─── */}
                <TabsContent value="products" className="flex flex-col gap-6 mt-6">
                    {isProductLoading ? (
                        <ChartSkeleton className="h-[30vh] min-h-0" />
                    ) : (
                        <>
                            {/* Product Summary Cards */}
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                                <Card className="bg-[#161616] border-[#333]">
                                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                                        <CardTitle className="text-sm font-medium text-gray-400">Total Product Views</CardTitle>
                                        <Eye className="h-4 w-4 text-blue-500" />
                                    </CardHeader>
                                    <CardContent>
                                        <div className="text-2xl font-bold text-white">
                                            {productData.reduce((sum, p) => sum + p.views, 0).toLocaleString()}
                                        </div>
                                        <p className="text-xs text-gray-500 mt-1">Across {productData.length} products</p>
                                    </CardContent>
                                </Card>
                                <Card className="bg-[#161616] border-[#333]">
                                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                                        <CardTitle className="text-sm font-medium text-gray-400">Total Product Orders</CardTitle>
                                        <ShoppingCart className="h-4 w-4 text-blue-500" />
                                    </CardHeader>
                                    <CardContent>
                                        <div className="text-2xl font-bold text-white">
                                            {productData.reduce((sum, p) => sum + p.orders, 0).toLocaleString()}
                                        </div>
                                        <p className="text-xs text-gray-500 mt-1">
                                            Avg conversion: {(productData.reduce((sum, p) => sum + p.conversionRate, 0) / (productData.length || 1)).toFixed(1)}%
                                        </p>
                                    </CardContent>
                                </Card>
                                <Card className="bg-[#161616] border-[#333]">
                                    <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                                        <CardTitle className="text-sm font-medium text-gray-400">Product Revenue</CardTitle>
                                        <IndianRupee className="h-4 w-4 text-yellow-500" />
                                    </CardHeader>
                                    <CardContent>
                                        <div className="text-2xl font-bold text-white">
                                            ₹{productData.reduce((sum, p) => sum + p.revenue, 0).toLocaleString()}
                                        </div>
                                        <p className="text-xs text-gray-500 mt-1">
                                            Top: {topRevenue[0]?.name || 'N/A'}
                                        </p>
                                    </CardContent>
                                </Card>
                            </div>

                            {/* Top Products Chart */}
                            <Card className="bg-[#161616] border-[#333]">
                                <CardHeader className="flex flex-row items-center justify-between">
                                    <div>
                                        <CardTitle className="text-white">Product Performance</CardTitle>
                                        <CardDescription>Top products by views, orders, and revenue</CardDescription>
                                    </div>
                                    <Select value={productSort} onValueChange={setProductSort}>
                                        <SelectTrigger className="w-[150px] bg-[#0D0D0D] border-[#333] text-white">
                                            <SelectValue />
                                        </SelectTrigger>
                                        <SelectContent className="bg-[#161616] border-[#333] text-white">
                                            <SelectItem value="views">By Views</SelectItem>
                                            <SelectItem value="orders">By Orders</SelectItem>
                                            <SelectItem value="revenue">By Revenue</SelectItem>
                                        </SelectContent>
                                    </Select>
                                </CardHeader>
                                <CardContent>
                                    <div className="h-[350px] w-full">
                                        <ResponsiveContainer width="100%" height="100%">
                                            <BarChart data={productData.slice(0, 10)} layout="vertical" margin={{ left: 20 }}>
                                                <CartesianGrid strokeDasharray="3 3" stroke="#222" horizontal={false} />
                                                <XAxis type="number" stroke="#666" tickLine={false} axisLine={false}
                                                    tickFormatter={(v) => productSort === 'revenue' ? `₹${v >= 1000 ? `${(v/1000).toFixed(0)}k` : v}` : v.toLocaleString()} />
                                                <YAxis type="category" dataKey="name" stroke="#999" width={140} tick={{ fontSize: 12 }} tickLine={false} axisLine={false} />
                                                <Tooltip
                                                    contentStyle={{ backgroundColor: '#1F1F1F', border: '1px solid #333', borderRadius: '8px' }}
                                                    labelStyle={{ color: '#fff', fontWeight: 600 }}
                                                    formatter={(value: number, name: string) => {
                                                        if (name === 'revenue') return [`₹${value.toLocaleString()}`, 'Revenue']
                                                        if (name === 'views') return [value.toLocaleString(), 'Views']
                                                        if (name === 'orders') return [value.toLocaleString(), 'Orders']
                                                        return [value, name]
                                                    }}
                                                />
                                                <Bar dataKey={productSort} fill={BAR_COLORS[productSort as keyof typeof BAR_COLORS] || '#3b82f6'} radius={[0, 6, 6, 0]} barSize={24} />
                                            </BarChart>
                                        </ResponsiveContainer>
                                    </div>
                                </CardContent>
                            </Card>

                            {/* Three ranking tables side by side */}
                            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                                {/* Top Viewed */}
                                <Card className="bg-[#161616] border-[#333]">
                                    <CardHeader className="pb-3">
                                        <CardTitle className="text-white flex items-center gap-2 text-base">
                                            <Eye className="h-4 w-4 text-blue-500" /> Top Viewed
                                        </CardTitle>
                                    </CardHeader>
                                    <CardContent className="p-0">
                                        <div className="divide-y divide-[#222]">
                                            {topViewed.map((product, idx) => (
                                                <div key={product.productId} className="flex items-center gap-3 px-5 py-3 hover:bg-[#1a1a1a] transition-colors">
                                                    <span className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                                                        idx === 0 ? 'bg-yellow-500/20 text-yellow-400' :
                                                        idx === 1 ? 'bg-gray-400/20 text-gray-300' :
                                                        idx === 2 ? 'bg-orange-500/20 text-orange-400' :
                                                        'bg-[#222] text-gray-500'
                                                    }`}>{idx + 1}</span>
                                                    <div className="flex-1 min-w-0">
                                                        <p className="text-sm text-white truncate">{product.name}</p>
                                                        <p className="text-xs text-gray-500">SKU: {product.sku}</p>
                                                    </div>
                                                    <div className="text-right">
                                                        <p className="text-sm font-semibold text-blue-400">{product.views.toLocaleString()}</p>
                                                        <p className="text-xs text-gray-500">views</p>
                                                    </div>
                                                </div>
                                            ))}
                                            {topViewed.length === 0 && (
                                                <p className="px-5 py-8 text-center text-gray-500 text-sm">No view data available</p>
                                            )}
                                        </div>
                                    </CardContent>
                                </Card>

                                {/* Top Bought */}
                                <Card className="bg-[#161616] border-[#333]">
                                    <CardHeader className="pb-3">
                                        <CardTitle className="text-white flex items-center gap-2 text-base">
                                            <ShoppingCart className="h-4 w-4 text-blue-500" /> Top Bought
                                        </CardTitle>
                                    </CardHeader>
                                    <CardContent className="p-0">
                                        <div className="divide-y divide-[#222]">
                                            {topBought.map((product, idx) => (
                                                <div key={product.productId} className="flex items-center gap-3 px-5 py-3 hover:bg-[#1a1a1a] transition-colors">
                                                    <span className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                                                        idx === 0 ? 'bg-yellow-500/20 text-yellow-400' :
                                                        idx === 1 ? 'bg-gray-400/20 text-gray-300' :
                                                        idx === 2 ? 'bg-orange-500/20 text-orange-400' :
                                                        'bg-[#222] text-gray-500'
                                                    }`}>{idx + 1}</span>
                                                    <div className="flex-1 min-w-0">
                                                        <p className="text-sm text-white truncate">{product.name}</p>
                                                        <p className="text-xs text-gray-500">₹{product.revenue.toLocaleString()} rev</p>
                                                    </div>
                                                    <div className="text-right">
                                                        <p className="text-sm font-semibold text-blue-400">{product.orders}</p>
                                                        <p className="text-xs text-gray-500">orders</p>
                                                    </div>
                                                </div>
                                            ))}
                                            {topBought.length === 0 && (
                                                <p className="px-5 py-8 text-center text-gray-500 text-sm">No order data available</p>
                                            )}
                                        </div>
                                    </CardContent>
                                </Card>

                                {/* Top Revenue */}
                                <Card className="bg-[#161616] border-[#333]">
                                    <CardHeader className="pb-3">
                                        <CardTitle className="text-white flex items-center gap-2 text-base">
                                            <IndianRupee className="h-4 w-4 text-yellow-500" /> Top Revenue
                                        </CardTitle>
                                    </CardHeader>
                                    <CardContent className="p-0">
                                        <div className="divide-y divide-[#222]">
                                            {topRevenue.map((product, idx) => (
                                                <div key={product.productId} className="flex items-center gap-3 px-5 py-3 hover:bg-[#1a1a1a] transition-colors">
                                                    <span className={`w-6 h-6 rounded-full flex items-center justify-center text-xs font-bold ${
                                                        idx === 0 ? 'bg-yellow-500/20 text-yellow-400' :
                                                        idx === 1 ? 'bg-gray-400/20 text-gray-300' :
                                                        idx === 2 ? 'bg-orange-500/20 text-orange-400' :
                                                        'bg-[#222] text-gray-500'
                                                    }`}>{idx + 1}</span>
                                                    <div className="flex-1 min-w-0">
                                                        <p className="text-sm text-white truncate">{product.name}</p>
                                                        <p className="text-xs text-gray-500">{product.orders} orders · {product.conversionRate.toFixed(1)}% conv</p>
                                                    </div>
                                                    <div className="text-right">
                                                        <p className="text-sm font-semibold text-yellow-400">₹{product.revenue.toLocaleString()}</p>
                                                        <p className="text-xs text-gray-500">revenue</p>
                                                    </div>
                                                </div>
                                            ))}
                                            {topRevenue.length === 0 && (
                                                <p className="px-5 py-8 text-center text-gray-500 text-sm">No revenue data available</p>
                                            )}
                                        </div>
                                    </CardContent>
                                </Card>
                            </div>

                            {/* Conversion Funnel */}
                            <Card className="bg-[#161616] border-[#333]">
                                <CardHeader>
                                    <CardTitle className="text-white">Product Conversion Funnel</CardTitle>
                                    <CardDescription>Views → Cart Adds → Orders for top products</CardDescription>
                                </CardHeader>
                                <CardContent>
                                    <div className="h-[300px] w-full">
                                        <ResponsiveContainer width="100%" height="100%">
                                            <BarChart data={topViewed.slice(0, 8)}>
                                                <CartesianGrid strokeDasharray="3 3" stroke="#222" vertical={false} />
                                                <XAxis dataKey="name" stroke="#666" tick={{ fontSize: 11 }} tickLine={false} axisLine={false}
                                                    tickFormatter={(v) => v.length > 15 ? v.slice(0, 15) + '…' : v} />
                                                <YAxis stroke="#666" tickLine={false} axisLine={false} />
                                                <Tooltip contentStyle={{ backgroundColor: '#1F1F1F', border: '1px solid #333', borderRadius: '8px' }} />
                                                <Legend iconType="circle" />
                                                <Bar dataKey="views" fill="#3b82f6" name="Views" radius={[4, 4, 0, 0]} barSize={18} />
                                                <Bar dataKey="cartAdds" fill="#f59e0b" name="Cart Adds" radius={[4, 4, 0, 0]} barSize={18} />
                                                <Bar dataKey="orders" fill="#2563eb" name="Orders" radius={[4, 4, 0, 0]} barSize={18} />
                                            </BarChart>
                                        </ResponsiveContainer>
                                    </div>
                                </CardContent>
                            </Card>
                        </>
                    )}
                </TabsContent>

                {/* ─── DEMAND INSIGHTS TAB ─── */}
                <TabsContent value="demand" className="flex flex-col gap-6 mt-6">
                    {!demandData ? (
                        <ChartSkeleton className="h-[30vh] min-h-0" />
                    ) : (
                        <>
                            {/* Trending Products */}
                            <Card className="bg-[#161616] border-[#333]">
                                <CardHeader>
                                    <CardTitle className="text-white flex items-center gap-2">
                                        <Flame className="h-5 w-5 text-orange-500" /> Trending Products
                                    </CardTitle>
                                    <CardDescription>Most viewed products in the last 7 days</CardDescription>
                                </CardHeader>
                                <CardContent>
                                    {demandData.trendingProducts.length > 0 ? (
                                        <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                            {demandData.trendingProducts.map((product, idx) => (
                                                <div key={product.productId} className="flex items-center gap-4 p-4 rounded-xl bg-[#0D0D0D] border border-[#222] hover:border-[#444] transition-colors">
                                                    <div className={`w-10 h-10 rounded-xl flex items-center justify-center font-bold text-lg ${
                                                        idx === 0 ? 'bg-gradient-to-br from-yellow-500 to-orange-500 text-white' :
                                                        idx === 1 ? 'bg-gradient-to-br from-gray-300 to-gray-500 text-white' :
                                                        idx === 2 ? 'bg-gradient-to-br from-orange-400 to-red-500 text-white' :
                                                        'bg-[#222] text-gray-400'
                                                    }`}>
                                                        {idx + 1}
                                                    </div>
                                                    <div className="flex-1 min-w-0">
                                                        <p className="text-sm font-medium text-white truncate">{product.name}</p>
                                                        <div className="flex items-center gap-3 mt-1">
                                                            <span className="text-xs text-blue-400 flex items-center gap-1">
                                                                <Eye className="w-3 h-3" /> {product.views} views
                                                            </span>
                                                            <span className={`text-xs flex items-center gap-1 ${product.stock > 0 ? 'text-blue-400' : 'text-red-400'}`}>
                                                                <Package className="w-3 h-3" /> {product.stock > 0 ? `${product.stock} in stock` : 'Out of stock'}
                                                            </span>
                                                        </div>
                                                    </div>
                                                    <TrendingUp className="w-5 h-5 text-orange-400 shrink-0" />
                                                </div>
                                            ))}
                                        </div>
                                    ) : (
                                        <p className="text-center py-8 text-gray-500">No trending data available yet</p>
                                    )}
                                </CardContent>
                            </Card>

                            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
                                {/* High Demand Products */}
                                <Card className="bg-[#161616] border-[#333]">
                                    <CardHeader>
                                        <CardTitle className="text-white flex items-center gap-2 text-base">
                                            <ArrowUpRight className="h-4 w-4 text-red-500" /> High Demand - Restock Needed
                                        </CardTitle>
                                        <CardDescription>Products with high views/negotiations but low/zero stock</CardDescription>
                                    </CardHeader>
                                    <CardContent className="p-0">
                                        {demandData.highDemandProducts.length > 0 ? (
                                            <div className="divide-y divide-[#222]">
                                                {demandData.highDemandProducts.map((product) => (
                                                    <div key={product.productId} className="flex items-center gap-3 px-5 py-3">
                                                        <div className="w-8 h-8 rounded-lg bg-red-500/10 flex items-center justify-center">
                                                            <AlertTriangle className="w-4 h-4 text-red-400" />
                                                        </div>
                                                        <div className="flex-1 min-w-0">
                                                            <p className="text-sm text-white truncate">{product.name}</p>
                                                            <div className="flex gap-3 mt-0.5">
                                                                <span className="text-xs text-blue-400">{product.recentViews} views</span>
                                                                <span className="text-xs text-purple-400">{product.recentNegotiations} negotiations</span>
                                                            </div>
                                                        </div>
                                                        <Badge variant="destructive" className="text-xs">Out of Stock</Badge>
                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <p className="px-5 py-8 text-center text-gray-500 text-sm">No high-demand alerts right now</p>
                                        )}
                                    </CardContent>
                                </Card>

                                {/* Low Stock Alerts */}
                                <Card className="bg-[#161616] border-[#333]">
                                    <CardHeader>
                                        <CardTitle className="text-white flex items-center gap-2 text-base">
                                            <ArrowDownRight className="h-4 w-4 text-yellow-500" /> Low Stock Alerts
                                        </CardTitle>
                                        <CardDescription>Products approaching their restock threshold</CardDescription>
                                    </CardHeader>
                                    <CardContent className="p-0">
                                        {demandData.lowStockAlerts.length > 0 ? (
                                            <div className="divide-y divide-[#222]">
                                                {demandData.lowStockAlerts.map((product) => (
                                                    <div key={product._id} className="flex items-center gap-3 px-5 py-3">
                                                        <div className="w-8 h-8 rounded-lg bg-yellow-500/10 flex items-center justify-center">
                                                            <Package className="w-4 h-4 text-yellow-400" />
                                                        </div>
                                                        <div className="flex-1 min-w-0">
                                                            <p className="text-sm text-white truncate">{product.name}</p>
                                                            <p className="text-xs text-gray-500">SKU: {product.sku}</p>
                                                        </div>
                                                        <div className="text-right">
                                                            <p className="text-sm font-semibold text-yellow-400">{product.stock}</p>
                                                            <p className="text-xs text-gray-500">/ {product.lowStockThreshold} min</p>
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                        ) : (
                                            <p className="px-5 py-8 text-center text-gray-500 text-sm">All products are well-stocked</p>
                                        )}
                                    </CardContent>
                                </Card>
                            </div>
                        </>
                    )}
                </TabsContent>
            </Tabs>
        </div>
    )
}
