# Shared helpers for the lab scripts (sourced). Output of every command is captured as-is.
r(){ echo "\$ $*"; eval "$@" 2>&1; }
note(){ echo "### $*"; }
PROJ="$HOME/projects/Learn_DevOps/Class_Assignments/Devops_Project_And_Troubleshooting"
APP="$PROJ/final-devops-project"
LAB="$PROJ/lab"
WORK="$HOME/devops-lab/final"
K="kubectl --context final"
