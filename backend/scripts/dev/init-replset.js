// Idempotently initiates the single-node replica set "rs0" on the demo mongod.
// Used by start-mongo.sh when mongosh is not installed. Local (127.0.0.1) only.
const { MongoClient } = require('mongoose').mongo; // driver bundled with mongoose

const port = Number(process.env.DEMO_MONGO_PORT || 27018);
const host = `127.0.0.1:${port}`;

async function main() {
  const client = new MongoClient(`mongodb://${host}/?directConnection=true`, { serverSelectionTimeoutMS: 15000 });
  await client.connect();
  const admin = client.db('admin');
  try {
    await admin.command({ replSetGetStatus: 1 });
    console.log('Replica set already initiated.');
  } catch (error) {
    if (error.codeName !== 'NotYetInitialized' && error.code !== 94) throw error;
    await admin.command({ replSetInitiate: { _id: 'rs0', members: [{ _id: 0, host }] } });
    console.log('Replica set rs0 initiated.');
  }
  for (let i = 0; i < 60; i += 1) {
    const hello = await admin.command({ hello: 1 });
    if (hello.isWritablePrimary) break;
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  await client.close();
}

main().catch((error) => {
  console.error(`Could not initiate replica set: ${error.message}`);
  process.exit(1);
});
