const assert = require('assert');

// Live deal chat over a REAL socket.io server and client (not a stand-in):
// no token -> join refused; a wholesaler can only join their own deal;
// the role / user id a client claims is ignored; admin and staff can join any
// deal. Needs a local "test"/"demo" database (see tests/helpers/testDb.js):
//
//   TEST_MONGODB_URI=mongodb://127.0.0.1:27019/demomart_test node tests/negotiationSocketReal.test.js

process.env.JWT_SECRET = 'test-access-secret-0123456789-abcdefghij';
const http = require('http');
const { isSafeTestDatabase: isLocalDatabase, testDatabaseUri, assertSafeToWipe } = require('./helpers/testDb');

const waitFor = (socket, event, ms = 1500) => new Promise((resolve) => {
  const timer = setTimeout(() => { socket.off(event, handler); resolve(null); }, ms);
  const handler = (payload) => { clearTimeout(timer); resolve(payload || {}); };
  socket.once(event, handler);
});

async function run(uri) {
  process.env.MONGODB_URI = uri;
  const mongoose = require('mongoose');
  const { Server } = require('socket.io');
  const { io: connectClient } = require('socket.io-client');
  const { User, Negotiation, Product } = require('../src/models');
  const { signAccessToken, signRefreshToken } = require('../src/utils/jwtTokens');
  const NegotiationSocketService = require('../src/services/negotiationSocketService');

  await mongoose.connect(uri);
  assertSafeToWipe(mongoose);
  const suffix = `${Date.now()}${Math.floor(Math.random() * 1000)}`;
  const makeUser = (role, extra = {}) => User.create({
    name: `Real socket ${role}`, email: `real-socket-${role}-${suffix}@example.com`,
    authProvider: 'email', role, isActive: true, ...extra,
  });
  const owner = await makeUser('wholesaler');
  const stranger = await makeUser('wholesaler', { email: `real-socket-stranger-${suffix}@example.com` });
  const buyer = await makeUser('buyer');
  const admin = await makeUser('admin');
  const staff = await makeUser('staff', { username: `realsocketstaff${suffix}` });
  const userIds = [owner, stranger, buyer, admin, staff].map((user) => user._id);
  const product = await Product.create({ name: `Real Socket Drill ${suffix}`, sku: `RSOCK-${suffix}`, category: 'Tools', mrp: 100, retailPrice: 90, wholesalePrice: 80 });
  const deal = await Negotiation.create({
    wholesalerId: owner._id, productId: product._id, productSnapshot: { name: product.name, price: 80 },
    requestedQuantity: 10, requestedPricePerUnit: 75, requestedTotalPrice: 750,
    expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000),
  });
  const dealId = String(deal._id);
  const token = (user) => signAccessToken({ userId: String(user._id) }, '10m');

  const server = http.createServer();
  const io = new Server(server, { transports: ['websocket'] });
  NegotiationSocketService.initializeSocket(io);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  const clients = [];
  const client = async (auth) => {
    const socket = connectClient(url, { transports: ['websocket'], auth, forceNew: true, reconnection: false });
    clients.push(socket);
    await waitFor(socket, 'connect', 3000);
    return socket;
  };
  const join = (socket, payload) => new Promise((resolve) => {
    const finish = (outcome) => {
      clearTimeout(timer);
      socket.off('negotiation-joined', onJoined);
      socket.off('negotiation-join-error', onRefused);
      resolve(outcome);
    };
    const onJoined = () => finish('joined');
    const onRefused = () => finish('refused');
    const timer = setTimeout(() => finish('silent'), 2000);
    socket.once('negotiation-joined', onJoined);
    socket.once('negotiation-join-error', onRefused);
    socket.emit('join-negotiation', payload);
  });

  try {
    // No token anywhere: refused.
    let socket = await client({});
    assert.strictEqual(await join(socket, { negotiationId: dealId }), 'refused', 'no token => refused');

    // Claims in the event are ignored (id / role spoofing without a token).
    socket = await client({});
    assert.strictEqual(await join(socket, { negotiationId: dealId, userId: String(owner._id), userRole: 'admin' }), 'refused', 'spoofed role without token => refused');

    // Refresh token / garbage token: refused.
    socket = await client({ token: signRefreshToken({ userId: String(owner._id) }, '10m') });
    assert.strictEqual(await join(socket, { negotiationId: dealId }), 'refused', 'refresh token => refused');
    socket = await client({});
    assert.strictEqual(await join(socket, { negotiationId: dealId, token: 'x.y.z' }), 'refused', 'garbage token => refused');

    // A wholesaler claiming to be admin still only gets their own deals.
    socket = await client({ token: token(stranger) });
    assert.strictEqual(await join(socket, { negotiationId: dealId, userRole: 'admin', userId: String(admin._id) }), 'refused', "another wholesaler's deal => refused even with an admin claim");
    // A retail customer never joins.
    socket = await client({ token: token(buyer) });
    assert.strictEqual(await join(socket, { negotiationId: dealId }), 'refused', 'buyer => refused');

    // The deal's wholesaler: token at handshake, or with the event.
    const ownerSocket = await client({ token: token(owner) });
    assert.strictEqual(await join(ownerSocket, { negotiationId: dealId, token: token(owner) }), 'joined', 'own deal => joined');

    // Admin and staff can join any deal; the wholesaler hears them come online.
    const online = waitFor(ownerSocket, 'user-online');
    const adminSocket = await client({ token: token(admin) });
    assert.strictEqual(await join(adminSocket, { negotiationId: dealId, token: token(admin) }), 'joined', 'admin => joined');
    const seen = await online;
    assert.ok(seen && seen.userRole === 'admin' && seen.userId === String(admin._id), 'identity comes from the token');
    const staffSocket = await client({ token: token(staff) });
    assert.strictEqual(await join(staffSocket, { negotiationId: dealId, token: token(staff) }), 'joined', 'staff => joined');

    // Admin room: only admins.
    const adminRoomOwner = await client({ token: token(owner) });
    adminRoomOwner.emit('join-admin', { token: token(owner) });
    assert.ok(await waitFor(adminRoomOwner, 'admin-join-error'), 'wholesaler cannot join the admin room');
    adminSocket.emit('join-admin', { token: token(admin) });
    assert.ok(await waitFor(adminSocket, 'admin-joined'), 'admin joins the admin room');
  } finally {
    clients.forEach((c) => c.close());
    await new Promise((resolve) => io.close(resolve));
    await Negotiation.deleteOne({ _id: deal._id });
    await Product.deleteOne({ _id: product._id });
    await User.deleteMany({ _id: { $in: userIds } });
    await mongoose.disconnect();
  }
}

(async () => {
  const uri = testDatabaseUri('SOCKET_TEST_MONGODB_URI');
  if (!isLocalDatabase(uri)) {
    console.log('Real socket tests skipped: set SOCKET_TEST_MONGODB_URI (or TEST_MONGODB_URI) to a local test database');
    return;
  }
  await run(uri);
  console.log('Negotiation real-socket tests passed');
})().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => setTimeout(() => process.exit(), 50));
