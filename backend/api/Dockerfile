FROM node:24-slim

RUN apt-get update -y && apt-get install -y openssl && apt-get install -y wget

WORKDIR /backend/api

COPY package.json package-lock.json ./

RUN npm ci


COPY . .


CMD ["sh", "-c", "npm run db:deploy && npm run dev"]


