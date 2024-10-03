import dotenv from 'dotenv'
import dotenvExpand from 'dotenv-expand';
dotenvExpand.expand(dotenv.config({ path: [ `.env.${process.env.NODE_ENV}.local`, '.env.local', `.env.${process.env.NODE_ENV}`, '.env'] }));

import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
  const user = await prisma.user.create({
    data: {
      name: 'Alice',
      email: 'alice@prisma.io',
    },
  })
  console.log(user)
}

main()
  .then(async () => {
    await prisma.$disconnect()
  })
  .catch(async (e) => {
    console.error(e)
    await prisma.$disconnect()
    process.exit(1)
  })
