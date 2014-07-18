#!/bin/bash

# 20140414 Joachim van de Haterd, Moyo Web Architects
#
# At Moyo, we use a lot of repos that we share among projects. These are symlinked by a shell script.
# This script enables us to check (and optionally pull) all repos from a shared project, instead of manually checking each little repository.

# Please note that this script will only properly work in Mac OSX and possible in *BSD. Something with a different standard for echo sequences.

# Variables. Please tweak as necessary
PROJECT_DIR=/var/www
VERBOSITY=0
AUTO_PULL=1
SHARED_REPO_NAME=""
BRANCH_NAME=""

while getopts b:hnp:v opt
do
    case "$opt" in
		b) BRANCH_NAME="$OPTARG";echo "--- Branch $BRANCH_NAME selected ---";;
    	h)  
		echo "This command will check all repositories within a project for changes."
		echo
		echo "a : Enable automatic pulling. Use with care."
		echo "b : automatically checkout specified branch. Implies the -a option. Use with care."
	  	echo "h : Print this help message."
	  	echo "n : Does not pull automatcally. Instead give a helpful status update per repository. Warning, this clashes with the -b option."
	  	echo "p : Use specified project, e.g. moyo-content."
		echo "v : Be more verbose by showing a message for each subdirectory"
		exit 0;;
		n) echo "--- Dry run activated.---";AUTO_PULL=0;;
		p) SHARED_REPO_NAME="$OPTARG"; echo "--- Shared repository $SHARED_REPO_NAME selected ---";;
		v) echo "--- Verbosity mode on. You asked for it. ---";VERBOSITY=1;;
    	\?) echo >&2 "usage: $0 [-a] [-b branch] [-h] [-p project] [-v]";exit 1;;
	esac
done

shift `expr $OPTIND - 1`

# If a shared repo name is specified, go to this dir. Otherwise, merely use PWD
if [ "$SHARED_REPO_NAME" != "" ] ; then
	PROJECT_DIR+="/"$SHARED_REPO_NAME
else
	PROJECT_DIR="$(pwd)"
fi
# 
# Function declarations
#
# Verbosity function. 
# If the -v option has been chosen, do a echo. Otherwise, just be silent.
debugln() {
	if [ $VERBOSITY -eq 1 ] ; then
		echo -e $1
	fi
}

# Determine whether $PROJECT_DIR is a valid directory
if [[ ! -d $PROJECT_DIR ]] ; then
	echo $PROJECT_DIR" is not a valid directory";
	exit 1
fi
cd $PROJECT_DIR

echo "Removing pesky .DS_Store files."
find . -name *.DS_Store -type f -delete

# Check all subdirectories for git repos
# If a repo is found, try to determine whether anything needs to be done. Otherwise, just print a message and move on
for f in *; do
    if [[ -d "$f" && ! -L "$f" ]]; then
        # $f is a directory and not a symlink
		debugln "Entering directory \033[1m$f\033[0m..."
		if [[ ! -e $f"/.git"  || ! -d $f"/.git" ]]; then
			debugln "Subdirectory \033[1m$f\033[0m does not contain a git repository. \033[0;32mIgnoring\033[0m."
		else
			cd "$f"

			if [ -n "$(git status --porcelain)" ]; then
				# Possible @TODO: Auto-stash?
				# See whether anything needs to be pushed. 
				echo -e "The \033[1m$f\033[0m repository has changes."
				echo -e "\033[0;31mPlease commit and push manually\033[0m."
			else
				CURRENT_BRANCH=`git rev-parse --abbrev-ref HEAD`
				# Branch chosen? Then checkout
				if [ "$BRANCH_NAME" != "" ]; then
					if [ "$CURRENT_BRANCH"  != "$BRANCH_NAME" ] ; then
						debugln "Checking out  \033[1m[$f][$BRANCH_NAME]\033[0m."
						CURRENT_BRANCH=$BRANCH_NAME
						git checkout "$BRANCH_NAME" --quiet
					fi
				else
					# Get current branch
					debugln "Current branch = $CURRENT_BRANCH"
				fi
				if [[ `git fetch origin;git rev-list HEAD..origin/$CURRENT_BRANCH --count` != '0' ]]; then
					# See whether anything needs to be pulled
					echo -e "The \033[1m[$f][$CURRENT_BRANCH]\033[0m repository has remote changes."
					
					# If automatic pulling is enabled (which is by default), pull the shit. Otherwise, give a friendly message.
					if [ $AUTO_PULL -eq 1 ]; then
						git pull --all --quiet
					else
						echo -e "\033[0;33mPlease perform a pull manually\033[0m."
					fi
				else
					# No changes. Give a friendly message
					debugln "No changes in \033[1m[$f][$CURRENT_BRANCH]\033[0m . \033[0;32mMoving on...\033[0m."
				fi
			fi

			#######
			# NEXT!
			debugln
			cd ..
		fi
    fi
done

echo "Done!"
exit 0
