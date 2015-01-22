#!/bin/bash

# Read a composer.json file, parse the dependencies and create correct symlinks in the current project folder
# Obviously, this file needs to be run from a Joomla! project root directory. There MUST be a composer.json file.
# See https://github.com/derjoachim/moyo-git-tools for the most recent version

# Variables. Please tweak as necessary

PROJECT_DIR=/var/www
WD=`pwd` # @TODO: Make this more idiot proof.
VERBOSITY=0
ALLREPOS=()
PROJECTS=()
REPOS=()
FLUSH_ALL_SYMLINKS=0
FORCE_ALL=0
PKG_TYPES=(component components libraries media modules plugin plugins)
SUBDIR_TYPES=(components media modules)
FLUSH_SUBDIRS=(administrator components libraries media modules plugins)

#
# Setting parameters.
#
while getopts dfhv opt
do
    case "$opt" in
		d) echo "--- Flush all symlinks ---";FLUSH_ALL_SYMLINKS=1;;
		f) echo "--- Force all enabled ---";FORCE_ALL=1;;
    	h)  
		echo "This command will parse the composer.json file and automatically create the correct symlinks if possible."
		echo
	  	echo "d : Removes all symlinks prior to parsing the composer.json file."
		echo "f : Uses the Force, Luke. All links will be forced, thus overwriting earlier links, files or directories. Use with care."
	  	echo "h : Print this help message."
		echo "v : Be more verbose by showing a message for each subdirectory"
		exit 0;;
		v) echo "--- Verbosity mode on. You asked for it. ---";VERBOSITY=1;;
    	\?) echo >&2 "usage: $0 [-d] [-f] [-h] [-v]";exit 1;;
	esac
done

shift `expr $OPTIND - 1`

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
#
# Autosymlink function
# @param $1 SRC file
# @param $2 DEST file
# Tries to determine whether a symlink file is to be created. It'll do so if necessary. If not, it'll just exit.
symlinker() {
	local src=$1
	local dest=$2

	# First, try to force deletion of existing symlinks, files or directories
	if [ $FORCE_ALL -eq 1 ] ; then
		if [ -d "$dest" ] ; then
			debugln "Removing destination directory $dest"
			rm -rf $dest
		elif [ -L "$dest" ] ; then
			debugln "Removing symlink $dest"
			rm -f $dest
		elif [ -f "$dest" ] ; then
			debugln "Removing regular file $dest"
			rm -f $dest
		fi
	fi
	if [[ -d $src  && ! -L $dest ]] ; then
		# If SRC is a directory...
		if [ -d "$dest" ] ; then
			# Destination is a directory, thus is part of the main project. A warning should be given, because the developer is possibly working in the wrong repository.
			echo -e "\033[31mWarning\033[0m: The subdirectory $dest appears to be part of the main project. Please fix manually."
		elif [ ! -L  "$dest" ] ; then
			debugln "Trying to symlink directory $src to $dest"
			ln -sf "$src" "$dest"
		fi
	elif [[ -f $src && ! -L $dest ]] ; then
		# If SRC is a file...
		if [ -f "$dest" ] ; then
			echo -e "\033[31mWarning\033[0m: The file $dest appears to be part of the main project. Please fix manually."
		elif [ ! -L "$dest" ] ; then
			debugln "Trying to symlink file $src to $dest"
			ln -sf "$src" "$dest"
		fi
	fi
}

#
# #7: Within installable Joomla packages, certain package types contain a media subdirectory. Make sure that these are properly symlinked as well
# Note that this is only necessary for properly packaged repositories! @TODO: Refactor! Probably not needed as a function anymore.

lnmedia() {
	local path=$1
	local dirname="$(basename "${path}")"
	if [ -d "$path/media/$dirname" ]; then
		symlinker "$path/media/$dirname" "$WD/media/$dirname"
	fi
}

# #7-ish. Within a package, it is possible, but not obligatory to iterate through components. This function links components.
lncomponent() {
	local comppath=$1

	# /administrator/components
	for path in $comppath/administrator/components/* ; do 
		[ -d "${path}" ] || continue

		dirname="$(basename "${path}")"
		symlinker "$comppath/administrator/components/$dirname" "$WD/administrator/components/$dirname"
	done;

	# /media
	for path in $comppath/media/* ; do
		dirname="$(basename "${path}")"
		symlinker "$comppath/media/$dirname" "$WD/media/$dirname"
	done;
	
	# /components
	for path in $comppath/components/* ; do 
		[ -d "${path}" ] || continue
		dirname="$(basename "${path}")"
		symlinker "$comppath/components/$dirname" "$WD/components/$dirname"
	done;
}

#
# End function declarations
#

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
if [ ! -d ./libraries/joomla ] ; then
	echo -e "You are not in a joomla project. Therefore, this script will be useless."
	exit 1
fi

# 4: is the project_dir configured correctly? 
if [[ ! -d $PROJECT_DIR ]] ; then
	echo $PROJECT_DIR" is not a valid directory";
	exit 1
fi

# Second step: parse all assembla URLs from the JSON file
while IFS= read -r line; do
	# Old style composer.json: /source/type = git
	URL=$(echo $line | cut -d \" -f 10)
	if [ "$URL" = "" ] ; then
		# New style composer.json: type = vcs
		URL=$(echo $line | cut -d \" -f 6)
	fi
	ALLREPOS+=($URL)
	GITHOST="$(echo $URL | cut -d \/ -f 3)"
	PROJECTS+=("$(echo $URL | cut -d \/ -f 4 | cut -d \. -f 1)")
	case $GITHOST in
		"git.assembla.com")
			# https://git.assembla.com/moyo-content.cloudinary.git -> ok
			REPOS+=("$(echo $URL | cut -d \/ -f 4 | cut -d \. -f 2)")
			;;
		"github.com")
			# https://github.com/cta-int/terms.git ->  ok
			REPOS+=("$(echo $URL | cut -d \/ -f 5 | cut -d \. -f 1)")
			;;
		*)
			echo "\033[1mZoinks\033[0m! $GITHOST is not supported"
			;;
	esac;
done <<< "$(cat composer.json | JSON.sh -b | egrep '\"url\"\]')"

debugln  "${#ALLREPOS[@]} repositories to be parsed."

# Third step: check whether shared repos are cloned. 
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
		echo -e "Cloning new repository \033[33m${ALLREPOS[$idx]}\033[0m into \033[33m${REPOS[$idx]}\033[0m."
		git clone ${ALLREPOS[$idx]} ${REPOS[$idx]}
	else
		debugln "Repository \033[1m${REPOS[$idx]}\033[0m found."
	fi
	#@TODO Automatic checkout of desired branch? Worth a discussion

	cd ..
	let "idx=$idx+1"
done

# Forth step: Optionally flush all symlinks. Also, find and remove any dead symlinks
cd $WD
if [ $FLUSH_ALL_SYMLINKS -eq 1 ] ; then
	# Iterate through all relevant subdirectories
	for subdir in ${FLUSH_SUBDIRS[@]} ; do
		debugln "Flushing subdirectory $WD/$subdir"
		cd $WD/$subdir

		find . -type l -delete
	done
	# Find and remove symlinks within said subdirectories
fi

debugln "Finding dead symlinks."
find . -type l -exec test ! -e {} \; -delete

# Fifth step: check whether actually symlinked.
# If not, either give a warning or force new symlinks.
idx=0
while [ "$idx" -lt "$numrepos" ] ; do
	SRCDIR="$PROJECT_DIR/${PROJECTS[$idx]}/${REPOS[$idx]}"
	if [ -d $PROJECT_DIR/${PROJECTS[$idx]}/${REPOS[$idx]}/packages ] ; then
		SRCDIR+="/packages"
		echo -e "${PROJECTS[$idx]} - \033[32m${REPOS[$idx]}\033[0m \033[33mPackages subdirectory found\033[0m."
		for pkgtype in ${PKG_TYPES[@]} ; do
			if [ -d "$SRCDIR/$pkgtype" ] ; then
				case $pkgtype in
					"component")
						debugln "\033[1mSingular component\033[0m found in $SRCDIR/$pkgtype/"
						lncomponent $SRCDIR/$pkgtype
						;;
					"components")
						debugln "\033[1mMultiple components\033[0m found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/*; do
							[ -d "${path}" ] || continue
							debugln "Trying to create symlinks for component within $path"
							lncomponent $path
						done;
						;;
					"libraries")
						debugln "\033[1mLibraries\033[0m found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
							lnmedia $path
							symlinker "$SRCDIR/$pkgtype/$dirname" "$WD/$pkgtype/$dirname"
						done;
						if [ -f "$SRCDIR/$pkgtype/pkg_${REPOS[$idx]}.xml" ] ; then
							symlinker "$SRCDIR/$pkgtype/pkg_${REPOS[$idx]}.xml" "$WD/administrator/manifests/libraries/${REPOS[$idx]}.xml"
						fi
						;;
					"media")
						debugln "\033[1mMedia\033[0m found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
							symlinker "$SRCDIR/$pkgtype/$dirname" "$WD/$pkgtype/$dirname"
						done;
						;;
					"modules")
						debugln "\033[1mModules\033[0m found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
							lnmedia $path
							symlinker "$SRCDIR/$pkgtype/$dirname" "$WD/modules/$dirname"
						done
						;;
					"plugin")
						debugln "\033[1mPlugin\033[0m found in $SRCDIR/$pkgtype/"
						if [ -f "$SRCDIR/$pkgtype/${REPOS[$idx]}.xml" ] ; then
							plugintype=`sed -n '/group/s/\(.*group=\)\(.*\)/\2/p' $SRCDIR/$pkgtype/${REPOS[$idx]}.xml|awk -F\" '{print $2}'`
							symlinker "$SRCDIR/$pkgtype" "$WD/plugins/$plugintype/${REPOS[$idx]}"
						fi
						;;
					"plugins")
						debugln "\033[1mPlugins new style \033[0m found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
							if [ -f "$SRCDIR/$pkgtype/$dirname/${dirname}.xml" ] ; then
								plugintype=`sed -n '/group/s/\(.*group=\)\(.*\)/\2/p' $SRCDIR/$pkgtype/$dirname/${dirname}.xml|awk -F\" '{print $2}'`
								symlinker "$SRCDIR/$pkgtype/$dirname" "$WD/plugins/$plugintype/$dirname"
							fi
						done
						;;
					*)
						echo "\033[1mZoinks\033[0m! I hope that's just Scoob behind me (hint. It isn't)"
						;;
				esac;
			fi
		done
		# Try to simlink pkg_blah.xml
		if [ -f  "$SRCDIR/pkg_${REPOS[$idx]}.xml" ] ; then
			symlinker "$SRCDIR/pkg_${REPOS[$idx]}.xml" "$WD/administrator/manifests/packages/pkg_${REPOS[$idx]}.xml"
		fi
	else
		# We're currently in a single component or module. As of version 1.1, this is prohibited. An error is to be given and exit code 1 (error) is to be returned.
		echo -e "Error in repository: ${PROJECTS[$idx]} - \033[32m${REPOS[$idx]}\033[0m \033[33mComponent not in package.\033[0m."
		exit 1
	fi
	debugln "---"

	let "idx=$idx+1"
done

echo -e "\033[36mDone\033[0m! All symlinks appear to be in place."
exit 0;
