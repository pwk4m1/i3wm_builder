#!/bin/sh

AUTHOR="k4m1  <k4m1@protonmail.com>";
LOGFILE="install.log";

function install_failed {
	echo "Installing $1 failed!";
	echo "Please submit ${LOGFILE} to ${AUTHOR}";
	exit 1;
}

function install_brew {
	echo "Installing brew...";
	TARGET="https://raw.githubusercontent.com/\
		Homebrew/install/master/install.sh"
	/bin/bash -c "$(curl -fsSL ${TARGET})";
}

function install_pkgin {
	echo "Installing pkgin...";
	BOOTSTRAP_TAR="bootstrap-trunk-x86_64-20200219.tar.gz"
	BOOTSTRAP_SHA="92992f79188a677f09cfa543499beef3f902017a"
	ADDR="https://pkgsrc.joyent.com/packages/Darwin/bootstrap/";

	curl -O ${ADDR}${BOOTSTRAP_TAR};
	echo "Verifying ${BOOTSTRAP_SHA}";

	echo "${BOOTSTRAP_SHA}  ${BOOTSTRAP_TAR}" > /tmp/check_shasum;
	shasum -c -s /tmp/check_shasum || {
		echo "Shasum check for ${BOOTSTRAP_TAR} failed! exit.";
		exit 1;
	}
	rm -rf /tmp/check_shasum;

	echo "Installing bootstrap kit to /opt/pkg";
	sudo tar -zxpf ${BOOTSTRAP_TAR} -C /;

	echo "Reloading PATH/MANPATH";
	eval $(/usr/libexec/path_helper);
	export PATH="/opt/pkg/bin:$PATH";
}

function install_with_brew {
	echo "Installing $1...";
	brew install $1 >> ${LOGFILE} 2>&1 || {
		install_failed $1;
	}
	echo "Done";
}

function install_with_pkgin {
	echo "Installing $1...";
	sudo pkgin -y install $1 >> ${LOGFILE} 2>&1 || {
		install_failed $1;
	}
	echo "Done";
}

function check_lib {
	printf "Checking for $1: ";
	lib=`find /usr/local/Cellar -name $1 | grep -v include`;
	if [ "${lib}" == "/usr/local/Cellar/$1" ]; then
		echo "${lib}";
		return;
	fi
	echo "Not found, installing...";
	$2 $1;
}

function check_prog {
	printf "Checking for $1: ";
	command -v $1 2>/dev/null && return;
	command -v /opt/pkg/bin/$1 2>/dev/null && {
		PATH="/opt/pkg/bin:$PATH";
		return;
	}
	command -v /opt/X11/bin/$1 2>/dev/null && {
		PATH="/opt/X11/bin:$PATH";
		return;
	}
	command -v /usr/local/bin/$1 2>/dev/null && {
		PATH="/usr/local/bin:$PATH";
		return;
	}
	echo "Not found, installing...";
	$2 $1;
}

function git_clone {
	echo "Fetching $1";
	git clone $1 >> $LOGFILE 2>&1 || {
		install_failed $1;
	}
}

function install_xquartz {
	echo "XQuartz must be installed manually, you can obtain XQuartz from";
	echo "https://www.xquartz.org/";
	exit 1;
}

function check_all {
	check_prog "startx" install_xquartz;
	check_prog "git" install_with_brew;
	check_prog "asciidoc" install_with_brew;
	check_prog "xmlto" install_with_brew;
	check_prog "make" install_with_brew;
	check_prog "automake" install_with_brew;
	check_prog "libtool" install_with_brew;
	check_prog "pulseaudio" install_with_brew;
	check_lib "yajl" install_with_brew;
	check_prog "i3" install_with_pkgin;
}

function build_libconfuse {
	echo "Building libconfuse";
	git_clone https://github.com/martinh/libconfuse;
	cd libconfuse;
	./autogen.sh;
	mkdir build;
	cd build;
	../configure 2>&1 || {
		install_failed "libconfuse";
	}
	make 2>&1 || {
		install_failed "libconfuse";
	}
	make install ||  {
		install_failed "libconfuse";
	}
	cd ../../
	echo "Installed libconfuse, cleaning up...";
	rm -rf libconfuse;
}

function build_i3status {
	echo "Building i3status":
	git_clone https://github.com/i3/i3status;
	cd i3status;
	autoreconf -fi 2>&1 || {
		install_failed "i3status";
	}
	mkdir build;
	cd build;
	../configure --disable-sanitizers 2>&1 || {
		install_failed "i3status";
	}
	echo "Modifying makefile to make it work with MacOS...";
	cp Makefile Makefile.old
	cat Makefile.old | sed 's/xmlto/xmlto\ --skip-validation/g' > Makefile
	make -j8 2>&1 || {
		install_failed "i3status";
	}
	sudo make install || {
		install_failed "i3status";
	}
	cd ../../
	echo "Installed i3status, cleaning up...";
	rm -rf i3status;
}

function main {
	check_all 2>&1 | tee -a $LOGFILE;
	build_libconfuse 2>&1 | tee -a $LOGFILE;
	build_i3status 2>&1 | tee -a $LOGFILE;
}

main;
