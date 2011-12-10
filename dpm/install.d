module dpm.install;

import std.file;
import std.stdio;
import std.utf;
import std.process;
import std.string;

import dpm.json;

/*
 * Installs dependencies if they don't exist and returns paths to their package roots.
 * This function will build each dependency before responding to the caller.
 *
 * If the version is *, any version will be acceptable. If the version is latest,
 * a check will be made to the database to check for updates.
 * 
 * @param deps- The dependencies to build (key: module name, value: version)
 */
string[] installDeps(string[string] deps) {
	string[] files;

	foreach(key, val; deps) {
		files ~= key;
	}

	return files;
}

/*
 * Parse the main file looking for dependencies that may have been missed.
 * 
 * Advise the user to add the missing dependencies (with version numbers) to
 * the package.json.
 *
 * This function will not install anything; it finds missing imports and gets
 * their version numbers.
 *
 * @param main- Path to the main source file specified in the package.json
 * @return A map of dependencies with their latest versions
 */
string[string] findMissingDeps(string main, ref string[string] curDeps) {
	return null;
}

/*
 * Builds a package using rdmd.
 * 
 * @param main- Filepath to the main source file
 * @param libs- Paths to external dependencies (managed by this package manager)
 * @return True if the build succeeded
 */
bool buildPackage(string main, string outfile, string[] libs = null) {
	auto command = format("rdmd --build-only -of%s %s", outfile, main);

	writefln("Building with command: %s", command);

	auto ret = system(command);
	if (ret == 0) {
		return true;
	}

	writefln("Build exited with code: %d", ret);

	return false;
}

/*
 * Installs a package given a path to the package.json.
 * 
 * @param filename- Path to a package.json
 @ @return True if the package was successfully installed
 */
bool installPackage(string filename) {
	bool ret = true;
	try {
		// get the JSON data for the package
		string jsonData = readText(filename);
		auto pack = parseJSON(jsonData);

		writefln("Got here");

		string main = pack.obj["main"].str;
		string name = pack.obj["name"].str;
		string[string] deps;
		
		foreach(key, val; pack.obj["dependencies"].obj) {
			deps[key] = val.str;
		}
		findMissingDeps(main, deps);

		string[] files = installDeps(deps);
		foreach(file; files) {
			writefln(file);
		}

		ret = buildPackage(main, "bin/" ~ name);
		foreach(key, val; pack.obj["bin"].obj) {
			ret = buildPackage(val.str, "bin/" ~ key);
		}
	} catch (FileException e) {
		writefln("Error opening file: " ~ filename);
	} catch (UTFException e) {
		writefln("File not unicode encoded: " ~ filename);
	} catch (JSONException e) {
		writefln("File not valid JSON: " ~ filename);
	}

	return ret;
}
