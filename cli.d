import std.stdio;
import std.getopt;
import std.file;

import dpm.install;

void install(string[] args) {
	string filename = args.length > 0 ? args[0] : "./";

	if (!filename.exists) {
		printUsage();
		return;
	}

	if (filename.isDir) {
		filename ~= "/package.json";
		if (!filename.exists) {
			printUsage();
			return;
		}
	}

	installPackage(filename);
}

void printUsage() {
	writefln("Usage: dpm [verb] [options]");
}

int main(string[] args) {
	if (args.length < 2) {
		printUsage();
		return -1;
	}

	string verb = args[1];

	switch (verb) {
		case "install":
			install(args[2..$]);
			break;

		default:
			break;
	}

	return 0;
}
