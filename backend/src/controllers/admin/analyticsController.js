const { Order, Product, Negotiation, User, Analytics, Payment, ProductInterest } = require('../../models');
const { ORDER_STATUS, PAYMENT_STATUS, NEGOTIATION_STATUS, PRODUCT_STATUS } = require('../../utils/constants');
const {
  LEAD_DELAY_MINUTES,
  LEAD_RETENTION_DAYS,
  LEAD_ROLES,
  INTEREST_THRESHOLDS,
  interestLevel,
  resolveLeadPeriodDays,
} = require('../../utils/leadInterest');
const { getPriceForUser } = require('../../utils/productVariants');
const { buildDiscountMap, discountsFor } = require('../../services/productDiscountService');

exports.getDashboardStats = async (req, res, next) => {
  try {
    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const thisMonthStart = new Date(today.getFullYear(), today.getMonth(), 1);

    const [
      totalOrders,
      pendingPayments,
      totalRevenue,
      activeNegotiations,
      todayOrders,
      todayRevenue,
      monthOrders,
      monthRevenue,
      lowStockProducts,
      totalProducts,
      totalCustomers,
    ] = await Promise.all([
      Order.countDocuments(),
      Payment.countDocuments({ status: PAYMENT_STATUS.PENDING }),
      Order.aggregate([
        { $match: { status: { $in: [ORDER_STATUS.PAYMENT_VERIFIED, ORDER_STATUS.PROCESSING, ORDER_STATUS.SHIPPED, ORDER_STATUS.DELIVERED] } } },
        { $group: { _id: null, total: { $sum: '$total' } } },
      ]),
      Negotiation.countDocuments({ status: { $in: [NEGOTIATION_STATUS.PENDING, NEGOTIATION_STATUS.COUNTERED] } }),
      Order.countDocuments({ createdAt: { $gte: today } }),
      Order.aggregate([
        { $match: { createdAt: { $gte: today }, status: { $ne: ORDER_STATUS.CANCELLED } } },
        { $group: { _id: null, total: { $sum: '$total' } } },
      ]),
      Order.countDocuments({ createdAt: { $gte: thisMonthStart } }),
      Order.aggregate([
        { $match: { createdAt: { $gte: thisMonthStart }, status: { $ne: ORDER_STATUS.CANCELLED } } },
        { $group: { _id: null, total: { $sum: '$total' } } },
      ]),
      Product.countDocuments({ status: PRODUCT_STATUS.ACTIVE, $expr: { $lte: ['$stock', '$lowStockThreshold'] }, stock: { $gt: 0 } }),
      Product.countDocuments({ status: PRODUCT_STATUS.ACTIVE }),
      User.countDocuments({ role: { $ne: 'admin' }, isActive: true }),
    ]);

    res.json({
      success: true,
      data: {
        overview: {
          totalOrders,
          pendingPayments,
          totalRevenue: totalRevenue[0]?.total || 0,
          activeNegotiations,
          totalProducts,
          totalCustomers,
        },
        today: {
          orders: todayOrders,
          revenue: todayRevenue[0]?.total || 0,
        },
        thisMonth: {
          orders: monthOrders,
          revenue: monthRevenue[0]?.total || 0,
        },
        alerts: {
          lowStockProducts,
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getProductAnalytics = async (req, res, next) => {
  try {
    const { period = '30d', sortBy = 'views' } = req.query;

    const daysMap = { '7d': 7, '30d': 30, '90d': 90 };
    const days = daysMap[period] || 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const products = await Product.aggregate([
      { $match: { status: PRODUCT_STATUS.ACTIVE } },
      {
        $lookup: {
          from: 'analytics',
          let: { productId: '$_id' },
          pipeline: [
            {
              $match: {
                $expr: { $eq: ['$productId', '$$productId'] },
                timestamp: { $gte: startDate },
              },
            },
            { $group: { _id: '$eventType', count: { $sum: 1 } } },
          ],
          as: 'analytics',
        },
      },
      {
        $lookup: {
          from: 'orders',
          let: { productId: '$_id' },
          pipeline: [
            { $unwind: '$items' },
            {
              $match: {
                $expr: { $eq: ['$items.productId', '$$productId'] },
                createdAt: { $gte: startDate },
                status: { $in: [ORDER_STATUS.PAYMENT_VERIFIED, ORDER_STATUS.PROCESSING, ORDER_STATUS.SHIPPED, ORDER_STATUS.DELIVERED] },
              },
            },
            { $group: { _id: null, orders: { $sum: 1 }, revenue: { $sum: '$items.totalPrice' } } },
          ],
          as: 'orderStats',
        },
      },
      {
        $project: {
          productId: '$_id',
          name: 1,
          sku: 1,
          stock: 1,
          price: 1,
          views: {
            $ifNull: [
              { $arrayElemAt: [{ $filter: { input: '$analytics', cond: { $eq: ['$$this._id', 'view'] } } }, 0] },
              { count: 0 },
            ],
          },
          cartAdds: {
            $ifNull: [
              { $arrayElemAt: [{ $filter: { input: '$analytics', cond: { $eq: ['$$this._id', 'cart_add'] } } }, 0] },
              { count: 0 },
            ],
          },
          orders: { $ifNull: [{ $arrayElemAt: ['$orderStats.orders', 0] }, 0] },
          revenue: { $ifNull: [{ $arrayElemAt: ['$orderStats.revenue', 0] }, 0] },
        },
      },
      {
        $addFields: {
          views: '$views.count',
          cartAdds: '$cartAdds.count',
          conversionRate: {
            $cond: [
              { $gt: ['$views.count', 0] },
              { $multiply: [{ $divide: ['$orders', '$views.count'] }, 100] },
              0,
            ],
          },
        },
      },
      { $sort: { [sortBy === 'orders' ? 'orders' : sortBy === 'revenue' ? 'revenue' : 'views']: -1 } },
      { $limit: 20 },
    ]);

    res.json({
      success: true,
      data: products,
    });
  } catch (error) {
    next(error);
  }
};

exports.getSalesAnalytics = async (req, res, next) => {
  try {
    const { period = '30d', groupBy = 'day' } = req.query;

    const daysMap = { '7d': 7, '30d': 30, '90d': 90, '1y': 365 };
    const days = daysMap[period] || 30;
    const startDate = new Date();
    startDate.setDate(startDate.getDate() - days);

    const dateFormat = groupBy === 'month' ? '%Y-%m' : groupBy === 'week' ? '%Y-W%V' : '%Y-%m-%d';

    const [summary, timeline, byCategory] = await Promise.all([
      Order.aggregate([
        { $match: { createdAt: { $gte: startDate }, status: { $ne: ORDER_STATUS.CANCELLED } } },
        {
          $group: {
            _id: null,
            totalRevenue: { $sum: '$total' },
            totalOrders: { $sum: 1 },
            avgOrderValue: { $avg: '$total' },
          },
        },
      ]),
      Order.aggregate([
        { $match: { createdAt: { $gte: startDate }, status: { $ne: ORDER_STATUS.CANCELLED } } },
        {
          $group: {
            _id: { $dateToString: { format: dateFormat, date: '$createdAt' } },
            orders: { $sum: 1 },
            revenue: { $sum: '$total' },
          },
        },
        { $sort: { _id: 1 } },
        { $project: { date: '$_id', orders: 1, revenue: 1, _id: 0 } },
      ]),
      Order.aggregate([
        { $match: { createdAt: { $gte: startDate }, status: { $ne: ORDER_STATUS.CANCELLED } } },
        { $unwind: '$items' },
        {
          $lookup: {
            from: 'products',
            localField: 'items.productId',
            foreignField: '_id',
            as: 'product',
          },
        },
        { $unwind: '$product' },
        {
          $group: {
            _id: '$product.category',
            orders: { $sum: 1 },
            revenue: { $sum: '$items.totalPrice' },
          },
        },
        { $project: { category: '$_id', orders: 1, revenue: 1, _id: 0 } },
        { $sort: { revenue: -1 } },
      ]),
    ]);

    const orderTypeCounts = await Order.aggregate([
      { $match: { createdAt: { $gte: startDate }, status: { $ne: ORDER_STATUS.CANCELLED } } },
      { $group: { _id: '$orderType', count: { $sum: 1 } } },
    ]);

    const retailOrders = orderTypeCounts.find(o => o._id === 'retail')?.count || 0;
    const wholesaleOrders = orderTypeCounts.find(o => o._id === 'wholesale')?.count || 0;

    res.json({
      success: true,
      data: {
        summary: {
          totalRevenue: summary[0]?.totalRevenue || 0,
          totalOrders: summary[0]?.totalOrders || 0,
          averageOrderValue: Math.round(summary[0]?.avgOrderValue || 0),
          retailOrders,
          wholesaleOrders,
        },
        timeline,
        byCategory,
      },
    });
  } catch (error) {
    next(error);
  }
};

// Mongo expression mirroring utils/leadInterest.interestLevel for summaries.
const meetsInterest = (level) => ({
  $or: [
    { $gte: ['$viewCount', INTEREST_THRESHOLDS[level].views] },
    { $gte: ['$totalWatchSeconds', INTEREST_THRESHOLDS[level].watchSeconds] },
  ],
});

// Leads: one row per customer + product (ProductInterest). A lead shows
// LEAD_DELAY_MINUTES after the last view and is hidden once the customer sent
// a requirement for the product or ordered it. Staff/admin are never leads.
exports.getPotentialCustomers = async (req, res, next) => {
  try {
    const { period, page = 1, limit = 30 } = req.query;
    const days = resolveLeadPeriodDays(period);
    const pageNumber = Math.max(parseInt(page, 10) || 1, 1);
    const pageLimit = Math.min(Math.max(parseInt(limit, 10) || 30, 1), 100);
    const skip = (pageNumber - 1) * pageLimit;

    const now = Date.now();
    const startDate = new Date(now - days * 24 * 60 * 60 * 1000);
    const readyBefore = new Date(now - LEAD_DELAY_MINUTES * 60 * 1000);

    const results = await ProductInterest.aggregate([
      { $match: { lastViewedAt: { $gte: startDate, $lte: readyBefore } } },
      {
        $lookup: {
          from: 'users',
          localField: 'userId',
          foreignField: '_id',
          pipeline: [{
            $project: {
              name: 1, email: 1, phone: 1, role: 1, isActive: 1,
              businessName: '$businessInfo.businessName',
            },
          }],
          as: 'user',
        },
      },
      { $unwind: '$user' },
      { $match: { 'user.role': { $in: LEAD_ROLES }, 'user.isActive': { $ne: false } } },
      {
        $lookup: {
          from: 'products',
          localField: 'productId',
          foreignField: '_id',
          pipeline: [{
            $project: {
              name: 1, sku: 1, stock: 1, mrp: 1, retailPrice: 1, wholesalePrice: 1,
              company: 1, categoryRef: 1, category: 1, minWholesaleQuantity: 1, negotiationEnabled: 1,
              image: { $arrayElemAt: ['$images.url', 0] },
            },
          }],
          as: 'product',
        },
      },
      { $unwind: '$product' },
      // Hidden: sent a requirement for this product...
      {
        $lookup: {
          from: 'negotiations',
          let: { uid: '$userId', pid: '$productId' },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ['$wholesalerId', '$$uid'] },
                    { $eq: ['$productId', '$$pid'] },
                    { $gte: ['$createdAt', startDate] },
                  ],
                },
              },
            },
            { $limit: 1 },
            { $project: { _id: 1 } },
          ],
          as: 'requirements',
        },
      },
      // ...or ordered it (Buy Now or cart), unless that order was cancelled.
      {
        $lookup: {
          from: 'orders',
          let: { uid: '$userId', pid: '$productId' },
          pipeline: [
            {
              $match: {
                $expr: {
                  $and: [
                    { $eq: ['$userId', '$$uid'] },
                    { $ne: ['$status', ORDER_STATUS.CANCELLED] },
                    { $gte: ['$createdAt', startDate] },
                    { $in: ['$$pid', '$items.productId'] },
                  ],
                },
              },
            },
            { $limit: 1 },
            { $project: { _id: 1 } },
          ],
          as: 'orders',
        },
      },
      { $match: { requirements: { $size: 0 }, orders: { $size: 0 } } },
      { $sort: { viewCount: -1, totalWatchSeconds: -1, lastViewedAt: -1 } },
      {
        $facet: {
          data: [{ $skip: skip }, { $limit: pageLimit }],
          summary: [{
            $group: {
              _id: null,
              total: { $sum: 1 },
              hot: { $sum: { $cond: [meetsInterest('hot'), 1, 0] } },
              warm: { $sum: { $cond: [{ $and: [{ $not: [meetsInterest('hot')] }, meetsInterest('warm')] }, 1, 0] } },
              addedToCart: { $sum: { $cond: [{ $ne: [{ $ifNull: ['$lastCartAddAt', null] }, null] }, 1, 0] } },
              averageViews: { $avg: '$viewCount' },
              averageWatchSeconds: { $avg: '$totalWatchSeconds' },
            },
          }],
        },
      },
    ]);

    const rows = results[0]?.data || [];
    const summaryRow = results[0]?.summary?.[0] || {};
    const total = summaryRow.total || 0;

    // Price the product the way this customer sees it (brand/category discount).
    const discountMap = await buildDiscountMap(rows.map((row) => row.product));
    const potentialCustomers = rows.map((row) => {
      const pricing = getPriceForUser(row.product, row.user.role, null, discountsFor(discountMap, row.product));
      const totalWatchSeconds = row.totalWatchSeconds || 0;
      return {
        userId: row.userId,
        productId: row.productId,
        viewCount: row.viewCount,
        totalWatchSeconds,
        averageWatchSeconds: row.viewCount > 0 ? Math.round(totalWatchSeconds / row.viewCount) : 0,
        firstViewed: row.firstViewedAt,
        lastViewed: row.lastViewedAt,
        addedToCart: Boolean(row.lastCartAddAt),
        lastCartAddAt: row.lastCartAddAt || null,
        interest: interestLevel({ viewCount: row.viewCount, totalWatchSeconds }),
        user: {
          name: row.user.name,
          email: row.user.email,
          phone: row.user.phone,
          role: row.user.role,
          businessName: row.user.businessName,
        },
        product: {
          name: row.product.name,
          sku: row.product.sku,
          price: pricing.price,
          mrp: pricing.mrp || null,
          discountPercent: pricing.discountPercent,
          stock: row.product.stock,
          image: row.product.image,
        },
      };
    });

    res.json({
      success: true,
      data: {
        potentialCustomers,
        summary: {
          total,
          hot: summaryRow.hot || 0,
          warm: summaryRow.warm || 0,
          browsing: Math.max(total - (summaryRow.hot || 0) - (summaryRow.warm || 0), 0),
          addedToCart: summaryRow.addedToCart || 0,
          averageViews: Math.round((summaryRow.averageViews || 0) * 10) / 10,
          averageWatchSeconds: Math.round(summaryRow.averageWatchSeconds || 0),
        },
        rules: {
          periodDays: days,
          delayMinutes: LEAD_DELAY_MINUTES,
          retentionDays: LEAD_RETENTION_DAYS,
        },
        pagination: {
          page: pageNumber,
          limit: pageLimit,
          total,
          pages: Math.ceil(total / pageLimit),
        },
      },
    });
  } catch (error) {
    next(error);
  }
};

exports.getDemandInsights = async (req, res, next) => {
  try {
    const sevenDaysAgo = new Date();
    sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);

    const highDemandProducts = await Product.aggregate([
      { $match: { stock: 0, status: PRODUCT_STATUS.ACTIVE } },
      {
        $lookup: {
          from: 'analytics',
          let: { productId: '$_id' },
          pipeline: [
            {
              $match: {
                $expr: { $eq: ['$productId', '$$productId'] },
                timestamp: { $gte: sevenDaysAgo },
                eventType: 'view',
              },
            },
            { $count: 'views' },
          ],
          as: 'recentViews',
        },
      },
      {
        $lookup: {
          from: 'negotiations',
          let: { productId: '$_id' },
          pipeline: [
            {
              $match: {
                $expr: { $eq: ['$productId', '$$productId'] },
                createdAt: { $gte: sevenDaysAgo },
              },
            },
            { $count: 'negotiations' },
          ],
          as: 'recentNegotiations',
        },
      },
      {
        $addFields: {
          recentViews: { $ifNull: [{ $arrayElemAt: ['$recentViews.views', 0] }, 0] },
          recentNegotiations: { $ifNull: [{ $arrayElemAt: ['$recentNegotiations.negotiations', 0] }, 0] },
        },
      },
      {
        $match: {
          $or: [
            { recentViews: { $gte: 50 } },
            { recentNegotiations: { $gte: 3 } },
          ],
        },
      },
      {
        $project: {
          productId: '$_id',
          name: 1,
          sku: 1,
          stock: 1,
          recentViews: 1,
          recentNegotiations: 1,
          alert: { $literal: 'High demand detected - restock recommended' },
        },
      },
    ]);

    const lowStockAlerts = await Product.find({
      status: PRODUCT_STATUS.ACTIVE,
      stock: { $gt: 0 },
      $expr: { $lte: ['$stock', '$lowStockThreshold'] },
    })
      .select('name sku stock lowStockThreshold')
      .limit(10);

    const trendingProducts = await Analytics.aggregate([
      { $match: { timestamp: { $gte: sevenDaysAgo }, eventType: 'view' } },
      { $group: { _id: '$productId', views: { $sum: 1 } } },
      { $sort: { views: -1 } },
      { $limit: 10 },
      {
        $lookup: {
          from: 'products',
          localField: '_id',
          foreignField: '_id',
          as: 'product',
        },
      },
      { $unwind: '$product' },
      {
        $project: {
          productId: '$_id',
          name: '$product.name',
          views: 1,
          stock: '$product.stock',
        },
      },
    ]);

    res.json({
      success: true,
      data: {
        highDemandProducts,
        lowStockAlerts,
        trendingProducts,
      },
    });
  } catch (error) {
    next(error);
  }
};
