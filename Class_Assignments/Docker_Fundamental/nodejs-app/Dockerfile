FROM node:22-alpine
WORKDIR /app
COPY package.json server.js ./
# run as the unprivileged "node" user that ships with the image
USER node
EXPOSE 3000
CMD ["node", "server.js"]
