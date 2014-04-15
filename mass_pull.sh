#!/bin/bash

# J. van de Haterd, Moyo Web Architects
#
# At Moyo, we use a lot of repos that we share among projects. These are symlinked by a shell script
# This script enables us to check (and pull) any 
# This script pulls all the repos from a shared project

# Please note that this script will only properly work in Mac OSX. 
# Why the fuck does apple have its own escape sequence 'standards' for echo? Fuck them.

# @TODO: Make an option to check only instead of pulling immediately
# @TODO: create a verbosity flag. 

# Variables. Probably dependent on the idiot who configured the host system
# @TODO add more when needed
PROJECT_DIR=~/www

# If a shared repo is given in the CLI, go to this dir
if [ -n "$1" ]
then
	PROJECT_DIR+="/"$1
else
	PROJECT_DIR="$(pwd)"
fi

# Determine whether $PROJECT_DIR is a valid directory
if [[ ! -d $PROJECT_DIR ]] ; then
	echo $PROJECT_DIR" is not a valid directory";
	exit 1
fi
cd $PROJECT_DIR

# Check all subdirectories for git repos
# If a repo is found, try to determine whether anything needs to be done.
# Otherwise, just print a message and move on
for f in *; do
    if [[ -d "$f" && ! -L "$f" ]]; then
        # $f is a directory and not a symlink
		echo -e "Entering directory \033[1m$f\033[0m..."
		if [[ ! -e $f"/.git"  || ! -d $f"/.git" ]]; then
			echo -e "Subdirectory \033[1m$f\033[0m does not contain a git repository. \033[0;32mIgnoring\033[0m."
		else
			cd "$f"
			if [ -n "$(git status --porcelain)" ]; then
				# See whether anything needs to be pushed. 
				echo -e "The \033[1m$f\033[0m repository has changes. \033[0;31mPlease commit and push manually\033[0m."
			elif [ "$(git rev-list HEAD...origin/master --count)" -gt 0 ]; then
				# See whether anything needs to be pulled
				echo -e "The \033[1m$f\033[0m has remote changes. \033[0;33mWe need to pull\033[0m."
				#git pull
			else 
				echo -e "No changes in the \033[1m$f\033[0m repository. \033[0;32mIgnoring\033[0m."
			fi
			cd ..
		fi
    fi
done

exit 0
