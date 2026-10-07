# CampusDesk web UI: multi-stage build (Node builds the React app, Nginx serves it).
#   docker build -f docker/frontend.Dockerfile -t campusdesk-frontend:dev .
FROM node:22.23.3-alpine AS build
WORKDIR /src
COPY application/frontend/package.json application/frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY application/frontend/ ./
RUN npm run build

FROM nginx:1.31.6-alpine
# Security gate fix (pipeline run 1): Trivy found fixable HIGH CVEs in libexpat and pcre2
# in the base image, so pull the patched Alpine packages at build time.
RUN apk upgrade --no-cache libexpat pcre2
# Run as the unprivileged `nginx` user (uid 101) on port 8080 instead of root on 80.
RUN sed -i -e '/^user /d' -e 's#^pid .*#pid /tmp/nginx.pid;#' /etc/nginx/nginx.conf \
 && rm -f /etc/nginx/conf.d/default.conf /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh \
 && chown -R nginx:nginx /var/cache/nginx /etc/nginx/conf.d
COPY docker/nginx/default.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /src/dist /usr/share/nginx/html
# Where /api/ is proxied to. docker compose: http://backend:8000 ; Kubernetes: the backend Service.
ENV BACKEND_URL=http://campusdesk-backend:8000
USER 101
EXPOSE 8080
