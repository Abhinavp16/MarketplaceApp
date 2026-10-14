# DemoMart API image. Build context: ../backend (see docker-compose.yml).

FROM node:22-alpine AS deps
WORKDIR /app
# The lock files are written by npm 11; the npm bundled with Node 22 (10.x) rejects them in `npm ci`.
RUN npm install -g npm@11 --no-fund --no-audit
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

FROM node:22-alpine
ENV NODE_ENV=production \
    PORT=5000 \
    LOCAL_UPLOADS_DIR=/data/uploads \
    LOCAL_PRIVATE_DIR=/data/private
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
COPY scripts ./scripts
COPY assets ./assets
# /data is the persistent volume (public uploads + private media).
RUN mkdir -p /data/uploads /data/private && chown -R node:node /data /app
USER node
EXPOSE 5000
HEALTHCHECK --interval=15s --timeout=5s --start-period=30s --retries=5 \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||5000)+'/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"
CMD ["node", "src/server.js"]
