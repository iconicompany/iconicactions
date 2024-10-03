ARG NODE_REPO=oven/bun:alpine
ARG NODE_LOCK=bun.lockb
ARG NPM=bun
ARG NODE=bun
ARG RUNNER_REPO=oven/bun:alpine # node:20-alpine, bcgovimages/alpine-node-libreoffice:20, etc
ARG RUNNER_NPM=bun # npm, pnpm, etc

# ARG NODE_REPO=node
# ARG NODE_VERSION=20-alpine
# ARG NODE_LOCK=pnpm-lock.yaml
# ARG NPM=pnpm
# ARG NODE=pnpm

FROM ${NODE_REPO} AS base
# RUN apk add --no-cache libstdc++
# RUN npm i -g pnpm@latest

FROM base AS prod-deps
ARG NODE_LOCK
ARG NPM
WORKDIR /app
COPY package.json ${NODE_LOCK} ./
RUN ${NPM} install --frozen-lockfile --production

FROM prod-deps AS deps
ARG NODE_LOCK
ARG NPM
WORKDIR /app
COPY package.json ${NODE_LOCK} ./
RUN ${NPM} install  --frozen-lockfile

#FROM deps as builder
#ARG NPM
#WORKDIR /app
#ENV NODE_ENV=production
#COPY src src
#COPY *.?js *.yaml *.ts? *.json *.lock? ./
#RUN ${NPM} run build

# Production image, copy all the files and run next
FROM prod-deps AS runner
WORKDIR /app
ENV NODE_ENV=production
#RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
USER 1000
EXPOSE 3000

#COPY --from=prod-deps /app/node_modules ./node_modules
COPY package.json ./
COPY src src
#COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
#COPY --from=builder --chown=nextjs:nodejs /app/public ./public
#COPY --from=builder --chown=nextjs:nodejs /app/next.config.mjs ./

CMD "bun deploy && bun start"
