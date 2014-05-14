#/bin/bash

# Joachim van de Haterd - Moyo Web Architects
#
# Syncs a subdirectory with development code to a subdirectory with staging code.
# This is needed for two reasons:
# 1 The workflow for CTA-related projects is to commit to a iBuildings-hosted git repo.
# 	using Capistrano, thus invalidating our workflow. Therefore, branching is out of 
# 	the question.
# 2	We use repositories that are being shared among projects. Instead of using modules,
#	the proper subdirectories are being symlinked. The staging branch contains all code
#	for the main projects and the shared projects combined, and in the case of CTA 
# 	projects the entire CMS code base. :-X
#
# This script assumes that a project directory contains either a development directory
# and a staging directory

SRC="development"
DEST="staging"

RSYNCOPT="-aLrtv"
DRY_RUN=0
KEEP_ORPHANS=0

while getopts hnk opt
do
    case "$opt" in
    	h)  
		echo "Sync development and staging subdirectories. Why no branches? Because fuck you!"
		echo
	  	echo "h : Print this helpful message."
	  	echo "n : Chicken mode. Dry-run is activated, no files are being overwritten."
	  	echo "k : Keep files that would be deleted."
		exit 0;;
		n) echo "--- Chicken mode on. No files are being overwritten. ---";DRY_RUN=1;;
		k) echo "--- Orphan rescue mode on. No orphaned files are being deleted ---";KEEP_ORPHANS=1;;
    	\?) echo >&2 "usage: $0 [-h] [-n] [-k]";exit 1;;
	esac
done

shift `expr $OPTIND - 1`

if [ ! -d $SRC ] ; then
	echo "Source directory $SRC is not a valid subdirectory"
	exit 1
fi
if [ ! -d $DEST ] ; then
	echo "Destination directory $DEST is not a valid subdirectory"
	exit 1
fi

if [ $DRY_RUN -eq 1 ]; then
	RSYNCOPT+="n"
fi
if [ $KEEP_ORPHANS -eq 0 ] ; then
	RSYNCOPT+=" --delete"
fi

rsync $RSYNCOPT --delete --exclude='.git' --exclude='/.gitignore' --exclude='/copy.sh' --exclude='/symlinker.sh' --exclude='/configuration.php' --exclude='/composer.lock' --exclude='/administrator/cache' --exclude='/joomlatools-files' --exclude='/cache' --exclude='/logs' --exclude='/images' --exclude='/tmp' --exclude='/vendor' $SRC/ $DEST/
