const mongoose = require('mongoose');
const User = require('../models/User');
const Negotiation = require('../models/Negotiation');
const { verifyAccessToken } = require('../utils/jwtTokens');
const logger = require('../utils/logger');

// The business team can open any deal; a wholesaler only their own.
const TEAM_ROLES = new Set(['admin', 'staff']);

/**
 * The signed-in user on this socket, from their access token (sent with the
 * event or at connection). What the client says about its own id or role is
 * never trusted. Null when there is no valid token or the account is off.
 */
async function socketUser(socket, data = {}) {
  const token = data?.token || socket.handshake.auth?.token;
  if (!token || typeof token !== 'string') return null;
  try {
    const decoded = verifyAccessToken(token);
    if (decoded.sessionExpiresAt && new Date(decoded.sessionExpiresAt) <= new Date()) return null;
    const user = await User.findById(decoded.userId).select('_id name role isActive');
    return user && user.isActive ? user : null;
  } catch {
    return null;
  }
}

async function canOpenNegotiation(user, negotiationId) {
  if (!mongoose.Types.ObjectId.isValid(negotiationId)) return false;
  if (TEAM_ROLES.has(user.role)) {
    return Boolean(await Negotiation.exists({ _id: negotiationId }));
  }
  if (user.role !== 'wholesaler') return false;
  return Boolean(await Negotiation.exists({ _id: negotiationId, wholesalerId: user._id }));
}

// Events about a deal only count from a socket that joined that deal.
const inNegotiation = (socket, data) =>
  Boolean(socket.negotiationId) && String(data?.negotiationId || '') === socket.negotiationId;

// Shared Socket.IO server instance (also used for admin fan-out).
let ioInstance = null;

// Store active connections: { negotiationId: Set<socketId> }
const activeConnections = new Map();

// Store typing users: { negotiationId: { userId: { username, timestamp } } }
const typingUsers = new Map();

// Takes the socket out of its deal's room and tells the others.
function leaveRoom(socket) {
  const { negotiationId, userId, userRole } = socket;
  if (!negotiationId) return;
  const room = `negotiation-${negotiationId}`;
  socket.leave(room);

  if (activeConnections.has(negotiationId)) {
    activeConnections.get(negotiationId).delete(socket.id);
    if (activeConnections.get(negotiationId).size === 0) {
      activeConnections.delete(negotiationId);
    }
  }
  if (typingUsers.has(negotiationId)) {
    delete typingUsers.get(negotiationId)[userId];
  }

  socket.to(room).emit('user-offline', { userId, userRole, timestamp: new Date() });
  logger.info(`[Socket] ${userRole} left negotiation ${negotiationId}`);
  socket.negotiationId = null;
}

class NegotiationSocketService {
  static getIO() {
    return ioInstance;
  }

  static initializeSocket(io) {
    ioInstance = io;
    io.on('connection', (socket) => {
      logger.info(`[Socket] New connection: ${socket.id}`);

      // Admin panels join the shared `admins` room for realtime
      // notifications. Unlike negotiation rooms, this join is authenticated:
      // the client must present a valid JWT for an active admin user.
      socket.on('join-admin', async (data = {}) => {
        const user = await socketUser(socket, data);
        if (!user) {
          socket.emit('admin-join-error', { message: 'Invalid or expired token' });
          return;
        }
        if (user.role !== 'admin') {
          socket.emit('admin-join-error', { message: 'Admin access required' });
          return;
        }
        socket.join('admins');
        socket.adminUserId = String(user._id);
        logger.info(`[Socket] Admin ${user._id} joined admins room`);
        socket.emit('admin-joined', { at: new Date() });
      });

      socket.on('leave-admin', () => {
        socket.leave('admins');
        socket.adminUserId = null;
      });

      // Joining a deal's chat room needs a valid sign-in and access to the deal.
      socket.on('join-negotiation', async (data = {}) => {
        const negotiationId = String(data?.negotiationId || '');
        const user = await socketUser(socket, data);
        if (!user) {
          socket.emit('negotiation-join-error', { negotiationId, message: 'Authentication required' });
          return;
        }
        let allowed = false;
        try {
          allowed = await canOpenNegotiation(user, negotiationId);
        } catch (err) {
          logger.error('[Socket] Negotiation access check failed', { message: err.message });
        }
        if (!allowed) {
          socket.emit('negotiation-join-error', { negotiationId, message: 'Negotiation not found' });
          return;
        }

        // One deal per socket: leave the previous one first.
        if (socket.negotiationId && socket.negotiationId !== negotiationId) {
          leaveRoom(socket);
        }

        const room = `negotiation-${negotiationId}`;
        socket.join(room);
        socket.negotiationId = negotiationId;
        socket.userId = String(user._id);
        socket.userRole = TEAM_ROLES.has(user.role) ? 'admin' : 'wholesaler';
        socket.username = user.name || '';

        if (!activeConnections.has(negotiationId)) {
          activeConnections.set(negotiationId, new Set());
        }
        activeConnections.get(negotiationId).add(socket.id);

        logger.info(`[Socket] ${socket.userRole} joined negotiation ${negotiationId}`);
        socket.emit('negotiation-joined', { negotiationId });

        socket.to(room).emit('user-online', {
          userId: socket.userId,
          userRole: socket.userRole,
          timestamp: new Date(),
        });
      });

      // Typing indicators, using the identity from the join.
      socket.on('typing', (data = {}) => {
        if (!inNegotiation(socket, data)) return;
        const { negotiationId, userId, username, userRole } = socket;
        if (!typingUsers.has(negotiationId)) {
          typingUsers.set(negotiationId, {});
        }
        typingUsers.get(negotiationId)[userId] = { username, userRole, timestamp: Date.now() };
        socket.to(`negotiation-${negotiationId}`).emit('user-typing', { userId, username, userRole });
      });

      socket.on('stop-typing', (data = {}) => {
        if (!inNegotiation(socket, data)) return;
        const { negotiationId, userId } = socket;
        if (typingUsers.has(negotiationId)) {
          delete typingUsers.get(negotiationId)[userId];
        }
        socket.to(`negotiation-${negotiationId}`).emit('stop-typing', { userId });
      });

      socket.on('mark-read', (data = {}) => {
        if (!inNegotiation(socket, data)) return;
        const messageId = String(data.messageId || '').slice(0, 100);
        if (!messageId) return;
        io.to(`negotiation-${socket.negotiationId}`).emit('message-read', {
          messageId,
          userId: socket.userId,
          timestamp: new Date(),
        });
      });

      socket.on('leave-negotiation', (data = {}) => {
        if (!inNegotiation(socket, data)) return;
        leaveRoom(socket);
      });

      socket.on('disconnect', () => {
        if (socket.negotiationId) leaveRoom(socket);
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
