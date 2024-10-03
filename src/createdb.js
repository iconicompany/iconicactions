import dotenv from 'dotenv'
import dotenvExpand from 'dotenv-expand';
dotenvExpand.expand(dotenv.config({ path: [ `.env.${process.env.NODE_ENV}.local`, '.env.local', `.env.${process.env.NODE_ENV}`, '.env'] }));

// prisma сама создает БД, но если нужно создание по шаблону, тут можно сделать правки
import { PrismaClient } from '@prisma/client'
const prisma = new PrismaClient()


async function createDB() {

  const databaseUrl = new URL(process.env.DATABASE_URL);
  const createDbName=databaseUrl.pathname.slice(1);;
  databaseUrl.pathname='postgres';
  process.env.DATABASE_URL=databaseUrl.toString();

  return await prisma.$executeRaw`CREATE DATABASE ${createDbName}`;
}

createDB().then(async () => {
  await prisma.$disconnect()
})
.catch(async (e) => {
  console.error(e)
  await prisma.$disconnect()
  process.exit(1)
})
