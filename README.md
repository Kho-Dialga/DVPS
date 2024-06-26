# Dialga's Void Post-install Script (DVPS)
# Forked from [LARBS](https://github.com/LukeSmithxyz/LARBS)

## Installation:

On a Void or Arch based distribution as root, run the following:

```
xbps-install curl || pacman -S
curl https://raw.githubusercontent.com/Kho-Dialga/DVPS/master/dvps.sh | sh
```

That's it.

## What is DVPS?

DVPS is a script that autoinstalls and autoconfigures a fully-functioning
and minimal terminal-and-vim-based Void/Arch Linux environment.

DVPS can be run on a fresh install of Void Linux, and provides you
with a fully configured diving-board for work or more customization.

## Customization

By default, DVPS uses the programs [here in progs.csv](progs.csv) and installs
[my dotfiles repo (configs) here](https://github.com/Kho-Dialga/configs),
but you can easily change this by either modifying the default variables at the
beginning of the script or giving the script one of these options:

- `-r`: custom dotfiles repository (URL)
- `-p`: custom programs list/dependencies (local file or URL)
- `-w`: custom window manager list (local file or URL)

### The `progs.csv` lists

DVPS will parse the given programs list and install all given programs. Note
that the programs file must be a three column `.csv`.

The first column is a "tag" that determines how the program is installed, ""
(blank) for the main repository or `G` if the program is a
git repository that is meant to be `make && sudo make install`ed.

The second column is the name of the program in the repository, or the link to
the git repository, and the third column is a description (should be a verb
phrase) that describes the program. During installation, DVPS will print out
this information in a grammatical sentence. It also doubles as documentation
for people who read the CSV and want to install my dotfiles manually.

Depending on your own build, you may want to tactically order the programs in
your programs file. DVPS will install from the top to the bottom.

If you include commas in your program descriptions, be sure to include double
quotes around the whole description to ensure correct parsing.

### The `wm.csv` list

This is similar to the `progs.csv` list mentioned above, but instead there
need to be 6 colums instead of 3, hopefully I can reduce the number of columns.

The first column, just like `progs.csv`, has a "tag" that determines how the
window manager will be installed.

The second column is the name of the window manager, this is what will be
displayed in the menu.

The third column is the name of the package of the window manager, or the link
to the git repo if you're compiling your wm through `git` and `make`.

The forth column is any additional packages needed for the window manager. Some
window managers will have this column empty, but others such as `bspwm` and `xmonad`
need other packages to function properly.

The fifth column is the command used to launch the window manager. Since some
window managers have a different launch command than their package name, such as
`i3-gaps` needing the command `i3` in order to be launched, this field is needed.

And finally, the sixth column, is just an addtional argument that `dialog` needs
to create a menu. Feel free to put whatever you want in here!

### The script itself

The script is extensively divided into functions for easier readability and
trouble-shooting. Most everything should be self-explanatory.

The main work is done by the `installationloop` function, which iterates
through the programs file and determines based on the tag of each program,
which commands to run to install it. You can easily add new methods of
installations and tags as well.