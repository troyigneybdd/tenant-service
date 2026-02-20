
FROM node:18-alpine
WORKDIR /app
COPY src/package*.json ./
RUN npm install --production
COPY src/tenants-api.js ./
COPY src/env.js ./env.js
ENV PORT=8080
EXPOSE 8080
ENV NODE_ENV=production
CMD ["node", "tenants-api.js"]
