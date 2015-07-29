#!/usr/bin/env bash
#
# brew-install.sh
# Copyright (C) 2013 KuoE0 <kuoe0.tw@gmail.com>
#
# Distributed under terms of the MIT license.

function get-package-name {
	echo $(echo $1 | cut -d ' ' -f1)
}

function get-parameters {
	Col=$(echo $1 | awk -F' ' '{print NF; exit}')
	if [ $Col != "1" ]; then
		echo $(echo $1 | cut -d ' ' -f2-)
	fi
}

function tolower {
	echo $1 | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

# create temporal directory & log directory
TMP_DIR=/tmp/BREW-$(date +%Y%m%d-%H%M%S)
LOGDIR="$TMP_DIR/log"
IFS=$'\n'

if [ -d $TMP_DIR ] || [ -f $TMP_DIR ]; then
	rm -r $TMP_DIR
fi
mkdir -p $TMP_DIR
mkdir -p $LOGDIR

# brew does not exist
if ! which brew &> /dev/null; then
	# remove homebrew directory /usr/local/Cellar
	if [ -d /usr/local/Cellar ] || [ -f /usr/local/Cellar ]; then
		rm -rf /usr/local/Cellar
	fi

	# remove homebrew directory /usr/local/.git
	if [ -d /usr/local/.git ] || [ -f /usr/local/.git ]; then
		rm -rf /usr/local/.git
	fi

	# install homebrew
	echo "Install Homebrew..."
	# send ENTER keystroke to install automatically
	echo | ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

fi

# homebrew install failed
if ! which brew &> /dev/null; then
	echo "Homebrew install failed!"
	exit 255
fi

# add taps to homebrew
tap_list=(caskroom/cask caskroom/versions caskroom/fonts homebrew/dupes homebrew/science homebrew/versions)

for TAP_NAME in ${tap_list[*]}; do
	echo "Add tap $TAP_NAME to Homebrew..."
	brew tap $TAP_NAME
done


# brew status check
echo "Diagnose Homebrew..."
brew doctor 2>&1 | tee "$LOGDIR/brew-doctor.log"

# install packages and applications
if [ "$?" = "0" ]; then

	# update brew database
	brew update

	# install & upgrade brew-cask
	brew install brew-cask
	brew upgrade brew-cask

	# install applications from homebrew-cask
	# Install from homebrew-cask first, because there are some package need XQuartz
	while read APP; do
		echo "Installing $APP..."
		PKG=$(tolower $APP)
		brew cask install $PKG --appdir=/Applications 2>&1 | tee "$LOGDIR/$PKG.log"
	done < cask-packages.list

	# install packages from homebrew
	while read CMD; do
		PKG=$(get-package-name $CMD)
		PARA=$(get-parameters $CMD)
		echo "Installing $PKG..."
		brew install $PKG $PARA 2>&1 | tee "$LOGDIR/$PKG.log"
	done < packages-core.list

	# use llvm to build
	brew --env --use-llvm

	# install packages from homebrew
	while read CMD; do
		PKG=$(echo $CMD | cut -d' ' -f1)
		echo "Installing $PKG..."
		brew install $PKG $PARA 2>&1 | tee "$LOGDIR/$PKG.log"
	done < packages.list

fi

