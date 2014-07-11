#!/bin/bash

# 20140414 Joachim van de Haterd, Moyo Web Architects
#
# At Moyo, we use a lot of repos that we share among projects. These are symlinked by a shell script.
# This script enables us to check (and optionally pull) all repos from a shared project, instead of manually checking each little repository.

# Please note that this script will only properly work in Mac OSX. Why the f*ck does apple have its own escape sequence 'standards' for echo?

# Variables. Please tweak as necessary
PROJECT_DIR=~/www
VERBOSITY=0
AUTO_PULL=0
SHARED_REPO_NAME=""

while getopts ahp:v opt
do
    case "$opt" in
		a) echo "--- Automatic pulling enabled ---";AUTO_PULL=1;;
    	h)  
		echo "This command will check all repositories within a project for changes."
		echo
		echo "a : Enable automatic pulling. Use with care."
	  	echo "h : Print this help message."
	  	echo "p : Use specified project, e.g. moyo-content."
		echo "v : Be more verbose by showing a message for each subdirectory"
		exit 0;;
		p) SHARED_REPO_NAME="$OPTARG"; echo "--- Shared repository $SHARED_REPO_NAME selected ---";;
		v) echo "--- Verbosity mode on. You asked for it. ---";VERBOSITY=1;;
    	\?) echo >&2 "usage: $0 [-a] [-h] [-p project] [-v]";exit 1;;
	esac
done

shift `expr $OPTIND - 1`

# If a shared repo name is specified, go to this dir. Otherwise, merely use PWD
if [ "$SHARED_REPO_NAME" != "" ]
then
	PROJECT_DIR+="/"$SHARED_REPO_NAME
else
	PROJECT_DIR="$(pwd)"
fi

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
		if [ $VERBOSITY -eq 1 ]; then
			echo -e "Entering directory \033[1m$f\033[0m..."
		fi
		if [[ ! -e $f"/.git"  || ! -d $f"/.git" ]]; then
			if [ $VERBOSITY -eq 1 ] ; then
				echo -e "Subdirectory \033[1m$f\033[0m does not contain a git repository. \033[0;32mIgnoring\033[0m."
			fi
		else
			cd "$f"
			if [ -n "$(git status --porcelain)" ]; then
				# See whether anything needs to be pushed. 
				echo -e "The \033[1m$f\033[0m repository has changes."
				echo -e "\033[0;31mPlease commit and push manually\033[0m."
			elif [[ `git fetch origin;git rev-list HEAD..origin/master --count` != '0' ]]; then
				# See whether anything needs to be pulled
				echo -e "The \033[1m$f\033[0m repository has remote changes."
				if [ $AUTO_PULL -eq 1 ] ; then
					git pull --all
				else
					echo -e "\033[0;33mPlease perform a pull manually\033[0m."
				fi
			elif [ $VERBOSITY -eq 1 ]; then 
				echo -e "No changes in the \033[1m$f\033[0m repository. \033[0;32mIgnoring\033[0m."
			fi

			# Print an empty line for cosmetic purposes
			if [ $VERBOSITY -eq 1 ]; then
				echo
			fi
			cd ..
		fi
    fi
done

# We're done. Show the world.
echo "Done!"
exit 0
