const { AdminNotification } = require('../../models');
const { paginate, formatPaginationResponse } = require('../../utils/helpers');

// @desc    List admin notifications (newest first) with per-admin read state
// @route   GET /api/v1/admin/notifications
// @access  Private/Admin
exports.getNotifications = async (req, res, next) => {
  try {
    const { page, limit, skip } = paginate(req.query.page, req.query.limit);
    const query = {};
    if (req.query.type) query.type = req.query.type;
    if (req.query.unreadOnly === 'true') {
      query.readBy = { $ne: req.user._id };
    }

    const [notifications, total, unreadCount] = await Promise.all([
      AdminNotification.find(query)
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      AdminNotification.countDocuments(query),
      AdminNotification.countDocuments({ readBy: { $ne: req.user._id } }),
    ]);

    const userId = String(req.user._id);
    res.json({
      success: true,
      unreadCount,
      ...formatPaginationResponse(
        notifications.map((item) => ({
          ...item,
          isRead: (item.readBy || []).some((id) => String(id) === userId),
        })),
        total,
        page,
        limit,
      ),
    });
  } catch (error) {
    next(error);
  }
};

// @desc    Mark one admin notification as read for the current admin
// @route   POST /api/v1/admin/notifications/:id/read
// @access  Private/Admin
exports.markAsRead = async (req, res, next) => {
  try {
    await AdminNotification.updateOne(
      { _id: req.params.id },
      { $addToSet: { readBy: req.user._id } },
    );
    const unreadCount = await AdminNotification.countDocuments({
      readBy: { $ne: req.user._id },
    });
    res.json({ success: true, unreadCount });
  } catch (error) {
    next(error);
  }
};

// @desc    Mark all admin notifications as read for the current admin
// @route   POST /api/v1/admin/notifications/read-all
// @access  Private/Admin
exports.markAllAsRead = async (req, res, next) => {
  try {
    await AdminNotification.updateMany(
      { readBy: { $ne: req.user._id } },
      { $addToSet: { readBy: req.user._id } },
    );
    res.json({ success: true, unreadCount: 0 });
  } catch (error) {
    next(error);
  }
};
