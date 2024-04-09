import http from "http";
import { createRouter } from "next-connect";

const port = process.env.HTTP_PORT || 3000;
import pkg from "pg";
const { Client, Pool } = pkg;

const config = {
  connectionString: process.env.DATABASE_URL,
  ssl: true,
  // this object will be passed to the TLSSocket constructor
  // ssl: {
  //   rejectUnauthorized: false,
  //   ca: fs.readFileSync('/path/to/server-certificates/root.crt').toString(),
  //   key: fs.readFileSync('/path/to/client-key/postgresql.key').toString(),
  //   cert: fs.readFileSync('/path/to/client-certificates/postgresql.crt').toString(),
  // },
};

async function postgres_now() {
  const client = new Client(config);
  await client.connect();
  const res = await client.query("select current_schema");
  await client.end();
  return res.rows[0];
}

const handler = createRouter()
  .get("/iconicactions", async (req, res) => {
    const now = await(postgres_now());
    res.end(JSON.stringify(now));
  })
  .handler();

http.createServer(handler).listen(port);
