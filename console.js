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
console.log(config);  

async function postgres_now() {
  const client = new Client(config);
  await client.connect();
  const res = await client.query("select current_schema");
  await client.end();
  return res.rows[0];
}

const res = await(postgres_now());
console.log(res);

