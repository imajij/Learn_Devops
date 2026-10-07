#!/bin/bash
# Runs inside the ubuntu-lab container (systemd as PID 1). Usage: docker exec -i ubuntu-lab bash -s <section> < run.sh
r(){ echo "# $*"; eval "$@" 2>&1; }
cd /root
case "$1" in
links)
  r 'mkdir -p /root/linkdemo && cd /root/linkdemo'
  r 'echo "Hello from Ajij" > original.txt'
  r 'ln -s original.txt soft.txt'
  r 'ln original.txt hard.txt'
  r 'ls -li'
  r 'cat soft.txt hard.txt'
  echo "### inode: hard.txt shares original.txt's inode, link count is 2. soft.txt has its own inode."
  r 'stat -c "%n inode=%i links=%h type=%F" original.txt hard.txt soft.txt'
  r 'echo "edited via hard link" >> hard.txt'
  r 'cat original.txt'
  echo "### delete the original"
  r 'rm original.txt'
  r 'ls -li'
  r 'cat hard.txt'
  r 'cat soft.txt'
  echo "### soft link to a directory works; hard link to a directory is refused"
  r 'mkdir mydir && ln -s mydir mydir-soft && ls -ld mydir-soft'
  r 'ln mydir mydir-hard'
  echo "### deleting links"
  r 'unlink soft.txt'
  r 'rm hard.txt mydir-soft'
  r 'ls -la'
  ;;
users)
  r 'ls -l $(which useradd adduser)'
  r 'head -1 /usr/sbin/adduser'
  echo "### useradd: low-level binary, does only what flags say"
  r 'useradd testuser1'
  r 'grep testuser1 /etc/passwd'
  r 'ls -ld /home/testuser1'
  r 'passwd -S testuser1'
  echo "### adduser: interactive Perl wrapper around useradd (recommended on Ubuntu/Debian)"
  r 'adduser --gecos "Ajij Uttam" --disabled-password ajij'
  r 'grep ajij /etc/passwd'
  r 'ls -la /home/ajij'
  r 'id ajij'
  r 'usermod -aG sudo ajij && id ajij'
  r 'grep -E "^#?(DSHELL|DHOME|SKEL|USERGROUPS)=" /etc/adduser.conf'
  echo "### cleanup: deluser --remove-home needs the full perl package; userdel works without it"
  r 'deluser --remove-home testuser1'
  r 'userdel testuser1 && grep -c testuser1 /etc/passwd'
  ;;
journal)
  r 'systemctl status nginx --no-pager | head -8'
  r 'journalctl --list-boots --no-pager'
  r 'journalctl -n 10 --no-pager'
  r 'systemctl restart nginx'
  r 'journalctl -u nginx --no-pager'
  r 'logger -t ajij-app "deployment finished for 24bcs10103"'
  r 'journalctl -t ajij-app --no-pager'
  r 'logger -p user.err -t ajij-app "simulated error: disk quota exceeded"'
  r 'journalctl -p err --no-pager -n 5'
  r 'journalctl -u cron --since "10 min ago" --no-pager -o short-iso'
  r 'journalctl -u nginx -o json-pretty -n 1 --no-pager | head -15'
  r 'journalctl --disk-usage'
  ;;
cheat1)
  r 'pwd'
  r 'mkdir -p projects/app/logs && cd projects'
  r 'touch app/main.py app/README.md'
  r 'ls -la app'
  r 'cp app/main.py app/main.bak && mv app/main.bak app/backup.py && ls app'
  r 'rm app/backup.py && ls app'
  r 'printf "error: db down\ninfo: started\nerror: timeout\ninfo: ok\n" > app/logs/app.log'
  r 'cat app/logs/app.log'
  r 'head -n 2 app/logs/app.log; tail -n 1 app/logs/app.log'
  r 'grep -n error app/logs/app.log'
  r 'grep -c info app/logs/app.log'
  r 'wc -l app/logs/app.log'
  r 'cut -d: -f1 app/logs/app.log | sort | uniq -c'
  r 'find /root/projects -name "*.py"'
  ;;
cheat2)
  r 'cd /root/projects/app'
  r 'chmod 750 main.py && ls -l main.py'
  r 'chown ajij:ajij README.md && ls -l README.md'
  r 'tar -czf /tmp/app.tar.gz -C /root/projects app && tar -tzf /tmp/app.tar.gz'
  r 'uname -a'
  r 'cat /etc/os-release | head -4'
  r 'whoami; id'
  r 'df -h /'
  r 'du -sh /var/log'
  r 'free -h'
  r 'uptime'
  r 'ps aux --sort=-%mem | head -6'
  r 'top -bn1 | head -12'
  r 'which nginx bash'
  r 'echo $PATH'
  r 'curl -sI http://localhost | head -3'
  ;;
esac
