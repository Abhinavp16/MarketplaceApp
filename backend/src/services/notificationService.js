const { getMessaging } = require('../config/firebase');
const BRAND = require('../config/brand');
const { DeviceToken, Notification, User } = require('../models');
const { normalizeLanguage, renderNotification } = require('./notificationTemplates');

// Only these FCM error codes mean the device token itself is permanently unusable.
// Every other failure (auth, APNs config, quota, outage) must leave the token active.
const UNREGISTERED_TOKEN_ERROR_CODES = new Set([
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
]);

const maskToken = (token) => {
  if (!token || typeof token !== 'string') return 'unknown';
  return token.length <= 12 ? token : `${token.slice(0, 8)}...${token.slice(-4)}`;
};

class NotificationService {
  constructor() {
    this.messaging = null;
  }

  getMessagingInstance() {
    if (!this.messaging) {
      this.messaging = getMessaging();
    }
    return this.messaging;
  }

  async sendToDevice(fcmToken, notification, data = {}, options = {}) {
    const messaging = this.getMessagingInstance();
    if (!messaging) {
      console.warn('FCM not configured, skipping notification');
      return null;
    }

    try {
      const message = this._buildMessagePayload(
        notification,
        data,
        options,
      );
      message.token = fcmToken;

      const response = await messaging.send(message);
      console.log('Notification sent successfully:', response);
      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      // If token is invalid, we might want to remove it from database
      if (error.code === 'messaging/invalid-registration-token' ||
          error.code === 'messaging/registration-token-not-registered') {
        await this.removeInvalidToken(fcmToken);
      }
      throw error;
    }
  }

  async sendToMultipleDevices(fcmTokens, notification, data = {}, options = {}) {
    const messaging = this.getMessagingInstance();
    if (!messaging) {
      console.warn('FCM not configured, skipping notification');
      return null;
    }

    if (!fcmTokens || fcmTokens.length === 0) {
      return { successCount: 0, failureCount: 0 };
    }

    try {
      const message = this._buildMessagePayload(
        notification,
        data,
        options,
      );

      const response = await messaging.sendEachForMulticast({
        tokens: fcmTokens,
        ...message,
      });

      console.log(`Notifications sent: ${response.successCount} success, ${response.failureCount} failure`);

      // Handle failed tokens. Only genuinely unusable tokens are deactivated so a
      // transient FCM/APNs outage or misconfiguration cannot silently disable a device.
      if (response.failureCount > 0) {
        const unregisteredTokens = [];
        response.responses.forEach((resp, idx) => {
          if (resp.success) return;

          const code = resp.error?.code || 'unknown';
          console.error(
            `FCM delivery failed for token ${maskToken(fcmTokens[idx])}: ${code} - ${resp.error?.message || 'no message'}`
          );

          if (UNREGISTERED_TOKEN_ERROR_CODES.has(code)) {
            unregisteredTokens.push(fcmTokens[idx]);
          }
        });

        if (unregisteredTokens.length > 0) {
          await this.removeInvalidTokens(unregisteredTokens);
        }
      }

      return response;
    } catch (error) {
      console.error('Error sending multicast notification:', error);
      throw error;
    }
  }

  _buildMessagePayload(notification, data = {}, options = {}) {
    const payloadData = {
      ...data,
      title: notification.title,
      body: notification.body,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    };

    const message = {
      data: payloadData,
      android: {
        priority: 'high',
      },
      apns: {
        // Without these headers iOS can treat the push as low-priority/background
        // and never present it in Notification Center.
        headers: {
          'apns-push-type': 'alert',
          'apns-priority': '10',
        },
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    if (options.androidDataOnly) {
      message.apns.payload.aps.alert = {
        title: notification.title,
        body: notification.body,
      };
    } else {
      message.notification = {
        title: notification.title,
        body: notification.body,
        ...(notification.imageUrl && { imageUrl: notification.imageUrl }),
      };
      message.android.notification = {
        channelId: 'tradehub_default',
        priority: 'high',
        defaultSound: true,
      };
    }

    return message;
  }

  async sendToUser(userId, notification, data = {}) {
    try {
      // Store notification in DB
      try {
        await Notification.create({
          userId,
          title: notification.title,
          body: notification.body,
          type: data.type || 'general',
          data,
        });
      } catch (dbErr) {
        console.error('Error storing notification:', dbErr);
      }

      const tokens = await DeviceToken.find({ userId, isActive: true }).select('fcmToken platform');
      if (!tokens || tokens.length === 0) {
        console.log(`No FCM tokens found for user ${userId}`);
        return null;
      }

      const platformSummary = tokens.reduce((acc, token) => {
        const platform = token.platform || 'unknown';
        acc[platform] = (acc[platform] || 0) + 1;
        return acc;
      }, {});
      console.log(
        `Sending notification to user ${userId} across ${tokens.length} device(s): ${JSON.stringify(platformSummary)}`
      );

      const fcmTokens = tokens.map(t => t.fcmToken);
      return await this.sendToMultipleDevices(fcmTokens, notification, data);
    } catch (error) {
      console.error('Error sending notification to user:', error);
      throw error;
    }
  }

  async getUserLanguage(userId) {
    try {
      const user = await User.findById(userId).select('preferredLanguage').lean();
      return normalizeLanguage(user?.preferredLanguage);
    } catch (error) {
      return 'en';
    }
  }

  // Sends a template (services/notificationTemplates.js) in the user's language.
  async sendLocalizedToUser(userId, templateKey, params = {}, data = {}) {
    const language = await this.getUserLanguage(userId);
    return this.sendToUser(userId, renderNotification(templateKey, language, params), { ...data, language });
  }

  async sendToTopic(topic, notification, data = {}) {
    const messaging = this.getMessagingInstance();
    if (!messaging) {
      console.warn('FCM not configured, skipping notification');
      return null;
    }

    try {
      const message = {
        topic,
        notification: {
          title: notification.title,
          body: notification.body,
          ...(notification.imageUrl && { imageUrl: notification.imageUrl }),
        },
        data: {
          ...data,
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
      };

      const response = await messaging.send(message);
      console.log('Topic notification sent:', response);
      return response;
    } catch (error) {
      console.error('Error sending topic notification:', error);
      throw error;
    }
  }

  async subscribeToTopic(fcmTokens, topic) {
    const messaging = this.getMessagingInstance();
    if (!messaging) return null;

    try {
      const response = await messaging.subscribeToTopic(fcmTokens, topic);
      console.log(`Subscribed ${response.successCount} tokens to topic ${topic}`);
      return response;
    } catch (error) {
      console.error('Error subscribing to topic:', error);
      throw error;
    }
  }

  async unsubscribeFromTopic(fcmTokens, topic) {
    const messaging = this.getMessagingInstance();
    if (!messaging) return null;

    try {
      const response = await messaging.unsubscribeFromTopic(fcmTokens, topic);
      console.log(`Unsubscribed ${response.successCount} tokens from topic ${topic}`);
      return response;
    } catch (error) {
      console.error('Error unsubscribing from topic:', error);
      throw error;
    }
  }

  async removeInvalidToken(token) {
    try {
      await DeviceToken.updateMany(
        { fcmToken: token },
        { $set: { isActive: false } }
      );
    } catch (error) {
      console.error('Error removing invalid token:', error);
    }
  }

  async removeInvalidTokens(tokens) {
    try {
      await DeviceToken.updateMany(
        { fcmToken: { $in: tokens } },
        { $set: { isActive: false } }
      );
    } catch (error) {
      console.error('Error removing invalid tokens:', error);
    }
  }

  // Pre-built notification templates
  async sendOrderStatusUpdate(userId, orderId, status) {
    const templateByStatus = {
      confirmed: 'orderConfirmed',
      shipped: 'orderShipped',
      delivered: 'orderDelivered',
      cancelled: 'orderCancelled',
    };
    return this.sendLocalizedToUser(userId, templateByStatus[status] || 'orderUpdated', {}, {
      type: 'order_update',
      orderId: orderId.toString(),
      status,
    });
  }

  async sendNegotiationUpdate(userId, negotiationId, message) {
    return this.sendLocalizedToUser(userId, 'negotiationUpdate', { message }, {
      type: 'negotiation_update',
      negotiationId: negotiationId.toString(),
    });
  }

  async sendNewProductAlert(productName, productId) {
    return this.sendToTopic('new_products', {
      title: 'New Product Available!',
      body: `Check out ${productName} - now available on ${BRAND.name}`,
    }, {
      type: 'new_product',
      productId: productId.toString(),
    });
  }

  async sendPromotionalNotification(title, body, imageUrl = null) {
    return this.sendToTopic('promotions', {
      title,
      body,
      imageUrl,
    }, {
      type: 'promotion',
    });
  }

  async sendPaymentVerified(userId, orderId, orderNumber) {
    return this.sendLocalizedToUser(userId, 'paymentVerified', { orderNumber }, {
      type: 'payment_verified',
      orderId: orderId.toString(),
    });
  }

  async sendPaymentRejected(userId, orderId, orderNumber, reason) {
    return this.sendLocalizedToUser(
      userId,
      reason ? 'paymentRejectedWithReason' : 'paymentRejected',
      { orderNumber, reason },
      { type: 'payment_rejected', orderId: orderId.toString() },
    );
  }
}

module.exports = new NotificationService();
