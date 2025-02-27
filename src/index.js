import http from "http";
import { createRouter } from "next-connect";
import dotenv from 'dotenv'
import dotenvExpand from 'dotenv-expand';
dotenvExpand.expand(dotenv.config({ path: [`.env.${process.env.NODE_ENV}.local`, '.env.local', `.env.${process.env.NODE_ENV}`, '.env'] }));
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()
const port = process.env.HTTP_PORT || 3000;

const handler = createRouter()
  .get("/iconicactions", async (req, res) => {
    const result = await prisma.educationLevel.findMany();
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify(result));
  })
  .handler();

http.createServer(handler).listen(port);
