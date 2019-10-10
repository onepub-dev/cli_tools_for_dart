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
    Directory.current = "./test/data";

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

    File fromPath = File(from);
    if (!await validFrom(fromPath)) {
      fullusage(
          error:
              "The <fromPath> is not a valid filepath: '${p.join(Directory.current.path, fromPath.path)}'");
    }

    File toPath = File(to);
    if (!await validTo(toPath)) {
      fullusage(
          error:
              "The <toPath> is not a valid filepath: ${p.join(Directory.current.path, toPath.path)}");
    }

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

    if (normalised.startsWith("import")) {
      {
        String relative = p.relative(fromFile.path);

        String regexString = r"'.*'";
        RegExp regExp = RegExp(regexString);
        var matches = regExp.allMatches(normalised);
        if (matches.length != 1) {
          throw Exception(
              "import line did not contain a valid path: ${normalised}");
        }
        var match = matches.elementAt(0);
        if (match.groupCount != 1) {
          throw Exception(
              "import line did not contain a valid path: ${normalised}");
        }
        String importPath = match.group(0);
        String relativeImportPath = p.relative(importPath);
        if (relativeImportPath == relative) {
          line = "import '${toFile.path}'";
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

  Future<bool> validFrom(File fromPath) async {
    return await fromPath.exists();
  }

  Future<bool> validTo(toPath) async {
    return await toPath.parent.exists();
  }
}

class MoveResult {
  File tmpFile;
  int changeCount = 0;

  MoveResult(this.tmpFile);
}
