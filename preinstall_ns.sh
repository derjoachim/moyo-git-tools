#!/bin/bash

# A Simple script that exports a SVN snapshot for Nooku server into a new project folder. 
# Afterward, just open the index.php in this folder and do the proper installation.
# Joachim van de Haterd - Moyo Web Architects 20120515
# @PARAMETERS / @OPTIONS
# -b selects the branch
# -p selects the project name.
# -n is the chicken mode. This corresponds to the -n option for rsync.
# -r REVISION updates the chosen branch to revision REVISION. Implies -s
# -t Updates (or downgrades) to TAG.
# Note: this script will only work up to Nooku server versions up to 12.X. Newer versions have been moved to a git repo.
# Also: use at own risk.
if [ $# -eq 0 ] ; then
	echo "Usage: $0 PROJECTNAME -b BRANCH -h -r REVISION -t TAG"
	exit 1
fi

# The source subdirectory contains a Subversion dump
REPOSRC=~/repos/nooku/server
# The destination subdirectory
PRJFOLDER=~/www/$1/

# SVN options
REVISION=0
BRANCHNAME=''
TAGNAME=''

while [ $# -gt 0 ] ; do
	case "$1" in
		-b) BRANCHNAME=$2;echo "You chose branch $2.";shift 2;;
		-h)
			echo "Usage: $0 PROJECTNAME options"
			echo "Options:"
			echo "-b: Selects a non-standard branch. The default value is the trunk"
			echo "-h: prints this helpful message"
			echo "-r: update SVN branch to Revision number"
			echo "-t: use the version with tagname TAG"
			exit 1;;
		-r) echo "Updating to Revision $2"; REVISION=$2; shift 2;;
		-t) echo "Switching to tag $2";TAGNAME=$2;shift 2;;
		*) shift 1;;
	esac
done

if [ "$TAGNAME" != '' ]; then
	REPOSRC="$REPOSRC/tags/$TAGNAME/code/"
elif [ "$BRANCHNAME" != '' ]; then
	REPOSRC="$REPOSRC/branches/$BRANCHNAME/code"
else
	REPOSRC="$REPOSRC/trunk/code"
fi
# 0. Check whether the temporary folder exists.
echo "Check whether the right folders exist."
if [ ! -d "$REPOSRC" ]; then
	echo "Error: the repository or branch $REPOSRC does not exist."
	exit 1
fi
if [ -d "$PRJFOLDER" ]; then
	echo "Error: the project subdirectory $PRJFOLDER already exists. Therefore, I will gracefully exit."
	exit 1
fi

# 1. Export the repo into the temporary folder. 
echo "Export SVN repo $REPOSRC into $PRJFOLDER"
SVNCMD='svn export'

if [ $REVISION -gt 0 ]; then
	SVNCMD="$SVNCMD -r $REVISION"
fi
SVNCMD="$SVNCMD $REPOSRC $PRJFOLDER"

eval $SVNCMD
