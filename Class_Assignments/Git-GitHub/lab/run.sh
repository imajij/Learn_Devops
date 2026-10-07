#!/bin/bash
# runs a command and prints it like a terminal session
r(){ echo "\$ $*"; eval "$@" 2>&1; }
cd "$1"; rm -rf git-demo; mkdir git-demo; cd git-demo
export GIT_AUTHOR_NAME="Ajij Uttam" GIT_COMMITTER_NAME="Ajij Uttam" GIT_AUTHOR_EMAIL="67888293+imajij@users.noreply.github.com" GIT_COMMITTER_EMAIL="67888293+imajij@users.noreply.github.com"
exec > ../t1.txt
r git init -b main
r 'echo "line 1" > tracked.txt'
r git add tracked.txt
r 'git commit -m "Add tracked.txt"'
r 'echo "line 2" >> tracked.txt'
r 'echo "new file" > untracked.txt'
r git status --short
echo "### --- 1) git commit -m without staging ---"
r 'git commit -m "try plain -m"'
echo "### --- 2) git commit -a -m ---"
r 'git commit -a -m "Update tracked.txt using -a"'
r git status --short
r 'git show --stat --oneline HEAD'
echo "### untracked.txt was NOT picked up by -a; it must be added explicitly"
r git add untracked.txt
r 'git commit -m "Add untracked.txt with explicit add"'
r git log --oneline
exec > ../t2.txt
r 'echo "home page" > index.html && git add . && git commit -q -m "main: add index.html"'
r 'echo "about page" > about.html && git add . && git commit -q -m "main: add about.html"'
r 'echo "styles" > style.css && git add . && git commit -q -m "main: add style.css"'
r git log --oneline
r git switch -c feature
r 'echo "contact page" > contact.html && git add . && git commit -q -m "feature: add contact.html"'
r 'echo "footer v1" > footer.html && git add . && git commit -q -m "feature: add footer.html"'
r 'echo "experimental" > beta.html && git add . && git commit -q -m "feature: add beta.html"'
r git log --oneline -4
exec > ../t3.txt
r git switch main
r 'PICK=$(git log feature --format=%h --grep="footer.html")'
r 'echo $PICK'
r 'git cherry-pick $PICK'
r git log --oneline -3
r ls
r 'cat footer.html'
r 'git log --oneline --graph --all'
r 'git log --all --format="%h %s" | grep footer'
