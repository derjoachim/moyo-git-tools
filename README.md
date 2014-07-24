# Moyo-git-tools

## Git repository tools

Moyo Web Architects currently works with shared git repositories, i.e. repositories that are shared among projects. To
facilitate this workflow, a number of scripts has been written, some of which are currently being shared. This collection
of shell scripts is written as a complement to composer. Since our developers are working in several shared repositories
simultaneously within their projects, symlinks to the project subdirectory have to be created.

Obviously, for staging and production environments, composer is being used.

### mass_update.sh

The `mass_update.sh` script enters a local subdirectory that has all the shared repositories and iterates through the
subdirectories. Within each subdirectory, a check is done for local changes. Optionally, the desired branch is being
checked out and a pull is done for the subdirectory. The user can choose not to pull anything, but as of version 1.2,
automatic pulling is the default behavior.

### jsymlinker.sh

This script is intended to work solely within Joomla! projects. The `jsymlinker.sh` script parses a composer.json file.
It retrieves all required assembla repositories, clones them if necessary and adds symlinks within the Joomla! project
directory structure. You can optionally force symlinks (and overwrite your current content). Another option is flushing
existing symlinks first. This is commonly needed when code is being moved or removed.

# Early Nooku repository scripts

A number of older projects use 0.7 and 12.X versions of the [Nooku Server](http://nooku.assembla.com) CMS. Since back in
the day, these versions were in heavy development (and we like to swim with the sharks), I wrote a set of tools that
created a local dump of the (then) SVN repo, and synced (or installed) the desired version.
See [this post](http://moyoweb.nl/en/blog/2012-08-02/how-to-sync-your-project-code-with-the-nooku-server-repository.html)
for more information.

The `updatens.sh` is used to update a certain project. The default behavior is to merely pull the latest revision,
but you can specify revisions or even tags. Its sister script `preinstall_ns.sh` enables the developer to start a new
Nooku Server project, again while being to distinguish among revisions and tags.

# Changelog

**1.0.0** Initial version. Rudimentary support for Joomla package structure (e.g. 1 component and 1 plugin) .

**1.1.0** Better support for Joomla package structure. A package can now contain multiple components, plugins and modules.
Also, media folder are being symlinked from the proper positions.

**1.2.0** Support for branching in the mass pull script.

# Notes

* The bash scripts currently *only* work within a MacOSX environment. Other `*BSD environments may be supported, but
they were not tested. When you run the scripts in a Linux environment, you may probably get some nasty errors.
* If you choose to use the `jsymlinker.sh` script, make sure that the symlinks are readable by your web server. MAMP
users will not notice anything, but virtual machines must be able to reach the destination directories.

# Disclaimer

These scripts have been released under the GPL3 license. Use and reuse at will. A word of warning though: use these
scripts at your own risk. If you bork your repo, that's on you.

Kind regards,

Joachim van de Haterd
