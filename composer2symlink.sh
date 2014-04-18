#!/bin/bash

# Read a composer.json file, parse the dependencies and create correct symlinks in the current project folder
# Obviously, this file needs to be run from a web project root directory. There MUST be a composer.json file.
# 

# Variables. Please tweak as necessary
PROJECT_DIR=/var/www
WD=`pwd`
VERBOSITY=0
ALLREPOS=()
PROJECTS=()
REPOS=()
FORCE_ALL=0
PKG_TYPES=(component libraries media modules plugins)

# 
# Function declarations
#
# Autosymlink function
# @param $1 SRC file
# @param $2 DEST file
# Tries to determine whether a symlink file is to be created. It'll do so if necessary. If not, it'll just exit.
symlinker() {
	local src=$1
	local dest=$2

	if [[ -d $src  && ! -L $dest ]] ; then
		# If SRC is a directory
		if [[ ! -d $dest || $FORCE_ALL -eq 1 ]] ; then
			echo -e "Trying to symlink directory $src to $dest"
			ln -sf $src $dest
		fi
	elif [[ -f $src && ! -L $dest && ! -L $dest ]] ; then
		# If SRC is a file
		if [[ ! -f $dest || $FORCE_ALL -eq 1 ]] ; then
			echo -e  "Trying to symlink file $src to $dest"
			ln -sfn $src $dest
		fi
	fi
}

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

if [ $VERBOSITY -eq 1 ] ; then
	echo
	echo "${#ALLREPOS[@]} repositories to be parsed." 
fi

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
		if [ "$FORCE_CLONING" -eq 1 ] ; then
			echo -e "Cloning new repository \033[33m${ALLREPOS[$idx]}\033[0m."
			git clone ${ALLREPOS[$idx]} ${REPOS[$idx]}
		fi
	else
		if [ $VERBOSITY -eq 1 ] ; then
			echo -e "Repository \033[1m${REPOS[$idx]}\033[0m found."
		fi
	fi

	cd ..
	let "idx=$idx+1"
done

# Forth step: check whether actually symlinked.
# If not, either give a warning or force new symlinks.
cd $WD
idx=0
while [ "$idx" -lt "$numrepos" ] ; do
	# Sometimes a repo is a package (e.g. a module and a component
	SRCDIR="$PROJECT_DIR/${PROJECTS[$idx]}/${REPOS[$idx]}"

	if [ -d $PROJECT_DIR/${PROJECTS[$idx]}/${REPOS[$idx]}/packages ] ; then
		SRCDIR+="/packages"
		echo -e "${PROJECTS[$idx]} - ${REPOS[$idx]} \033[33mPackages subdirectory found\033[0m."
		for pkgtype in ${PKG_TYPES[@]} ; do
			if [ -d "$SRCDIR/$pkgtype" ] ; then
				case $pkgtype in
					"component")
						echo "Component found in $SRCDIR/$pkgtype/"
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
						# This is a loose cannon. Fortunately, the proper checks are in place.
						if [ -f "$SRCDIR/$pkgtype/${REPOS[$idx]}.xml" ] ; then
							symlinker "$SRCDIR/$pkgtype/${REPOS[$idx]}.xml" "$WD/administrator/components/com_${REPOS[$idx]}/${REPOS[$idx]}.xml"
						fi
						;;
					"libraries")
						echo "Libraries found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
							symlinker "$SRCDIR/$pkgtype/$dirname" "$WD/$pkgtype/$dirname"
						done;
						if [ -f "$SRCDIR/$pkgtype/pkg_${REPOS[$idx]}.xml"] ; then
							symlinker "$SRCDIR/$pkgtype/pkg_${REPOS[$idx]}.xml" "$WD/administrator/manifests/libraries/${REPOS[$idx]}.xml"
						fi
						;;
					"media")
						echo "Media found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
							symlinker "$SRCDIR/$pkgtype/$dirname" "$WD/$pkgtype/$dirname"
						done;
						;;
					"modules")
						echo "Modules found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
							symlinker "$SRCDIR/$pkgtype/$dirname" "$WD/modules/$dirname"
						done
						;;
					"plugins")
						echo "Plugins foundin $SRCDIR/$pkgtype/. You're screwed!"
						# @TODO: Read the manifest, determine the plugin type and determine the correct subdirectory to place stuff in.
						# symlinker "$SRCDIR/$pkgtype/$dirname" "$WD/plugins/$plugintype/$dirname
						;;
					*)
						echo "Zoinks! I hope that's just Scoob behind me (hint. It isn't)"
						;;
				esac;
			fi
		done
		# Try to simlink pkg_blah.xml
		if [ -f  "$SRCDIR/pkg_${REPOS[$idx]}.xml" ] ; then
			symlinker "$SRCDIR/pkg_${REPOS[$idx]}.xml" "$WD/administrator/manifests/packages/pkg_${REPOS[$idx]}.xml"
		fi
	else
		# @TODO: We're currently in a single component or module. Do the symlink thingy
		echo "TODO : $PROJECT_DIR/${PROJECTS[$idx]}/${REPOS[$idx]}"
	fi


	let "idx=$idx+1"
done

echo "We done"
exit 0;
