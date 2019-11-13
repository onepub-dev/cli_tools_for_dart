import 'dart:io';

import 'package:drtimport/yaml_me.dart';
import 'package:path/path.dart' as p;

import 'package:args/command_runner.dart';

import 'a_command2.dart';

class BCommand extends Command<void> {
  Directory lib;

  void run() async {
    lib = Directory(p.join(Directory.current.path, 'lib'));
    p.relative("hi");
    YamlMe("pubspec.yaml");

    ACommand();
  }

  @override
  String get description => "Bcommand";

  @override
  String get name => "BCommand";
}
