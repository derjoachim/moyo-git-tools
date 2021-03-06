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

RSYNCOPT="-rvptgoD" # Without symlinks
DRY_RUN=0
KEEP_ORPHANS=0

while getopts d:hnks: opt
do
    case "$opt" in
		d) DEST="$OPTARG";echo "-- Destination override to $DEST --";;
    	h)  
		echo "Sync development and staging subdirectories. Why no branches? Because fuck you!"
		echo
	  	echo "d : Override destination subdirectory."
	  	echo "h : Print this helpful message."
	  	echo "n : Chicken mode. Dry-run is activated, no files are being overwritten."
	  	echo "k : Keep files that would be deleted."
	  	echo "s : Override source subdirectory."
		exit 0;;
		n) echo "--- Chicken mode on. No files are being overwritten. ---";DRY_RUN=1;;
		k) echo "--- Orphan rescue mode on. No orphaned files are being deleted ---";KEEP_ORPHANS=1;;
		s) SRC="$OPTARG";echo "-- Source override to $SRC --";;
    	\?) echo >&2 "usage: $0 [-d destination_dir] [-h] [-n] [-k] [-s src_dir]";exit 1;;
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

# #9 Make sure that staging is in develop branch.
echo "Making sure that $DEST is currently in develop branch..."
cd $DEST
git checkout develop
cd ..

echo "Removing pesky .DS_Store files."
find . -name *.DS_Store -type f -delete

rsync $RSYNCOPT --exclude='.git' --exclude='php_errors.log' --exclude='administrator/php_errors.log' --exclude='/.idea' --exclude='/.gitignore' --exclude='/copy.sh' --exclude='/symlinker.sh' --exclude='/configuration.php' --exclude='/composer.lock' --exclude='/administrator/cache' --exclude='/joomlatools-files' --exclude='/cache' --exclude='/logs' --exclude='/images' --exclude='/tmp' --exclude='/vendor' $SRC/ $DEST/
