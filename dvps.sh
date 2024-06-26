
# Dialga's Void Post-install Script (DVPS)
# by Kho-Dialga <ivandashenyou@gmail.com>
# Forked from Luke Smith's LARBS
# License: GNU GPLv3

### OPTIONS AND VARIABLES ###

while getopts ":w:r:b:p:h" o; do case "${o}" in
	h) printf "Optional arguments for custom use:\\n  -r: Dotfiles repository (local file or url)\\n  -p: Dependencies and programs csv (local file or url)\\n  -a: AUR helper (must have pacman-like syntax)\\n  -w: Select the window manager csv (local file or url)\\n  -h: Show this message\\n" && exit 1 ;;
	r) dotfilesrepo=${OPTARG} && git ls-remote "$dotfilesrepo" || exit 1 ;;
	b) repobranch=${OPTARG} ;;
	p) progsfile=${OPTARG} ;;
	w) wmsfile=${OPTARG} ;;
	*) printf "Invalid option: -%s\\n" "$OPTARG" && exit 1 ;;
esac done

[ -z "$dotfilesrepo" ] && dotfilesrepo="https://github.com/Kho-Dialga/configs.git"
[ -z "$progsfile" ] && progsfile="https://raw.githubusercontent.com/Kho-Dialga/DVPS/master/progs.csv"
[ -z "$repobranch" ] && repobranch="master"
[ -z "$wmsfile" ] && wmsfile="https://raw.githubusercontent.com/Kho-Dialga/DVPS/master/wm.csv"
[ -z "$repobranch" ] && repobranch="master"

ANSWER=$(mktemp -t dvps-XXXXXXXX || exit 1)

CONF_FILE=/tmp/dvps.conf
if [ ! -f $CONF_FILE ]; then
    touch -f $CONF_FILE
fi
### FUNCTIONS ###

distro=$(cat /etc/issue | awk '{print $1}')

setvar(){
	[ $distro = Arch ] && archvar
	[ $distro = Void ] && voidvar
}
archvar(){
	export installcmd='pacman --noconfirm --needed -S'
	export progsfile="https://raw.githubusercontent.com/Kho-Dialga/DVPS/master/progs/arch.csv"
	export localefile=/etc/locale.gen
	export updatecmd='pacman -Sy'
	export aurhelper=paru
}

voidvar(){
	export installcmd='xbps-install -y'
	export progsfile="https://raw.githubusercontent.com/Kho-Dialga/DVPS/master/progs/void.csv"
	export localefile=/etc/default/libc-locales
	export updatecmd='xbps-install -Sy'
	mkdir -p /etc/xbps.d/ && echo "repository=https://gitlab.com/Kho-Dialga/dialga-void-repo/-/raw/master/current" > /etc/xbps.d/99-dialga-repo.conf
}

refreshrepo(){
	case "$(readlink -f /sbin/init)" in
	*systemd*)
		pacman --noconfirm -S archlinux-keyring >/dev/null 2>&1
		;;
	*)
		if ! grep -q "^\[universe\]" /etc/pacman.conf; then
			echo "[universe]
Server = https://universe.artixlinux.org/\$arch
Server = https://mirror1.artixlinux.org/universe/\$arch
Server = https://mirror.pascalpuffke.de/artix-universe/\$arch
Server = https://artixlinux.qontinuum.space/artixlinux/universe/os/\$arch
Server = https://mirror1.cl.netactuate.com/artix/universe/\$arch
Server = https://ftp.crifo.org/artix-universe/" >>/etc/pacman.conf
			pacman -Sy --noconfirm >/dev/null 2>&1
		fi
		pacman --noconfirm --needed -S \
			artix-keyring artix-archlinux-support >/dev/null 2>&1
		for repo in extra community; do
			grep -q "^\[$repo\]" /etc/pacman.conf ||
				echo "[$repo]
Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf
		done
		pacman -Sy >/dev/null 2>&1
		pacman-key --populate archlinux >/dev/null 2>&1
		;;
esac
}

installpkg(){ $installcmd $1 >/dev/null 2>&1 ;}

error() { echo "ERROR: $1" ; exit 1;}


set_option() {
    if grep -Eq "^$1.*" $CONF_FILE; then
        sed -i -e "/^$1.*/d" $CONF_FILE
    fi
    echo "$1 $2" >>$CONF_FILE
}

get_option() {
    echo $(grep -E "^${1}.*" $CONF_FILE|sed "s|${1}||")
}

welcomemsg() { \
	dialog --title "Welcome!" \
	--msgbox "Dialga's Void Post-install Script!\\n\\nThis script will automatically install a fully-featured Linux desktop, which I use as my main machine.\\n\\n-Kho-Dialga" 10 60

	dialog --title "Important Note!" \
		--yes-label "All ready!" \
		--no-label "Return..." \
		--yesno "Be sure the computer you are using has tha latest updates and refreshed $distro repositories.\\n\\nIf it does not, the installation of some programs might fail." 8 70
	}

getuserandpass() { \
	# Prompts user for new username an password.
	name=$(dialog --inputbox "First, please enter a name for the user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit 1
	while ! echo "$name" | grep -q "^[a-z_][a-z0-9_-]*$"; do
		name=$(dialog --no-cancel --inputbox "Username not valid. Give a username beginning with a letter, with only lowercase letters, - or _." 10 60 3>&1 1>&2 2>&3 3>&1)
	done
	pass1=$(dialog --no-cancel --insecure --passwordbox "Enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
	pass2=$(dialog --no-cancel --insecure --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	while ! [ "$pass1" = "$pass2" ]; do
		unset pass2
		pass1=$(dialog --no-cancel --insecure --passwordbox "Passwords do not match.\\n\\nEnter password again." 10 60 3>&1 1>&2 2>&3 3>&1)
		pass2=$(dialog --no-cancel --insecure --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
	done ;}

usercheck() { \
	! { id -u "$name" >/dev/null 2>&1; } ||
	dialog --colors --title "WARNING!" --yes-label "CONTINUE" --no-label "No wait..." --yesno "The user \`$name\` already exists on this system. DVPS can install for a user already existing, but it will \\Zboverwrite\\Zn any conflicting settings/dotfiles on the user account.\\n\\nDVPS will \\Zbnot\\Zn overwrite your user files, documents, videos, etc., so don't worry about that, but only click <CONTINUE> if you don't mind your settings being overwritten.\\n\\nNote also that DVPS will change $name's password to the one you just gave." 14 70
	}

localechecklist() {
locales="$(grep -E '\.UTF-8' $localefile|awk '{print $1, "off"}'|sed 's/^#//' | xargs)"
    dialog --infobox "Scanning locales ..." 4 60
    cmd=(dialog --stdout --no-items \
	    --separate-output \
	    --checklist "Select any additional locales:" 18 70 18)
chosenlocales=$("${cmd[@]}" ${locales})
}

localeset() {
    if [ -f $localefile ]; then
        # Uncomment locale from the locale file and regenerate it.
        dialog --title "DVPS Installation" --infobox "Generating selected locales..." 5 25
		for x in $chosenlocales; do
			sed -i "/$x/s/^\#//" $localefile
		done
        xbps-reconfigure -f glibc-locales >/dev/null 2>&1 || locale-gen >/dev/null 2>&1
    fi
}

wmmenu() { \
	wmlist=$(curl -Ls "$wmsfile" | sed '/^#/d' | cut -d, -f 6,2 | sed 's/,/ /')
	dialog --title "Window manager selection" --menu "Which window manager will you install?" 15 30 4 $wmlist 2> /tmp/wm
	}
preinstallmsg() { \
	dialog --title "Let's get this party started!" --yes-label "Let's go!" --no-label "No, nevermind!" --yesno "The rest of the installation will now be totally automated, so you can sit back and relax.\\n\\nIt will take some time, but when done, you can relax even more with your complete system.\\n\\nNow just press <Let's go!> and the system will begin installation!" 13 60 || { clear; exit 1; }
	}

adduserandpass() { \
	# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$name\"..." 4 50
	useradd -m -G wheel,audio,storage,input,video -s /bin/zsh "$name" >/dev/null 2>&1 ||
	usermod -a -G wheel,audio,storage,input,video "$name" && mkdir -p /home/"$name" && chown "$name":wheel /home/"$name"
	export repodir="/home/$name/.local/src/configs"
	mkdir -p "$repodir"
	chown -R "$name":wheel "$(dirname "$repodir")"
	echo "$name:$pass1" | chpasswd
	unset pass1 pass2 ;}

refreshrepos() { \
	dialog --infobox "Refreshing repositories" 4 40
	$updatecmd >/dev/null 2>1
	}


maininstall() { # Installs all needed programs from main repo.
	dialog --title "DVPS Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 5 70
	installpkg "$1"
	}

aurinstall() {
	dialog --title "DVPS Installation" \
		--infobox "Installing \`$1\` ($n of $total) from the AUR. $1 $2" 9 70
	echo "$aurinstalled" | grep -q "^$1$" && return 1
	sudo -u "$name" $aurhelper -S --noconfirm "$1" >/dev/null 2>&1
}

gitmakeinstall() {
	progname="${1##*/}"
	progname="${progname%.git}"
	dir="$repodir/$progname"
	dialog --title "DVPS Installation" \
		--infobox "Installing \`$progname\` ($n of $total) via \`git\` and \`make\`. $(basename "$1") $2" 8 70
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "$1" "$dir" ||
		{
			cd "$dir" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1
}

wmcount() { # Installs all needed programs from main repo.
	dialog --title "DVPS Installation" --infobox "Installing $wm, the window manager" 5 70
	installpkg "$1"
	}

sysconfig(){
for x in curl base-devel xstow git ntp zsh; do
	dialog --title "DVPS Installation" --infobox "Installing \`$x\` which is required to install and configure other programs." 5 70
	installpkg "$x"
done
}

voidsucklessconfig(){
	for x in fontconfig-devel harfbuzz-devel libX11-devel libXft-devel libXinerama-devel freetype-devel; do
	dialog --title "DVPS Installation" --infobox "Installing \`$x\` which is required to compile suckless utilities." 5 70
	installpkg "$x"
	done
}

wmgitmakeinstall() {
	progname="$(basename "$1" .git)"
	dir="$repodir/$progname"
	dialog --title "DVPS Installation" --infobox "Installing \`$wm\` via \`git\` and \`make\`. $(basename "$1") $2" 5 70
	sudo -u "$name" git clone --depth 1 "$1" "$dir" >/dev/null 2>&1 || { cd "$dir" || return 1 ; sudo -u "$name" git pull --force origin master;}
	cd "$dir" || exit 1
	make >/dev/null 2>&1
	make install >/dev/null 2>&1
	cd /tmp || return 1 ;}

manualinstall() {
	# Installs $1 manually. Used only for AUR helper here.
	# Should be run after repodir is created and var is set.
	dialog --infobox "Installing \"$1\", an AUR helper..." 7 50
	sudo -u "$name" mkdir -p "$repodir/$1"
	sudo -u "$name" git -C "$repodir" clone --depth 1 --single-branch \
		--no-tags -q "https://aur.archlinux.org/$1.git" "$repodir/$1" ||
		{
			cd "$repodir/$1" || return 1
			sudo -u "$name" git pull --force origin master
		}
	cd "$repodir/$1" || exit 1
	sudo -u "$name" -D "$repodir/$1" \
	makepkg --noconfirm -si >/dev/null 2>&1 || return 1
}

installationloop() { \
	([ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv) || curl -Ls "$progsfile" | sed '/^#/d' > /tmp/progs.csv
	total=$(wc -l < /tmp/progs.csv)
	while IFS=, read -r tag program comment; do
		n=$((n+1))
		echo "$comment" | grep -q "^\".*\"$" && comment="$(echo "$comment" | sed "s/\(^\"\|\"$\)//g")"
		case "$tag" in
			"G") gitmakeinstall "$program" "$comment" ;;
			"A") aurinstall "$program" "$comment" ;;
			*) maininstall "$program" "$comment" ;;
		esac
	done < /tmp/progs.csv ;}


putgitrepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	dialog --infobox "Downloading and installing config files..." 4 60
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown "$name":wheel "$dir" "$2"
	sudo -u "$name" git -C "$repodir" clone --depth 1 \
		--single-branch --no-tags -q --recursive -b "$branch" \
		--recurse-submodules "$1" "$dir"
	sudo -u "$name" cp -rfT "$dir" "$2"
}

installwm() {
	wm=$(cat /tmp/wm)
	wmtag=$(curl -Ls "$wmsfile" | grep $wm | cut -d, -f 1)
	extrapkgs=$(curl -Ls "$wmsfile" | grep $wm | cut -d, -f 3)
	chosenwm=$(curl -Ls "$wmsfile" | grep $wm | cut -d, -f 3,4 | sed 's/,/ /g')
	wmtotal=$(curl -Ls "$wmsfile" | grep $wm | cut -d, -f 3,4 | sed 's/,/ /g' | wc -w)
	wmcmd=$(curl -Ls "$wmsfile" | grep $wm | cut -d, -f 5)
	case $wmtag in
		G) wmgitmakeinstall $chosenwm "is the window manager" ;;
		*) wmcount $chosenwm "is the window manager" ;;
	esac
	case $wm in
		dwm) wmgitmakeinstall https://github.com/Kho-Dialga/dwmblocks-dialga.git "dwm's statusbar" ;;
		*) cat /dev/null ;;
	esac
}

elogindenable(){
	dialog --title "DVPS Installation" --infobox "Enabling the elogind service." 5 70
	yes | xbps-install -y elogind >/dev/null 2>&1; ln -s /etc/sv/dbus /var/service; ln -s /etc/sv/elogind /var/service
}

nm(){
	dialog --title "DVPS Installation" --infobox "Enabling NetworkManager." 5 70
	[ $distro = Void ] && installpkg NetworkManager >/dev/null; rm /var/service/{dhcpcd,wpa_supplicant}; ln -s /etc/sv/NetworkManager /var/service; sv up NetworkManager
	[ $distro = Arch ] && installpkg networkmanager >/dev/null; systemctl enable --now NetworkManager.service
}

systembeepoff() { dialog --infobox "Getting rid of that retarded error beep sound..." 10 50
	rmmod pcspkr
	echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf ;}

finalize(){ \
	dialog --infobox "Preparing welcome message..." 4 50
	dialog --title "All done!" --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nTo run the new graphical environment, log out and log back in as your new user, then run the command \"sx sh $XINITRC\" to start the graphical environment (it will start automatically in tty1).\\n\\n.t Kho-Dialga" 12 80
	}

### THE ACTUAL SCRIPT ###

### This is how everything happens in an intuitive format and order.

# Determine the distro

setvar

# Check if user is root on Void distro. Install dialog and add dialga-void-repo.
refreshrepo
installpkg dialog || error "Are you sure you're running this as the root user, are on an Void-based distribution and have an internet connection?"

# Welcome user and pick dotfiles.
welcomemsg || error "User exited."

# Get and verify username and password.
getuserandpass || error "User exited."

# Give warning if user already exists.
usercheck || error "User exited."

# Select which window manager will be installed
wmmenu || error "User exited."

# Locale checklist
localechecklist || error "User exited."

# Last chance for user to back out before install.
preinstallmsg || error "User exited."

### The rest of the script requires no user input.

# Refresh Void repositories.
refreshrepos || error "Error automatically refreshing the Void repos. Consider doing so manually."

# Install packages needed for configuring the system and compiling suckless utilities.

sysconfig

[ $distro = Void ] && voidsucklessconfig

dialog --title "DVPS Installation" --infobox "Synchronizing system time to ensure successful and secure installation of software..." 4 70
ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

adduserandpass || error "Error adding username and/or password."

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case

# Allow user to run sudo without password. Since AUR programs must be installed
# in a fakeroot environment, this is required for all builds with AUR.
trap 'rm -f /etc/sudoers.d/dvps-temp' HUP INT QUIT TERM PWR EXIT
echo "%wheel ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/dvps-temp

# Make pacman colorful, concurrent downloads and Pacman eye-candy.
[ $distro = Arch ] && grep -q "ILoveCandy" /etc/pacman.conf || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf
[ $distro = Arch ] && sed -Ei "s/^#(ParallelDownloads).*/\1 = 5/;/^#Color$/s/#//" /etc/pacman.conf

# Use all cores for compilation.
[ $distro = Arch ] && sed -i "s/-j2/-j$(nproc)/;/^#MAKEFLAGS/s/^#//" /etc/makepkg.conf

[ $distro = Arch ] && manualinstall $aurhelper

# The command that does all the installing. Reads the progs.csv file and
# installs each needed program the way required. Be sure to run this only after
# the user has been created and has priviledges to run sudo without a password
# and all build dependencies are installed.
installationloop
aurinstall xstow
# Install the window manager
installwm

# Install the config files themselves
putgitrepo "$dotfilesrepo" "$repodir" "$repobranch"
chown -R $name /home/$name/.local
sudo -u "$name" xstow -f $repodir -target /home/$name 2>&1
sudo -u "$name" sed -i "/ssh-agent/s/awesome/$wmcmd/g" /home/$name/.config/x11/xinitrc
rm -rf "/home/$name/README.md" "/home/$name/.stow-local-ignore" "/home/$name/.git" "/home/$name/configuration.nix" "/home/$name/.bash*" "/home/$name/dwm-dialga" "/home/$name/dwmblocks-dialga" "/home/$name/st-dialga" "/home/$name/dmenu-dialga"

# Switch from dhcpcd/wpa_supplicant to NetworkManager
nm
# Enable the elogind service

[ $distro = Void ] && elogindenable

# Most important command! Get rid of the beep!
systembeepoff

# Make zsh the default shell for the user.
chsh -s /bin/zsh "$name" >/dev/null 2>&1
sudo -u "$name" mkdir -p "/home/$name/.cache/zsh/"

# dbus UUID must be generated for runit.
dbus-uuidgen > /var/lib/dbus/machine-id

# Use system notifications for Brave on Artix
echo "export \$(dbus-launch)" > /etc/profile.d/dbus.sh

# Set up more locales
localeset

# This line, overwriting the `newperms` command above will allow the user to run
# serveral important commands, `shutdown`, `reboot`, updating, etc. without a password.
echo "%wheel ALL=(ALL) ALL" >/etc/sudoers.d/00-dvps-wheel-can-sudo
echo "%wheel ALL=(ALL) NOPASSWD: /usr/bin/shutdown,/usr/bin/poweroff,/usr/bin/reboot,/usr/bin/zzz,/usr/bin/xbps-install -Su,/usr/bin/xbps-install -S,/usr/bin/make install,/usr/bin/make clean install,/usr/bin/vsv,/usr/bin/systemctl suspend,/usr/bin/wifi-menu,/usr/bin/mount,/usr/bin/umount,/usr/bin/pacman -Syu,/usr/bin/pacman -Syuw --noconfirm,/usr/bin/loadkeys,/usr/bin/paru" >/etc/sudoers.d/01-dvps-cmds-without-password

# Last message! Install complete!
finalize
clear
