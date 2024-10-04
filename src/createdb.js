import dotenv from 'dotenv'
import dotenvExpand from 'dotenv-expand';
dotenvExpand.expand(dotenv.config({ path: [`.env.${process.env.NODE_ENV}.local`, '.env.local', `.env.${process.env.NODE_ENV}`, '.env'] }));
import { PrismaClient } from '@prisma/client'

// prisma сама создает БД, но если нужно создание по шаблону, тут можно сделать правки

async function createDB() {
  const databaseUrl = new URL(process.env.DATABASE_URL);
  const createDbName = databaseUrl.pathname.slice(1);
  databaseUrl.pathname = 'postgres'; // always exists
  process.env.DATABASE_URL = databaseUrl.toString();
  const prisma = new PrismaClient()
  try {
    const exists = await prisma.$queryRaw`SELECT datname FROM pg_catalog.pg_database WHERE datname = ${createDbName}`;
    console.log(exists, exists.length);
    if (exists.length === 0) {
      await prisma.$executeRawUnsafe(`CREATE DATABASE "${createDbName} TEMPLATE iconicactionstemplate"`);
    }
  } catch (e) {
    await prisma.$disconnect()
    throw e;
  }
}

createDB().then().catch((e) => {
  console.error(e)
  process.exit(1)
})
