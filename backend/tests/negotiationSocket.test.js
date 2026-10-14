const assert = require('assert');

// Live deal chat (socket.io): only the deal's wholesaler and the business
// team can join a deal's room, and identities come from the sign-in token.
// The socket handlers are driven through a small stand-in socket, against a
// database on this machine only (never the live database in .env):
//
//   SOCKET_TEST_MONGODB_URI=mongodb://127.0.0.1:27199/socket_test node tests/negotiationSocket.test.js

process.env.JWT_SECRET = 'test-access-secret-0123456789-abcdefghij';

const { isSafeTestDatabase: isLocalDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

// Just enough of socket.io's server API for the handlers.
function makeIo() {
  const rooms = new Map();
  let onConnection;
  const deliver = (room, event, payload, except) => {
    for (const socket of rooms.get(room) || []) {
      if (socket !== except) socket.received.push([event, payload]);
    }
  };
  const io = {
    on(event, handler) { if (event === 'connection') onConnection = handler; },
    to(room) { return { emit: (event, payload) => deliver(room, event, payload) }; },
  };
  const connect = (auth = {}) => {
    const handlers = {};
    const socket = {
      id: Math.random().toString(36).slice(2),
      handshake: { auth },
      received: [],
      on(event, handler) { handlers[event] = handler; },
      emit(event, payload) { socket.received.push([event, payload]); },
      join(room) {
        if (!rooms.has(room)) rooms.set(room, new Set());
        rooms.get(room).add(socket);
      },
      leave(room) { rooms.get(room)?.delete(socket); },
      to(room) { return { emit: (event, payload) => deliver(room, event, payload, socket) }; },
      fire: async (event, data) => handlers[event]?.(data),
      got: (event) => socket.received.filter(([name]) => name === event).map(([, payload]) => payload),
      inRoom: (room) => Boolean(rooms.get(room)?.has(socket)),
    };
    onConnection(socket);
    return socket;
  };
  return { io, connect, deliver };
}

async function runChecks(uri) {
  process.env.MONGODB_URI = uri;
  const mongoose = require('mongoose');
  const { User, Negotiation, Product } = require('../src/models');
  const { signAccessToken, signRefreshToken } = require('../src/utils/jwtTokens');
  const NegotiationSocketService = require('../src/services/negotiationSocketService');

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const makeUser = (role, extra = {}) => User.create({
    name: `Socket ${role}`,
    email: `socket-${role}-${suffix}@example.com`,
    authProvider: 'email',
    role,
    isActive: true,
    ...extra,
  });
  const owner = await makeUser('wholesaler');
  const stranger = await makeUser('wholesaler', { email: `socket-stranger-${suffix}@example.com` });
  const buyer = await makeUser('buyer');
  const admin = await makeUser('admin');
  const staff = await makeUser('staff', { username: `socketstaff${suffix}` });
  const inactive = await makeUser('wholesaler', { email: `socket-off-${suffix}@example.com`, isActive: false });
  const userIds = [owner, stranger, buyer, admin, staff, inactive].map((user) => user._id);

  const product = await Product.create({
    name: `Socket Pump ${suffix}`,
    sku: `SOCK-${suffix}`,
    category: 'Pumps',
    mrp: 100,
    retailPrice: 90,
    wholesalePrice: 80,
  });
  const deal = await Negotiation.create({
    wholesalerId: owner._id,
    productId: product._id,
    productSnapshot: { name: product.name, price: 80 },
    requestedQuantity: 10,
    requestedPricePerUnit: 75,
    requestedTotalPrice: 750,
    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
  });
  const dealId = String(deal._id);
  const room = `negotiation-${dealId}`;

  const token = (user) => signAccessToken({ userId: String(user._id) }, '10m');
  const { io, connect } = makeIo();
  NegotiationSocketService.initializeSocket(io);

  try {
    // No token, a made-up token, a refresh token, someone else's deal, a
    // customer, a switched-off account, a bad id: all refused.
    const refused = [
      [connect(), { negotiationId: dealId }],
      [connect(), { negotiationId: dealId, userId: String(owner._id), userRole: 'admin' }],
      [connect(), { negotiationId: dealId, token: 'x.y.z' }],
      [connect(), { negotiationId: dealId, token: signRefreshToken({ userId: String(owner._id) }, '10m') }],
      [connect({ token: token(stranger) }), { negotiationId: dealId }],
      [connect(), { negotiationId: dealId, token: token(buyer) }],
      [connect(), { negotiationId: dealId, token: token(inactive) }],
      [connect(), { negotiationId: 'not-an-id', token: token(owner) }],
      [connect(), {
        negotiationId: dealId,
        token: signAccessToken({ userId: String(owner._id), sessionExpiresAt: new Date(Date.now() - 1000).toISOString() }, '10m'),
      }],
    ];
    for (const [socket, data] of refused) {
      await socket.fire('join-negotiation', data);
      assert.ok(!socket.inRoom(room), `refused join: ${JSON.stringify(Object.keys(data))}`);
      assert.strictEqual(socket.got('negotiation-join-error').length, 1);
    }

    // The deal's wholesaler joins (token at connection or with the event).
    const ownerSocket = connect({ token: token(owner) });
    await ownerSocket.fire('join-negotiation', { negotiationId: dealId, userId: 'spoofed', userRole: 'admin' });
    assert.ok(ownerSocket.inRoom(room));
    assert.strictEqual(ownerSocket.got('negotiation-joined').length, 1);

    // The team joins any deal; staff show as the business side.
    const adminSocket = connect();
    await adminSocket.fire('join-negotiation', { negotiationId: dealId, token: token(admin) });
    assert.ok(adminSocket.inRoom(room));
    const staffSocket = connect({ token: token(staff) });
    await staffSocket.fire('join-negotiation', { negotiationId: dealId });
    assert.ok(staffSocket.inRoom(room));

    // Identity on events comes from the token, not from what the client sends.
    const online = ownerSocket.got('user-online');
    assert.ok(online.some((event) => event.userId === String(admin._id) && event.userRole === 'admin'));
    adminSocket.received.length = 0;
    await ownerSocket.fire('typing', { negotiationId: dealId, userId: String(admin._id), username: 'Fake Admin', userRole: 'admin' });
    const typing = adminSocket.got('user-typing');
    assert.strictEqual(typing.length, 1);
    assert.strictEqual(typing[0].userId, String(owner._id));
    assert.strictEqual(typing[0].userRole, 'wholesaler');
    assert.strictEqual(typing[0].username, owner.name);

    // A refused socket can't push events into the room.
    const outsider = refused[4][0];
    adminSocket.received.length = 0;
    await outsider.fire('typing', { negotiationId: dealId, userId: 'x', username: 'x' });
    await outsider.fire('mark-read', { negotiationId: dealId, messageId: 'm1', userId: 'x' });
    await outsider.fire('leave-negotiation', { negotiationId: dealId, userId: String(owner._id) });
    assert.strictEqual(adminSocket.received.length, 0, 'outsider events are ignored');
    assert.ok(ownerSocket.inRoom(room), 'outsider cannot remove the owner');

    // Clients can no longer broadcast chat messages over the socket (messages
    // go through the API, which saves them and then broadcasts).
    await outsider.fire('send-message', { negotiationId: dealId, message: 'fake', userId: 'x', userRole: 'admin' });
    await ownerSocket.fire('send-message', { negotiationId: dealId, message: 'fake', userId: 'x', userRole: 'admin' });
    assert.strictEqual(adminSocket.got('receive-message').length, 0);

    // Read receipts from a member carry their own id.
    await adminSocket.fire('mark-read', { negotiationId: dealId, messageId: 'm2', userId: String(owner._id) });
    const read = ownerSocket.got('message-read');
    assert.strictEqual(read.at(-1).userId, String(admin._id));

    // Leaving and disconnecting clean up.
    await adminSocket.fire('leave-negotiation', { negotiationId: dealId });
    assert.ok(!adminSocket.inRoom(room));
    assert.ok(ownerSocket.got('user-offline').some((event) => event.userId === String(admin._id)));
    await staffSocket.fire('disconnect');
    assert.ok(!staffSocket.inRoom(room));
    assert.strictEqual(NegotiationSocketService.getActiveUsers(dealId), 1);

    // The admin notifications room: admins only, sessions that ended refused.
    const adminRoom = connect();
    await adminRoom.fire('join-admin', { token: token(admin) });
    assert.strictEqual(adminRoom.got('admin-joined').length, 1);
    const staffRoom = connect();
    await staffRoom.fire('join-admin', { token: token(staff) });
    assert.strictEqual(staffRoom.got('admin-join-error').length, 1);
    const endedRoom = connect();
    await endedRoom.fire('join-admin', {
      token: signAccessToken({ userId: String(admin._id), sessionExpiresAt: new Date(Date.now() - 1000).toISOString() }, '10m'),
    });
    assert.strictEqual(endedRoom.got('admin-join-error').length, 1);
  } finally {
    await Negotiation.deleteOne({ _id: deal._id });
    await Product.deleteOne({ _id: product._id });
    await User.deleteMany({ _id: { $in: userIds } });
    await mongoose.disconnect();
  }
}

async function run() {
  const uri = testDatabaseUri('SOCKET_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('Negotiation socket tests skipped: set SOCKET_TEST_MONGODB_URI to a local test database');
    return;
  }
  await runChecks(uri);
  console.log('Negotiation socket tests passed');
}

// The API's database module reconnects after a disconnect, so exit explicitly.
run()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
