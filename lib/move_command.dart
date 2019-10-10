import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:args/command_runner.dart';
import 'package:yaml/yaml.dart';

import 'yaml.dart';

class MoveCommand extends Command {
  @override
  String get description =>
      "Moves a dart library and updates all import statements to reflect its now location.";

  @override
  String get name => "move";

  String _projectName;

  void run() async {
    Directory.current = "./test/data/";

    if (argResults.rest.length != 2) {
      fullusage();
    }
    if (!await File("pubspec.yaml").exists()) {
      fullusage(
          error: "The pubspec.yaml is missing from: ${Directory.current}");
    }
    Yaml yaml = Yaml("pubspec.yaml");
    await yaml.load();
    _projectName = yaml.getValue("name");

    // check we are in the root.
    if (!await Directory("lib").exists()) {
      fullusage(error: "You must run a move from the root of the package.");
    }

    String from = argResults.rest[0];
    String to = argResults.rest[1];

    File fromPath = await validFrom(from);
    File toPath = await validTo(to);

    process(fromPath, toPath);
  }

  void process(File fromPath, File toPath) async {
    Stream<FileSystemEntity> files = Directory.current.list(recursive: true);

    List<FileSystemEntity> dartFiles =
        await files.where((file) => file.path.endsWith(".dart")).toList();

    int scanned = 0;
    int updated = 0;
    for (var file in dartFiles) {
      scanned++;
      MoveResult result = await replaceString(file, fromPath, toPath);
      File tmpFile = result.tmpFile;

      if (result.changeCount != 0) {
        updated++;
        // FileSystemEntity backupFile = await file.rename(file.path + ".bak");
        // await tmpFile.rename(file.path);
        // await backupFile.delete();

        print("Updated : ${file.path} changed ${result.changeCount} lines");
      }
    }
    print("Finished: scanned $scanned updated $updated");
  }

  Future<MoveResult> replaceString(
      FileSystemEntity file, File fromPath, File toPath) async {
    Directory systemTempDir = Directory.systemTemp;

    String tmpPath = p.join(systemTempDir.path, p.relative(file.path));
    File tmpFile = File(tmpPath);

    Directory tmpDir = Directory(tmpFile.parent.path);
    await tmpDir.create(recursive: true);

    IOSink tmpSink = tmpFile.openWrite();

    MoveResult result = MoveResult(tmpFile);

    print("Scanning: ${file.path}");

    await File(file.path)
        .openRead()
        .transform(utf8.decoder)
        .transform(LineSplitter())
        .forEach((line) =>
            result.changeCount += replaceLine(line, fromPath, toPath, tmpSink));

    return result;
  }

  int replaceLine(String line, File fromPath, File toPath, IOSink tmpSink) {
    String normalised = normalise(line);

    String newLine = normalised;

    int changeCount = 0;

    // Does the line contain our fromPath
    newLine = actualReplaceLine(normalised, fromPath, toPath);

    if (line != normalised) {
      changeCount++;
    }
    tmpSink.writeln(newLine);

    return changeCount;
  }

  ///
  /// Takes a normalised line (local package: removed)
  /// and determines if it references our fromFile
  String actualReplaceLine(String normalised, File fromFile, File toFile) {
    String line = normalised;

    // import 'package:square_phone/yaml.dart';  - consider
    // import 'package:yaml/yaml.dart'; - ignore
    // import 'yaml.dart'; - consider.

    ///NOTE: all imports are relative to the 'lib' directory.
    Directory lib = Directory(p.join(Directory.current.path, 'lib'));

    if (normalised.startsWith("import")) {
      {
        String relative = p.relative(fromFile.path, from: lib.path);

        String regexString = r"'.*'";
        RegExp regExp = RegExp(regexString);
        String matches = regExp.stringMatch(normalised);
        if (matches.isEmpty) {
          throw Exception(
              "import line did not contain a valid path: ${normalised}");
        }
        String importPath = matches.substring(1, matches.length - 1);
        String relativeImportPath = p.relative(importPath);
        if (relativeImportPath == relative) {
          String relativeTo = p.relative(toFile.path, from: lib.path);
          line = "import '${relativeTo}'";
        }
      }
    }
    return line;
  }

  ///
  /// Remove the package declaration from local files.
  String normalise(String line) {
    String normalised = line;
    String projectPackage = "package:${_projectName}";
    // we ignore imported packages unless its our package.
    if (normalised.startsWith("import")) {
      {
        // make certain we only have single spaces
        normalised = normalised.replaceAll("  ", " ");
        // ensure we are using single quotes.
        normalised = normalised.replaceAll("\"", "'");

        if (line.contains(projectPackage)) {
          normalised = line.replaceFirst(projectPackage, "");
          // import '/
          if (normalised[8] == "/") {
            // strip leading slash as a paths must be relative.
            normalised = normalised.replaceFirst("/", "");
          }
        }
      }
    }
    return normalised;
  }

  void fullusage({String error}) {
    if (error != null) {
      print("Error: $error");
      print("");
    }

    print("Usage: ");
    print("Run the move from the root of the package");
    print("move <from path> <to path>");
    print("e.g. move apps/string.dart  util/string.dart");
    print(argParser.usage);

    exit(-1);
  }

  /// reads the project name from the yaml file
  ///
  Future<String> getProjectName() async {
    String contents = await File("pubspec.yaml").readAsString();

    YamlDocument pubSpec = loadYamlDocument(contents);

    for (TagDirective tag in pubSpec.tagDirectives) {
      print("Tag $tag");
    }
    return "fred";
  }

  Future<File> validFrom(String from) async {
    // all file paths are relative to lib/ but
    // the imports don't include lib so devs
    // will just pass in the name as the see it in the import statement (e.g. no lib)
    // but when we are validating the actual path we need the lib.
    File actualPath = File(p.canonicalize(p.join("lib", from)));

    if (!await actualPath.exists()) {
      fullusage(
          error:
              "The <fromPath> is not a valid filepath: '${actualPath.path}'");
    }
    return actualPath;
  }

  Future<File> validTo(String to) async {
    // all file paths are relative to lib/ but
    // the imports don't include lib so devs
    // will just pass in the name as the see it in the import statement (e.g. no lib)
    // but when we are validating the actual path we need the lib.
    File actualPath = File(p.canonicalize(p.join("lib", to)));
    if (!await actualPath.parent.exists()) {
      fullusage(
          error: "The <toPath> directory does not exist: ${actualPath.parent}");
    }
    return actualPath;
  }
}

class MoveResult {
  File tmpFile;
  int changeCount = 0;

  MoveResult(this.tmpFile);
}
