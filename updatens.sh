#!/bin/bash

# A Simple script that exports a Nooku Server branch, and syncs it to an existing Project.
# Joachim van de Haterd - Moyo Web Architects 20120514
# @PARAMETERS / @OPTIONS
# -b selects the branch
# -p selects the project name.
# -n is the chicken mode. This corresponds to the -n option for rsync.
# -r REVISION updates the chosen branch to revision REVISION. Implies -s
# -t Updates (or downgrades) to TAG.
if [ $# -eq 0 ] ; then
	echo "Usage: $0 PROJECTNAME -b BRANCH -h -n -r REVISION -t TAG"
	exit 1
fi

REPOSRC=~/repos/nooku/server
TMPFOLDER=~/Upload/nookuservertemp/
PRJFOLDER=~/Projecten/$1/

# SVN options
REVISION=0
BRANCHNAME=''
TAGNAME=''

#Rsync options
EXCLUDES=( '.gitignore' 'sites/' 'installation/' 'templates/' 'tmp/' 'cache/')
RSYNCOPTS='-av'

while [ $# -gt 0 ] ; do
	case "$1" in
		-b) BRANCHNAME=$2;echo "You chose branch $2.";shift 2;;
		-h)
			echo "Usage: $0 PROJECTNAME options"
			echo "Options:"
			echo "-b: Selects a non-standard branch. The default value is the trunk"
			echo "-h: prints this helpful message"
			echo "-n: chicken mode. Does not actually overwrite anything"
			echo "-r: update SVN branch to Revision number"
			echo "-t: use the version with tagname TAG"
			exit 1;;
		-n) echo "Chicken mode Activated. No data will actually be overwritten.";RSYNCOPTS='-avn'; shift 1;;
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
if [ -d "$TMPFOLDER" ]; then 
	echo "$TMPFOLDER exists. Will gracefully exit."
	exit 0
fi
if [ ! -d "$REPOSRC" ]; then
	echo "Error: the repository or branch $REPOSRC does not exist."
	exit 0
fi
if [ ! -d "$PRJFOLDER" ]; then
	echo "Error: the project subdirectory $PRJFOLDER does not exist."
	exit 0
fi

# 1. Export the repo into the temporary folder. 
echo "Export SVN repo $REPOSRC into $TMPFOLDER"
SVNCMD='svn export'

if [ $REVISION -gt 0 ]; then
	SVNCMD="$SVNCMD -r $REVISION"
fi
SVNCMD="$SVNCMD $REPOSRC $TMPFOLDER"
eval $SVNCMD
# 2. Synchronize the TMPFOLDER into your project folder. Please note that this will override any core hacks. 
echo "Synchronize trunk with $PRJFOLDER"

RSYNCCMD="rsync "$RSYNCOPTS
for EXCL in "${EXCLUDES[@]}"
do
	RSYNCCMD=$RSYNCCMD" --exclude='"$EXCL"'" 
done
RSYNCCMD=$RSYNCCMD" "$TMPFOLDER" "$PRJFOLDER
eval $RSYNCCMD

# 3. Remove the temporary folder
echo "Remove $TMPFOLDER"
rm -rf $TMPFOLDER
