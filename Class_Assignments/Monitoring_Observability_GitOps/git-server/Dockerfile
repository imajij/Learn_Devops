# Minimal Git smart-HTTP server: lighttpd runs git-http-backend as CGI.
# Clone/fetch (Argo CD) and push (me) both work over plain HTTP on port 3000.
FROM alpine:3.22
RUN apk add --no-cache git git-daemon lighttpd
COPY lighttpd.conf /etc/lighttpd/lighttpd.conf
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 3000
ENTRYPOINT ["/entrypoint.sh"]
