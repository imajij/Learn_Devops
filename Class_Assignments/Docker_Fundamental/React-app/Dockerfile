# Stage 1: install dependencies and build the static bundle
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: serve the built files with Nginx (Node is not needed at runtime)
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
