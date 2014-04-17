#!/bin/bash

# Read a composer.json file, parse the dependencies and create correct symlinks in the current project folder
# Obviously, this file needs to be run from a web project root directory. There MUST be a composer.json file.
# 

# Variables. Please tweak as necessary
PROJECT_DIR=~/www
VERBOSITY=0
ALLREPOS=()
PROJECTS=()
REPOS=()

# Arguments (@TODO):
# -v Be verbose
# -h Print a help file

# First, let us run some tests. 
# 1. Is there a composer.json file in the current directory?
if [ ! -f ./composer.json ] ; then
	echo -e "This script needs a composer.json file to properly run. Please make sure that you are in the correct subdirectory or create a composer.json file"
	exit 1
fi

# 2: resolve any dependencies
if [ ! $(type -p JSON.sh) ] ; then
	echo -e "No JSON parser found. In order to run this script, we need the JSON.sh script."
	echo -e "Please install this script by running the following command: \033[1msudo npm install -g JSON.sh\033[0m"
	exit 1
fi

# 3: Is it a Joomla! project? :-)
# @TODO: add more types of projects, e.g. Nooku
if [ ! -d ./libraries/joomla ] ; then
	echo -e "You are not in a joomla project. Therefore, this script will be useless."
	#exit 1
fi

# 4: is the project_dir configured correctly? 
if [[ ! -d $PROJECT_DIR ]] ; then
	echo $PROJECT_DIR" is not a valid directory";
	exit 1
fi

# Second step: parse all assembla URLs from the JSON file
while IFS= read -r line; do
	URL=$(echo $line | cut -d \" -f 10)
	ALLREPOS+=($URL)
	PROJECTS+=("$(echo $URL | cut -d \/ -f 4 | cut -d \. -f 1)")
	REPOS+=("$(echo $URL | cut -d \/ -f 4 | cut -d \. -f 2)")
done <<< "$(cat composer.json | JSON.sh -b | egrep '\"url\"\]')"

if [ $VERBOSITY -eq 1 ] ; then
	echo
	echo "${#ALLREPOS[@]} repositories to be parsed." 
fi

# Second step: check whether shared repos are cloned. 
# If they are, ok. If not, either warn or automatically clone.
numrepos="${#ALLREPOS[@]}"
idx=0
cd $PROJECT_DIR
while [ "$idx" -lt "$numrepos" ] ; do
	if [ ! -d ${PROJECTS[$idx]} ] ; then
		echo -e "Creating project directory  \033[32m${PROJECTS[$idx]}\033[0m."
		mkdir ${PROJECTS[$idx]}
	fi

	cd  ${PROJECTS[$idx]}
	if [ ! -d ${REPOS[$idx]} ] ; then
		echo -e "Creating repository directory  \033[32m${REPOS[$idx]}\033[0m."
		mkdir  ${REPOS[$idx]}
		# @TODO Git clone 
		echo -e "Cloning new repository \033[33m${ALLREPOS[$idx]}\033[0m."
		git clone ${ALLREPOS[$idx]} ${REPOS[$idx]}
	else
		if [ $VERBOSITY -eq 1 ] ; then
			echo -e "Repository \033[1m${REPOS[$idx]}\033[0m found."
		fi
	fi

	cd ..
	let "idx=$idx+1"
	echo `pwd`
done
# Third step: check whether actually symlinked.
# If not, either give a warning or force new symlinks.

# (...)

# profit
