ARG NODE_ENV=production
ARG DATABASE_URL
#FROM node:16.17-alpine
FROM oven/bun:alpine
ARG DATABASE_URL
ARG NODE_ENV
WORKDIR /app

RUN env && ls
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
#COPY package*.json ./
#RUN npm install
COPY package.json bun.lockb ./
RUN bun install

COPY *.js ./
ENV DATABASE_URL=${DATABASE_URL}
ENV NODE_ENV=${NODE_ENV}
RUN --mount=type=bind,source=.step,target=/root/.step env DATABASE_URL=${DATABASE_URL} bun console.js

USER nodejs
EXPOSE 3000

CMD bun start
