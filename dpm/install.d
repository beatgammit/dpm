module dpm.install;

import std.array;
import std.file;
import std.stdio;
import std.utf;
import std.process;
import std.string;
import std.regex;

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
	auto reg = regex("^(?:static\\s+)?import\\s+(.*);$", "gm");

	// gets the module's fully qualified name
	string getName(string s) {
		if (s.indexOf('=') > 0) {
			return s.split("=")[1].strip();
		}

		return s.strip();
	}

	// checks if the string is in the standard library
	bool isStandard(string s) {
		if (s.length > 5) {
			if (s[0 .. 4] == "std/" || s[0 .. 4] == "etc/" || s[0 .. 5] == "core/") {
				return true;
			}
		}

		return false;
	}

	string[] fetchImports(string filename) {
		try {
			auto deps = appender!(string[])();
			string contents = readText(filename);
			// foreach ImportList, we'll parse out the actual deps
			foreach(m; match(contents, reg)) {
				string capture = m.captures[1];

				// foreach import, check to if it's an:
				// - Import (single import)
				// - ImportBindings (single import with a bind list
				// - ImportList (just a list of imports)

				long comma = capture.indexOf(',');
				long colon = capture.indexOf(':');
				if (colon > 0 && (colon < comma || comma == -1)) {
					// ImportBindings
					// if the colon is before the comma or if the comma isn't in the string
					deps.put(getName(capture[0 .. colon]));
				} else if (comma > 0) {
					// ImportList
					// If it's not an ImportBindings, but there is more than one
					foreach(s; capture.split(",")) {
						deps.put(getName(capture));
					}
				} else {
					// Regular import
					deps.put(getName(capture));
				}
			}

			return deps.data;
		} catch (FileException e) {
			writefln("Error reading file: %s. Ignoring.", main);
		} catch (UTFException e) {
			writefln("File '%s' not valid unicode. Ignoring.", main);
		}

		return null;
	}

	bool keepProcessing = true;

	// populated with package dependencies
	// the value will be true if we've evaluated it
	bool[string] internalDeps;

	// populated with dependencies not in package root (3rd party probably)
	// the value will be true is irrelevant (just used for uniqueness)
	bool[string] otherDeps;

	// add the main file to it
	internalDeps[main] = false;

	// once all files have been processed, we're done
	while(keepProcessing) {

		// go through each of the files and process them
		foreach(key, value; internalDeps) {
			// if it's been processed, skip it
			if (value) {
				if (keepProcessing) {
					keepProcessing = false;
				}
				continue;
			}

			auto deps = fetchImports(key);

			// change these to relative paths
			foreach(ref s; deps) {
				s = s.replace(".", "/");
			}

			// go through the dependencies and update our dependency sets
			foreach(s; deps) {
				if (!isStandard(s)) {
					// add the extension
					s ~= ".d";

					if (s.exists) {
						if (!internalDeps.get(s, false)) {
							internalDeps[s] = false;
							keepProcessing = true;
						}
					} else {
						// doesn't really matter what the value is
						otherDeps[s] = true;
					}
				}
			}

			// mark this as processed
			internalDeps[key] = true;
		}
	}

	writefln("Package files:");
	foreach(s; internalDeps.byKey()) {
		writefln("  %s", s);
	}

	writefln("3rd party files:");
	foreach(s; otherDeps.byKey()) {
		writefln("  %s", s);
	}
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

		string main = pack.obj["main"].str;
		string name = pack.obj["name"].str;
		string[string] deps;
		
		foreach(key, val; pack.obj["dependencies"].obj) {
			deps[key] = val.str;
		}
		findMissingDeps(main, deps);

		string[] files = installDeps(deps);
		foreach(file; files) {
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
