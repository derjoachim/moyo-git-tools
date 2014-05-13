#!/bin/bash

# Read a composer.json file, parse the dependencies and create correct symlinks in the current project folder
# Obviously, this file needs to be run from a web project root directory. There MUST be a composer.json file.
# This currently only works for Joomla! projects.

# Variables. Please tweak as necessary
PROJECT_DIR=/var/www
WD=`pwd` # @TODO: Make this more idiot proof.
VERBOSITY=0
ALLREPOS=()
PROJECTS=()
REPOS=()
FORCE_ALL=0
PKG_TYPES=(component libraries media modules plugin)
SUBDIR_TYPES=(components media modules)
#
# Setting parameters.
#
while getopts fhv opt
do
    case "$opt" in
		f) echo "--- Force all enabled ---";FORCE_ALL=1;;
    	h)  
		echo "This command will parse the composer.json file and automatically create the correct symlinks if possible."
		echo
		echo "f : Uses the Force, Luke. All links will be forced, thus overwriting earlier links, files or directories. Use with care."
	  	echo "h : Print this help message."
		echo "v : Be more verbose by showing a message for each subdirectory"
		exit 0;;
		v) echo "--- Verbosity mode on. You asked for it. ---";VERBOSITY=1;;
    	\?) echo >&2 "usage: $0 [-f] [-h] [-v]";exit 1;;
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
		if [ -d $dest ] ; then
			debugln "Removing destination directory $dest"
			rm -rf $dest
		elif [ -L $dest ] ; then
			debugln "Removing symlink $dest"
			rm -f $dest
		elif [ -f $dest ] ; then
			debugln "Removing regular file $dest"
			rm -f $dest
		fi
	fi
	if [[ -d $src  && ! -L $dest ]] ; then
		# If SRC is a directory...
		if [ -d $dest ] ; then
			# Destination is a directory, thus is part of the main project. A warning should be given, because the developer is possibly working in the wrong repository.
			echo -e "\033[31mWarning\033[0m: The subdirectory $dest appears to be part of the main project. Please fix manually."
		elif [ ! -L  $dest ] ; then
			debugln "Trying to symlink directory $src to $dest"
			ln -sf "$src" "$dest"
		fi
	elif [[ -f $src && ! -L $dest ]] ; then
		# If SRC is a file...
		if [ -f $dest ] ; then
			echo -e "\033[31mWarning\033[0m: The file $dest appears to be part of the main project. Please fix manually."
		elif [ ! -L $dest ] ; then
			debugln "Trying to symlink file $src to $dest"
			ln -sf "$src" "$dest"
		fi
	fi
}

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
	URL=$(echo $line | cut -d \" -f 10)
	ALLREPOS+=($URL)
	PROJECTS+=("$(echo $URL | cut -d \/ -f 4 | cut -d \. -f 1)")
	REPOS+=("$(echo $URL | cut -d \/ -f 4 | cut -d \. -f 2)")
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
		echo -e "Cloning new repository \033[33m${ALLREPOS[$idx]}\033[0m."
		git clone ${ALLREPOS[$idx]} ${REPOS[$idx]}
	else
		debugln "Repository \033[1m${REPOS[$idx]}\033[0m found."
	fi

	cd ..
	let "idx=$idx+1"
done

# Forth step: check whether actually symlinked.
# If not, either give a warning or force new symlinks.
cd $WD
idx=0
while [ "$idx" -lt "$numrepos" ] ; do
	# Sometimes a repo is a package (e.g. a module and a component)
	SRCDIR="$PROJECT_DIR/${PROJECTS[$idx]}/${REPOS[$idx]}"

	if [ -d $PROJECT_DIR/${PROJECTS[$idx]}/${REPOS[$idx]}/packages ] ; then
		SRCDIR+="/packages"
		echo -e "${PROJECTS[$idx]} - \033[32m${REPOS[$idx]}\033[0m \033[33mPackages subdirectory found\033[0m."
		for pkgtype in ${PKG_TYPES[@]} ; do
			if [ -d "$SRCDIR/$pkgtype" ] ; then
				case $pkgtype in
					"component")
						debugln "\033[1mComponent\033[0m found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/administrator/components/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
							symlinker "$SRCDIR/$pkgtype/administrator/components/$dirname" "$WD/administrator/components/$dirname"

							# Do not forget the .xml files
							if [ -f  "$SRCDIR/$pkgtype/$dirname.xml" ] ; then
								symlinker "$SRCDIR/$pkgtype/$dirname.xml" "$WD/administrator/components/$dirname/$dirname.xml"
							fi
						done;
						for path in $SRCDIR/$pkgtype/components/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
							symlinker "$SRCDIR/$pkgtype/components/$dirname" "$WD/components/$dirname"
						done;
						if [ -f "$SRCDIR/$pkgtype/${REPOS[$idx]}.xml" ] ; then
							symlinker "$SRCDIR/$pkgtype/${REPOS[$idx]}.xml" "$WD/administrator/components/com_${REPOS[$idx]}/${REPOS[$idx]}.xml"
						fi
						;;
					"libraries")
						debugln "\033[1mLibraries\033[0m found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
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
		# We're currently in a single component or module. Do the symlink thingy
		# Not very DRY, but it'll do for the moment.
		echo -e "${PROJECTS[$idx]} - \033[32m${REPOS[$idx]}\033[0m \033[33mComponent not in package.\033[0m."

		# administrator/components
		if [ -d "$SRCDIR/administrator/components" ] ; then
			debugln "\033[1mAdministrator\033[0m found in $SRCDIR/"
			for path in $SRCDIR/administrator/components/* ; do 
				[ -d "${path}" ] || continue
				dirname="$(basename "${path}")"
				symlinker "$SRCDIR/administrator/components/$dirname" "$WD/administrator/components/$dirname"

				# Do not forget the .xml files
				if [ -f  "$SRCDIR/$dirname.xml" ] ; then
					symlinker "$SRCDIR/$dirname.xml" "$WD/administrator/components/$dirname/$dirname.xml"
				fi
			done
		fi
		# The rest is somewhat easier
		for pkgtype in ${SUBDIR_TYPES[@]} ; do
			if [ -d "$SRCDIR/$pkgtype" ] ; then
				debugln "\033[1m$pkgtype\033[0m found in $SRCDIR/$pkgtype/"
				for path in $SRCDIR/$pkgtype/* ; do 
					[ -d "${path}" ] || continue
					dirname="$(basename "${path}")"
					symlinker "$SRCDIR/$pkgtype/$dirname" "$WD/$pkgtype/$dirname"
				done
			fi
		done
	fi
	debugln "---"

	let "idx=$idx+1"
done

echo -e "\033[36mDone\033[0m! All symlinks appear to be in place."
exit 0;
