const notificationService = require('../services/notificationService');
const { paginate } = require('../utils/helpers');
const { DeviceToken, Notification } = require('../models');

const MAX_DEVICE_TOKENS_PER_USER = 10;
const MAX_FCM_TOKEN_LENGTH = 4096;
const PLATFORMS = new Set(['android', 'ios', 'web']);

exports.registerFcmToken = async (req, res, next) => {
  try {
    const { fcmToken, platform } = req.body;
    const userId = req.user._id;

    if (typeof fcmToken !== 'string' || !fcmToken || fcmToken.length > MAX_FCM_TOKEN_LENGTH) {
      return res.status(400).json({
        success: false,
        message: 'FCM token is required',
      });
    }

    // Upsert: create or reactivate the token
    await DeviceToken.findOneAndUpdate(
      { userId, fcmToken },
      { $set: { isActive: true, platform: PLATFORMS.has(platform) ? platform : 'android' } },
      { upsert: true, new: true }
    );

    // Only the newest few devices of a user stay active.
    const extra = await DeviceToken.find({ userId, isActive: true })
      .sort({ updatedAt: -1 })
      .skip(MAX_DEVICE_TOKENS_PER_USER)
      .select('_id')
      .lean();
    if (extra.length > 0) {
      await DeviceToken.updateMany({ _id: { $in: extra.map((token) => token._id) } }, { $set: { isActive: false } });
    }

    res.json({
      success: true,
      message: 'FCM token registered successfully',
    });
  } catch (error) {
    next(error);
  }
};

exports.unregisterFcmToken = async (req, res, next) => {
  try {
    const { fcmToken } = req.body;
    const userId = req.user._id;

    if (!fcmToken) {
      return res.status(400).json({
        success: false,
        message: 'FCM token is required',
      });
    }

    // Deactivate the token
    await DeviceToken.findOneAndUpdate(
      { userId, fcmToken },
      { $set: { isActive: false } }
    );

    res.json({
      success: true,
      message: 'FCM token unregistered successfully',
    });
  } catch (error) {
    next(error);
  }
};

// Topics a user may join themselves; others (if ever added) are managed by
// the server, so nobody can sign up for another group's announcements.
const PUBLIC_TOPICS = new Set(['new_products', 'promotions']);

exports.subscribeToTopic = async (req, res, next) => {
  try {
    const { topic } = req.body;
    const userId = req.user._id;

    if (!topic) {
      return res.status(400).json({
        success: false,
        message: 'Topic is required',
      });
    }
    if (!PUBLIC_TOPICS.has(String(topic))) {
      return res.status(400).json({
        success: false,
        message: 'Unknown topic',
        error: { code: 'INVALID_TOPIC' },
      });
    }

    const tokens = await DeviceToken.find({ userId, isActive: true }).select('fcmToken');
    if (!tokens || tokens.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No FCM tokens registered for this user',
      });
    }

    await notificationService.subscribeToTopic(tokens.map(t => t.fcmToken), topic);

    res.json({
      success: true,
      message: `Subscribed to topic: ${topic}`,
    });
  } catch (error) {
    next(error);
  }
};

exports.unsubscribeFromTopic = async (req, res, next) => {
  try {
    const { topic } = req.body;
    const userId = req.user._id;

    if (!topic) {
      return res.status(400).json({
        success: false,
        message: 'Topic is required',
      });
    }
    if (!PUBLIC_TOPICS.has(String(topic))) {
      return res.status(400).json({
        success: false,
        message: 'Unknown topic',
        error: { code: 'INVALID_TOPIC' },
      });
    }

    const tokens = await DeviceToken.find({ userId, isActive: true }).select('fcmToken');
    if (!tokens || tokens.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'No FCM tokens registered for this user',
      });
    }

    await notificationService.unsubscribeFromTopic(tokens.map(t => t.fcmToken), topic);

    res.json({
      success: true,
      message: `Unsubscribed from topic: ${topic}`,
    });
  } catch (error) {
    next(error);
  }
};

// Admin: Send notification to specific user
exports.sendToUser = async (req, res, next) => {
  try {
    const { userId, title, body, data } = req.body;

    if (!userId || !title || !body) {
      return res.status(400).json({
        success: false,
        message: 'userId, title, and body are required',
      });
    }

    const result = await notificationService.sendToUser(
      userId,
      { title, body },
      data || {}
    );

    res.json({
      success: true,
      message: 'Notification sent',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

// Admin: Send notification to topic
exports.sendToTopic = async (req, res, next) => {
  try {
    const { topic, title, body, imageUrl, data } = req.body;

    if (!topic || !title || !body) {
      return res.status(400).json({
        success: false,
        message: 'topic, title, and body are required',
      });
    }

    const result = await notificationService.sendToTopic(
      topic,
      { title, body, imageUrl },
      data || {}
    );

    res.json({
      success: true,
      message: 'Notification sent to topic',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

// Admin: Send promotional notification
exports.sendPromotion = async (req, res, next) => {
  try {
    const { title, body, imageUrl } = req.body;

    if (!title || !body) {
      return res.status(400).json({
        success: false,
        message: 'title and body are required',
      });
    }

    const result = await notificationService.sendPromotionalNotification(
      title,
      body,
      imageUrl
    );

    res.json({
      success: true,
      message: 'Promotional notification sent',
      data: result,
    });
  } catch (error) {
    next(error);
  }
};

// Get user's notifications
exports.getMyNotifications = async (req, res, next) => {
  try {
    const userId = req.user._id;
    const { page, limit, skip } = paginate(req.query.page, req.query.limit, 200);

    const [notifications, total, unreadCount] = await Promise.all([
      Notification.find({ userId })
        .sort({ createdAt: -1 })
        .skip(skip)
        .limit(limit)
        .lean(),
      Notification.countDocuments({ userId }),
      Notification.countDocuments({ userId, isRead: false }),
    ]);

    res.json({
      success: true,
      data: notifications,
      unreadCount,
      pagination: {
        page,
        limit,
        total,
        pages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    next(error);
  }
};

// Mark notifications as read
exports.markAsRead = async (req, res, next) => {
  try {
    const userId = req.user._id;
    const { ids } = req.body; // array of notification IDs, or empty to mark all

    const filter = { userId };
    if (ids && ids.length > 0) {
      filter._id = { $in: ids };
    }

    await Notification.updateMany(filter, { $set: { isRead: true } });

    res.json({ success: true, message: 'Notifications marked as read' });
  } catch (error) {
    next(error);
  }
};
