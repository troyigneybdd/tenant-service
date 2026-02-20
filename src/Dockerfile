
FROM node:18-alpine
WORKDIR /app
COPY src/apps/tenant-api/package*.json ./
RUN npm install --production
COPY src/apps/tenant-api/tenants-api.js ./
COPY ./env.js /shared/env.js
ENV PORT=8080
EXPOSE 8080
ENV NODE_ENV=production
EXPOSE 8080
CMD ["node", "tenants-api.js"]
