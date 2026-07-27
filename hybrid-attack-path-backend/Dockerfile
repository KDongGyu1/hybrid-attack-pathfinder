# hap-soc-api 배포용. 내부 포트 4000으로 뜬다 (nginx가 3000을 점유하므로 PORT=4000).
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production
COPY package*.json ./
RUN npm ci --omit=dev
COPY --from=build /app/dist ./dist

# PORT은 docker-compose에서 4000으로 주입 (main.ts가 process.env.PORT를 그대로 읽음, 코드 수정 없음)
EXPOSE 4000
CMD ["node", "dist/main"]
