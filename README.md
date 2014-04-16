Moyo-git-tools
==============

Git repository tools
--------------------

Moyo Web Architects currently works with shared git repositories, i.e. repositories that are shared amoung projects. To facilitate this workflow, a number of scripts has been written, some of which are currently being shared.

The `mass_update.sh` script enters a local subdirectory that has all the shared repositories and iterates through the subdirectories. Per subdirectory, it gives a status (and later) the option to perform certain actions within the script, like pulling.

Early Nooku repository scripts
------------------------------

A number of older projects use 0.7 and 12.X versions of the [Nooku Server](http://nooku.assembla.net) CMS. Since back in the day, these versions were in heavy development (and we like to swim with the sharks), I wrote a set of tools that created a local dump of the (then) SVN repo, and synced (or installed) the desired versoin.
See [this post](http://moyoweb.nl/index.php/blog/2-nooku-news/15-how-to-sync-your-project-code-with-the-nooku-server-repository.html) for more information.

The `updatens.sh` is used to update a certain project. The default behavior is to merely pull the latest revision, but you can specify revisions or even tags. Its sister script `preinstall_ns.sh enables the developer to start a new Nooku Server project, again while being to distinguish among revisions and tags.

Disclaimer
----------
These scripts have been released under the GPL3 license. Use and reuse at will. A word of warning though: use these scripts at your own risk. If you bork your repo, that's on you.

Kind regards,
Joachim van de Haterd
