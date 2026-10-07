# Ubuntu 24.04 with systemd as PID 1, so journalctl and systemctl behave like a real server.
FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      systemd systemd-sysv dbus adduser passwd sudo nginx cron \
      iproute2 iputils-ping iputils-tracepath traceroute dnsutils curl telnet ca-certificates nano less \
    && rm -rf /var/lib/apt/lists/* \
    && systemctl enable nginx cron
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]
