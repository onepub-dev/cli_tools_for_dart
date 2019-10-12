import 'dart:io';
import 'package:path/path.dart' as p;

import 'library.dart';
import 'yaml.dart';

enum ImportType {
  NOT // not an import line
  ,
  RELATIVE // a relative path to a library
  ,
  LOCAL_PACKAGE // a package path to an internal libary
  ,
  BUILT_IN // a dart package
  ,
  EXTERNAL_PACKAGE // a package path to an external library
}

class Line {
  static String _projectName;
  static Directory libRoot;
  static String projectPrefix;
  static String dartPrefix = "dart:";
  static String packagePrefix = "package:";

  // The library source file that this line comes from.
  Library sourceLibrary;
  ImportType _importType;
  // absolute path to the imported library.
  String _importedPath;
  String originalLine;
  String normalised;

  String get importedPath => _importedPath;

  static void init() async {
    _projectName = await getProjectName();
    projectPrefix = "package:${_projectName}";
    libRoot = Directory(p.join(Directory.current.path, 'lib'));
  }

  Line(this.sourceLibrary, String line) {
    originalLine = line;
    normalised = normalise(line);
    if (!__isImportLine(line)) {
      _importType = ImportType.NOT;
    } else if (__builtInLibrary(line)) {
      _importType = ImportType.BUILT_IN;
    } else if (__isExternalPackage(line)) {
      _importType = ImportType.EXTERNAL_PACKAGE;
    } else if (__isLocalPackage(line)) {
      _importType = ImportType.LOCAL_PACKAGE;
      _importedPath = _extractImportedPath();
    } else {
      _importType = ImportType.RELATIVE;
      _importedPath = _extractImportedPath();
    }
  }

  bool get isImportLine => _importType != ImportType.NOT;
  bool get isBuiltInLibrary => _importType == ImportType.BUILT_IN;

  bool __isImportLine(String normalised) {
    return normalised.startsWith("import");
  }

  bool __builtInLibrary(String normalised) {
    return normalised.startsWith("import 'dart:");
  }

  bool __isExternalPackage(String normalised) {
    return normalised.startsWith("import 'package:") &&
        !normalised.startsWith("import '${projectPrefix}");
  }

  bool __isLocalPackage(String normalised) {
    return normalised.startsWith("import '${projectPrefix}");
  }

  // import 'package:square_phone/yaml.dart';  - consider
  // import 'package:yaml/yaml.dart'; - ignore
  // import 'dart:io'; - ignore
  // import 'yaml.dart'; - consider.

  String _extractImportedPath() {
    String quoted = _extractQuoted();
    String importedPath;

    if (quoted.startsWith(projectPrefix)) {
      importedPath = quoted.substring(projectPrefix.length);
    } else if (quoted.startsWith(dartPrefix)) {
      importedPath = quoted.substring(dartPrefix.length);
    } else if (quoted.startsWith(packagePrefix)) {
      importedPath = quoted.substring(packagePrefix.length);
    } else {
      importedPath = quoted;
    }
    // strip leading slash as a paths must be relative.
    if (importedPath.startsWith(p.separator)) {
      importedPath = importedPath.replaceFirst(p.separator, "");
    }

    String finalPath;
    if (sourceLibrary.isExternal) {
      // e.g. bin/main.dart and paths will be realtive to lib
      finalPath = p.canonicalize(p.join(libRoot.path, importedPath));
    } else {
      finalPath = p.canonicalize(p.join(sourceLibrary.directory, importedPath));
    }

    return finalPath;
  }

  /// Extract the components between the quotes in the import statement.
  String _extractQuoted() {
    String regexString = r"'.*'";
    RegExp regExp = RegExp(regexString);
    String matches = regExp.stringMatch(normalised);
    if (matches.isEmpty) {
      throw Exception(
          "import line did not contain a valid path: ${normalised}");
    }
    return matches.substring(1, matches.length - 1);
  }

  ///
  /// Remove the package declaration from local files.
  String normalise(String line) {
    String normalised = line.trim();
    // make certain we only have single spaces
    normalised = normalised.replaceAll("  ", " ");
    // ensure we are using single quotes.
    normalised = normalised.replaceAll("\"", "'");
    return normalised;
  }

  /// reads the project name from the yaml file
  ///
  static Future<String> getProjectName() async {
    Yaml yaml = Yaml("pubspec.yaml");
    await yaml.load();
    return yaml.getValue("name");
  }

  String update(Library currentLibrary, File fromFile, File toFile) {
    ///NOTE: all imports are relative to the 'lib' directory.
    ///

    String line = originalLine;

    if (_importType == ImportType.RELATIVE ||
        _importType == ImportType.LOCAL_PACKAGE) {
      String relativeFromPath = p.relative(fromFile.path, from: libRoot.path);

      String importsRelativePath;

      importsRelativePath = p.relative(importedPath, from: libRoot.path);

      if (currentLibrary.sourceFile.path == fromFile.path) {
        // If we are processing the file we are moving
        // we need to also update all of its imports.
        // Imports a relative and if we have moved directories
        // we need to correct the path.
        String relativeImportPath = p.relative(importedPath,
            from: currentLibrary.sourceFile.parent.path);
        String newImportPath =
            calcNewImportPath(fromFile.path, relativeImportPath, toFile.path);
        line = replaceImportPath('${newImportPath}');
      } else
      // does the import path match the file we are looking to change.
      if (importsRelativePath == relativeFromPath) {
        /// [externalLib] The library we are parsing is outside the lib dir (e.g. bin/main.dart)
        if (currentLibrary.isExternal) {
          // relative to the 'lib' directory.
          String relativeToRoot = p.relative(toFile.path, from: libRoot.path);
          line = replaceImportPath('package:${_projectName}/${relativeToRoot}');
        } else if (_importType == ImportType.LOCAL_PACKAGE) {
          // relative to the 'lib' directory.
          String relativeToRoot = p.relative(toFile.path, from: libRoot.path);
          line = replaceImportPath('package:${_projectName}/${relativeToRoot}');
        } else {
          // must be a [ImportType.RELATIVE]
          String relativeToLibrary = p.relative(toFile.path,
              from: currentLibrary.sourceFile.parent.path);

          line = replaceImportPath('${relativeToLibrary}');
        }
      }
    }

    return line;
  }

  ///
  /// Takes an relative [import] path contained within [originalLibrary]
  /// and determines the new import path required to place the same [import]
  /// in the new library.
  /// e.g.
  /// [originalLibrary]: /lib/util/debug.dart
  /// [import] ../widget/timezone.dart
  /// [newLibrary]: /lib/app/debug/debug.dart
  /// Result: ../../widget/timezone.dart
  String calcNewImportPath(
      String originalLibrary, String import, String newLibrary) {
    String absImport = resolveImport(originalLibrary, import);
    return p.relative(absImport, from: p.dirname(newLibrary));
  }

  ///
  /// Returns the absolute path of an imported file.
  /// Uses the absolute path of the [library] that
  /// the imported file is imported from
  /// to calculate the imported files location.
  ///
  String resolveImport(String library, String import) {
    return p.join(
        p.normalize(p.absolute(p.dirname(library), p.dirname(import))),
        p.basename(import));
  }

  ///
  /// replaces the path component of the original import statement with
  /// a new path.
  /// This is important as an import can have an 'as' or 'show' statement
  /// after the path and we don't want to interfere with it.
  String replaceImportPath(String newPath) {
    return this.originalLine.replaceFirst(_extractQuoted(), newPath);
  }
}
