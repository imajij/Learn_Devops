#!/bin/sh
# Create the bare repo on first start (the PVC keeps it across restarts), allow pushes, start lighttpd.
set -e
for repo in ${REPOS:-shop-gitops}; do
  if [ ! -d "/srv/git/$repo.git" ]; then
    git init --bare -b main "/srv/git/$repo.git"
    git -C "/srv/git/$repo.git" config http.receivepack true
    echo "created empty repo /srv/git/$repo.git"
  fi
done
chown -R lighttpd:lighttpd /srv/git
git config --system --add safe.directory '*'
exec lighttpd -D -f /etc/lighttpd/lighttpd.conf
