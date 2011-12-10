Intro
=====

D is a cool language, but it has no standard package manager. This is an attempt to make a package manager that everyone can agree with. The idea is to have a package manager written entirely in D.

The design comes is based off NPM for NodeJS, because it is a simple and configurable package manager.

Please note that this is very much in the development stage, so things will most likely not work. Please wait for an official release before using this in anything mission-critical.

Install
=======

Checkout the repository:

    git clone git://github.com/beatgammit/json-d.git

Change directories to new repo:
	cd json-d

Run build script:

	./build.sh

The build script uses rdmd and the binary will be: `bin/dpm`

Eventually, dpm will be able to install itself.
