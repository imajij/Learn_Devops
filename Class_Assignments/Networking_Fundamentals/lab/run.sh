#!/bin/bash
# Runs inside the ubuntu-lab container (see ../../Linux_Fundamentals/lab/Dockerfile).
# Usage: docker exec -i ubuntu-lab bash -s < run.sh > transcript.txt   (sections are separated by @@name lines)
r(){ echo "# $*"; eval "$@" 2>&1; }
s(){ echo "@@$1"; }
s 01-hostname;   r hostname
s 02-whoami;     r whoami
s 03-ip-a;       r ip a
s 04-hostname-I; r hostname -I
s 05-ip-route;   r ip route
s 06-ping;       r ping -c 4 google.com
s 07-nslookup;   r nslookup google.com
s 08-dig;        r dig +short github.com; r 'dig github.com | sed -n "/ANSWER SECTION/,/^$/p"'
s 09-curl;       r curl -sI https://example.com; r 'curl -s -o /dev/null -w "status=%{http_code} ip=%{remote_ip} time=%{time_total}s\n" https://example.com'
s 10-ss;         r ss -tulnp
s 11-etc-hosts;  r cat /etc/hosts; r 'echo "127.0.0.1 ajij.local" >> /etc/hosts'; r 'ping -c 1 ajij.local'; r 'curl -sI http://ajij.local | head -2'
s 12-tracepath;  r tracepath -n -m 10 1.1.1.1
s 13-traceroute; r traceroute -n -m 10 1.1.1.1
s 14-telnet;     r '(printf "HEAD / HTTP/1.1\nHost: google.com\nConnection: close\n\n"; sleep 3) | telnet google.com 80 | head -9'; r '(sleep 1) | telnet localhost 81'
