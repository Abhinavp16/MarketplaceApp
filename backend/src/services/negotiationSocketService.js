const jwt = require('jsonwebtoken');
const mongoose = require('mongoose');
const User = require('../models/User');
const Negotiation = require('../models/Negotiation');
const logger = require('../utils/logger');

// Shared Socket.IO server instance (also used for admin fan-out).
let ioInstance = null;

// Store active connections: { negotiationId: Set<socketId> }
const activeConnections = new Map();

// Store typing users: { negotiationId: { userId: { username, timestamp } } }
const typingUsers = new Map();

const MAX_MESSAGE_LENGTH = 280;
const PRIVILEGED_ROLES = ['admin', 'staff'];

const roomFor = (negotiationId) => `negotiation-${negotiationId}`;

const extractToken = (socket) => {
  const auth = socket.handshake?.auth || {};
  if (typeof auth.token === 'string' && auth.token) return auth.token.replace(/^Bearer\s+/i, '');
  const header = socket.handshake?.headers?.authorization;
  if (typeof header === 'string' && /^Bearer\s+/i.test(header)) return header.replace(/^Bearer\s+/i, '');
  const queryToken = socket.handshake?.query?.token;
  if (typeof queryToken === 'string' && queryToken) return queryToken;
  return null;
};

/**
 * Socket.IO connection middleware. Every socket must present a valid access
 * token; identity (user id, role, name) is derived from that token and the
 * database - never from fields sent by the client.
 */
async function authenticateSocket(socket, next) {
  try {
    const token = extractToken(socket);
    if (!token) return next(new Error('Authentication required'));

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    if (decoded.type === 'refresh') return next(new Error('Invalid token'));
    if (decoded.sessionExpiresAt && new Date(decoded.sessionExpiresAt) <= new Date()) {
      return next(new Error('Session expired'));
    }

    const user = await User.findById(decoded.userId).select('_id name username role isActive');
    if (!user || !user.isActive) return next(new Error('Account not available'));

    socket.data.user = {
      id: String(user._id),
      role: user.role,
      name: user.name || user.username || 'User',
    };
    return next();
  } catch (error) {
    return next(new Error('Invalid or expired token'));
  }
}

// Admin/staff may join any negotiation; a wholesaler only their own.
async function canAccessNegotiation(user, negotiationId) {
  if (!user || !mongoose.isValidObjectId(negotiationId)) return false;
  if (PRIVILEGED_ROLES.includes(user.role)) {
    return Boolean(await Negotiation.exists({ _id: negotiationId }));
  }
  if (user.role === 'wholesaler') {
    return Boolean(await Negotiation.exists({ _id: negotiationId, wholesalerId: user.id }));
  }
  return false;
}

function cleanupMembership(socket, negotiationId) {
  if (activeConnections.has(negotiationId)) {
    activeConnections.get(negotiationId).delete(socket.id);
    if (activeConnections.get(negotiationId).size === 0) {
      activeConnections.delete(negotiationId);
    }
  }
  const user = socket.data.user;
  if (user && typingUsers.has(negotiationId)) {
    delete typingUsers.get(negotiationId)[user.id];
  }
}

class NegotiationSocketService {
  static getIO() {
    return ioInstance;
  }

  static initializeSocket(io) {
    ioInstance = io;
    io.use(authenticateSocket);

    io.on('connection', (socket) => {
      const user = socket.data.user;
      logger.info(`[Socket] Authenticated connection: ${socket.id} (${user.role})`);

      // Rooms this socket is allowed to speak in (set only after authorization).
      const joined = new Set();
      const inRoom = (negotiationId) => joined.has(String(negotiationId));

      // Admin panels join the shared `admins` room for realtime notifications.
      // The role comes from the authenticated socket, not from the client.
      socket.on('join-admin', () => {
        if (user.role !== 'admin') {
          socket.emit('admin-join-error', { message: 'Admin access required' });
          return;
        }
        socket.join('admins');
        socket.adminUserId = user.id;
        logger.info(`[Socket] Admin ${user.id} joined admins room`);
        socket.emit('admin-joined', { at: new Date() });
      });

      socket.on('leave-admin', () => {
        socket.leave('admins');
        socket.adminUserId = null;
      });

      // Join a negotiation chat room (authorized against the database).
      socket.on('join-negotiation', async (data = {}) => {
        try {
          const negotiationId = String(data.negotiationId || '');
          if (!(await canAccessNegotiation(user, negotiationId))) {
            socket.emit('negotiation-join-error', { negotiationId, message: 'Not allowed to join this negotiation' });
            return;
          }
          const room = roomFor(negotiationId);
          socket.join(room);
          joined.add(negotiationId);
          socket.negotiationId = negotiationId;

          if (!activeConnections.has(negotiationId)) {
            activeConnections.set(negotiationId, new Set());
          }
          activeConnections.get(negotiationId).add(socket.id);

          logger.info(`[Socket] ${user.role} joined negotiation ${negotiationId}`);
          socket.to(room).emit('user-online', {
            userId: user.id,
            userRole: user.role,
            timestamp: new Date(),
          });
          socket.emit('negotiation-joined', { negotiationId });
        } catch (error) {
          socket.emit('negotiation-join-error', { message: 'Could not join negotiation' });
        }
      });

      // Live message relay. Identity is taken from the token. (Persistence
      // happens through the REST message endpoints.)
      socket.on('send-message', (data = {}) => {
        const negotiationId = String(data.negotiationId || '');
        if (!inRoom(negotiationId)) return;
        const message = typeof data.message === 'string' ? data.message.trim() : '';
        if (!message || message.length > MAX_MESSAGE_LENGTH) return;

        io.to(roomFor(negotiationId)).emit('receive-message', {
          negotiationId,
          message,
          userId: user.id,
          userRole: user.role,
          timestamp: new Date(),
          messageId: `${user.id}-${Date.now()}`,
        });

        if (typingUsers.has(negotiationId)) {
          delete typingUsers.get(negotiationId)[user.id];
        }
        io.to(roomFor(negotiationId)).emit('stop-typing', { userId: user.id });
      });

      socket.on('typing', (data = {}) => {
        const negotiationId = String(data.negotiationId || '');
        if (!inRoom(negotiationId)) return;

        if (!typingUsers.has(negotiationId)) typingUsers.set(negotiationId, {});
        typingUsers.get(negotiationId)[user.id] = {
          username: user.name,
          userRole: user.role,
          timestamp: Date.now(),
        };
        socket.to(roomFor(negotiationId)).emit('user-typing', {
          userId: user.id,
          username: user.name,
          userRole: user.role,
        });
      });

      socket.on('stop-typing', (data = {}) => {
        const negotiationId = String(data.negotiationId || '');
        if (!inRoom(negotiationId)) return;
        if (typingUsers.has(negotiationId)) {
          delete typingUsers.get(negotiationId)[user.id];
        }
        socket.to(roomFor(negotiationId)).emit('stop-typing', { userId: user.id });
      });

      socket.on('mark-read', (data = {}) => {
        const negotiationId = String(data.negotiationId || '');
        if (!inRoom(negotiationId)) return;
        io.to(roomFor(negotiationId)).emit('message-read', {
          messageId: data.messageId,
          userId: user.id,
          timestamp: new Date(),
        });
      });

      socket.on('leave-negotiation', (data = {}) => {
        const negotiationId = String(data.negotiationId || '');
        if (!inRoom(negotiationId)) return;
        const room = roomFor(negotiationId);
        socket.leave(room);
        joined.delete(negotiationId);
        cleanupMembership(socket, negotiationId);
        socket.to(room).emit('user-offline', {
          userId: user.id,
          userRole: user.role,
          timestamp: new Date(),
        });
        logger.info(`[Socket] ${user.role} left negotiation ${negotiationId}`);
      });

      socket.on('disconnect', () => {
        for (const negotiationId of joined) {
          cleanupMembership(socket, negotiationId);
          socket.to(roomFor(negotiationId)).emit('user-offline', {
            userId: user.id,
            userRole: user.role,
            timestamp: new Date(),
          });
        }
        joined.clear();
        logger.info(`[Socket] Disconnected: ${socket.id}`);
      });
    });
  }

  static getActiveUsers(negotiationId) {
    return activeConnections.has(negotiationId)
      ? activeConnections.get(negotiationId).size
      : 0;
  }

  static getTypingUsers(negotiationId) {
    if (!typingUsers.has(negotiationId)) return [];
    return Object.entries(typingUsers.get(negotiationId)).map(
      ([userId, data]) => ({
        userId,
        username: data.username,
        userRole: data.userRole,
      })
    );
  }
}

module.exports = NegotiationSocketService;
module.exports.authenticateSocket = authenticateSocket;
module.exports.canAccessNegotiation = canAccessNegotiation;
