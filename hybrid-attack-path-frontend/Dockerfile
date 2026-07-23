# hap-soc-api 배포용. 내부 포트 3001로 뜬다 (외부 노출 없음, nginx만 접근).
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
# NEXT_PUBLIC_* 값은 빌드 시점에 번들에 고정되므로 .env.production이 이 시점에 존재해야 함
RUN npm run build

FROM node:20-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/.next ./.next
COPY --from=build /app/next.config.mjs ./next.config.mjs

EXPOSE 3001
CMD ["npm", "start", "--", "-p", "3001"]
