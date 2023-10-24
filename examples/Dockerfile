FROM node:16.17-alpine
WORKDIR /app

RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001
COPY package*.json ./
RUN npm i
COPY *.js ./

USER nodejs
EXPOSE 3000

CMD npm start
