# ---- Stage 1: build (has npm, dev dependencies, runs the checks) ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY server.js ./
RUN npm test
# keep only production dependencies for the next stage
RUN npm prune --omit=dev

# ---- Stage 2: runtime (only node + the app + prod node_modules) ----
FROM node:22-alpine
ENV NODE_ENV=production
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/server.js /app/package.json ./
USER node
EXPOSE 3000
CMD ["node", "server.js"]
