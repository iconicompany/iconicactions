#FROM node:16.17-alpine
FROM oven/bun:alpine
WORKDIR /app

RUN env && ls
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
#COPY package*.json ./
#RUN npm install
COPY package.json bun.lockb ./
RUN --mount=type=bind,source=.step,target=/root/.step ls -l /root/.step
#RUN ls -l /root/.step

COPY *.js ./

USER nodejs
EXPOSE 3000

CMD bun start
