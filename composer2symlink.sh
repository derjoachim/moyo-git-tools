#!/bin/bash

# Read a composer.json file, parse the dependencies and create correct symlinks in the current project folder
# Obviously, this file needs to be run from a web project root directory. There MUST be a composer.json file.
# 

# Variables. Please tweak as necessary
PROJECT_DIR=~/www
WD=`pwd`
VERBOSITY=0
ALLREPOS=()
PROJECTS=()
REPOS=()
FORCE_ALL=0
PKG_TYPES=(component libraries media modules plugins)


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
						echo "Component found"
						if [[ -d "$SRCDIR/$pkgtype/administrator/components/com_${REPOS[$idx]}" && ! -L "$WD/administrator/components/com_${REPOS[$idx]}" ]] ; then
							if [[ ! -d "$WD/administrator/components/com_${REPOS[$idx]}" || $FORCE_ALL -eq 1 ]] ; then
								SRC="$SRCDIR/$pkgtype/administrator/components/com_${REPOS[$idx]}"
								DEST="$WD/administrator/components/com_${REPOS[$idx]}"
								echo "Trying to symlink $SRC to $DEST"
								ln -sf $SRC $DEST
							fi
						fi
						if [[ -d "$SRCDIR/$pkgtype/components/com_${REPOS[$idx]}" && ! -L "$WD/components/com_${REPOS[$idx]}" ]] ; then
							if [[ ! -d "$WD/components/com_${REPOS[$idx]}" || $FORCE_ALL -eq 1 ]] ; then
								SRC="$SRCDIR/$pkgtype/components/com_${REPOS[$idx]}"
								DEST="$WD/components/com_${REPOS[$idx]}"
								echo "Trying to symlink $SRC to $DEST"
								ln -sf $SRC $DEST
							fi
						fi

						if [ ! -L "$WD/administrator/components/com_${REPOS[$idx]}.xml" ] ; then
							if [[ ! -f "$WD/administrator/components/com_${REPOS[$idx]}.xml" || $FORCE_ALL -eq 1 ]] ; then
								SRC="$SRCDIR/$pkgtype/com_${REPOS[$idx]}.xml"
								DEST="$WD/administrator/components/com_${REPOS[$idx]}/com_${REPOS[$idx]}.xml"
								echo "Trying to symlink $SRC to $DEST"
								ln -sf $SRC $DEST
							fi
						fi
						if [[ -f "$SRCDIR/$pkgtype/${REPOS[$idx]}.xml" || ! -L "$WD/administrator/components/${REPOS[$idx]}.xml" ]] ; then
							if [[ ! -f "$WD/administrator/components/${REPOS[$idx]}.xml" || $FORCE_ALL -eq 1 ]] ; then
								SRC="$SRCDIR/$pkgtype/${REPOS[$idx]}.xml"
								DEST="$WD/administrator/components/${REPOS[$idx]}/${REPOS[$idx]}.xml"
								echo "Trying to symlink $SRC to $DEST"
								ln -sf $SRC $DEST
							fi
						fi

						;;
					"libraries")
						echo "Libraries found"
						if [[ -d "$SRCDIR/$pkgtype/libraries/${REPOS[$idx]}" && ! -L "$WD/libraries/${REPOS[$idx]}" ]] ; then
							if [[ ! -d "$WD/libraries/${REPOS[$idx]}" || $FORCE_ALL -eq 1 ]] ; then
								SRC="$SRCDIR/$pkgtype/libraries/${REPOS[$idx]}"
								DEST="$WD/libraries/${REPOS[$idx]}"
								echo "Trying to symlink $SRC to $DEST"
								ln -sf $SRC $DEST
							fi
						fi
						if [ ! -L "$WD/administrator/manifests/libraries/${REPOS[$idx]}.xml" ] ; then
							if [[ ! -f "$WD/administrator/manifests/libraries/${REPOS[$idx]}.xml" || $FORCE_ALL -eq 1 ]] ; then
								SRC="$SRCDIR/$pkgtype/pkg_${REPOS[$idx]}.xml"
								DEST="$WD/administrator/manifests/libraries/${REPOS[$idx]}.xml"
								echo "Trying to symlink $SRC to $DEST"
								ln -sf $SRC $DEST
							fi
						fi

						;;
					"media")
						echo "Media found"
						if [[ -d "$SRCDIR/$pkgtype/com_${REPOS[$idx]}" && ! -L "$WD/com_${REPOS[$idx]}" ]] ; then
							if [[ ! -d "$WD/com_${REPOS[$idx]}" || $FORCE_ALL -eq 1 ]] ; then
								SRC="$SRCDIR/$pkgtype/com_${REPOS[$idx]}"
								DEST="$WD/com_${REPOS[$idx]}"
								echo "Trying to symlink $SRC to $DEST"
								ln -sf $SRC $DEST
							fi
						fi
						if [[ -d "$SRCDIR/$pkgtype/mod_${REPOS[$idx]}" && ! -L "$WD/mod_${REPOS[$idx]}" ]] ; then
							if [[ ! -d "$WD/mod_${REPOS[$idx]}" || $FORCE_ALL -eq 1 ]] ; then
								SRC="$SRCDIR/$pkgtype/mod_${REPOS[$idx]}"
								DEST="$WD/mod_${REPOS[$idx]}"
								echo "Trying to symlink $SRC to $DEST"
								ln -sf $SRC $DEST
							fi
						fi
						;;

					"modules")
						echo "Modules found in $SRCDIR/$pkgtype/"
						for path in $SRCDIR/$pkgtype/* ; do 
							[ -d "${path}" ] || continue
							dirname="$(basename "${path}")"
							echo $dirname;
								if [ ! -L "$WD/modules/$dirname" ] ; then
								if [[ ! -d "$WD/modules/$dirname" || $FORCE_ALL -eq 1 ]] ; then
									SRC="$SRCDIR/$pkgtype/$dirname"
									DEST="$WD/modules/$dirname"
									echo "Trying to symlink $SRC to $DEST"
									ln -sf $SRC $DEST
								fi
							fi
						done
						;;
					"plugins")
						echo "Plugins found. You're screwed!"
						# @TODO: Read the manifest, determine the plugin type and determine the correct subdirectory to place stuff in.
						;;
					*)
						echo "Zoinks! I hope that's just Scoob behind me (hint. It isn't)"
						;;
				esac;
			fi
		done
		# Try to simlink pkg_blah.xml
		if [ ! -L "$WD/administrator/manifests/packages/pkg_${REPOS[$idx]}.xml" ] ; then
			if [[ ! -f "$WD/administrator/manifests/packages/pkg_${REPOS[$idx]}.xml" || $FORCE_ALL -eq 1 ]] ; then
				SRC="$SRCDIR/pkg_${REPOS[$idx]}.xml"
				DEST="$WD/administrator/manifests/packages/pkg_${REPOS[$idx]}.xml"
				echo "Trying to symlink $SRC to $DEST"
				ln -sf $SRC $DEST
			fi
		fi
	fi

	# @TODO: We're currently in a single component or module. Do the symlink thingy

	let "idx=$idx+1"
done

echo "We done"
exit 0;
