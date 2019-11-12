import 'package:args/command_runner.dart';
import 'package:square_cli/move_command.dart';
import 'package:square_cli/patch_command.dart';
import 'package:square_cli/square_cli.dart';
import 'package:test/test.dart';

void main() {
  test('move file to file', () {
    run([
      "move",
      "--root",
      "./test/data/",
      "--debug",
      "a_command2.dart",
      "a_command.dart"
    ]);
  });

  test('move file to directory', () {
    run(["move", "--root", "./test/data/", "--debug", "yaml_me.dart", "util"]);
    // now move it back.
    run([
      "move",
      "--root",
      "./test/data/",
      "--debug",
      "util/yaml_me.dart",
      "."
    ]);
  });

  test('move directory to directory', () {
    run(["move", "--root", "./test/data/", "--debug", "util", "other"]);
    run(["move", "--root", "./test/data/", "--debug", "other", "util"]);
  });

  test('move directory to file', () {
    run(["move", "--root", "./test/data/", "--debug", "util", "other.dart"]);
  });
  test("Rename A->A2", () {
    run([
      "move",
      "--root",
      "./test/data/",
      "--debug",
      "a_command.dart",
      "a_command2.dart"
    ]);
  });

  test("Rename A2->A", () {
    run([
      "move",
      "--root",
      "./test/data/",
      "--debug",
      "a_command2.dart",
      "a_command.dart"
    ]);
  });

  test("Move Yaml to util", () {
    run([
      "move",
      "--root",
      "./test/data/",
      "--debug",
      "yaml_me.dart",
      "util/yaml_me.dart"
    ]);
  });

  test("Move Yaml from util", () {
    run([
      "move",
      "--root",
      "./test/data/",
      "--debug",
      "util/yaml_me.dart",
      "yaml_me.dart"
    ]);
  });

  test("Move Service Locator", () {
    run([
      "move",
      "--root",
      "/home/bsutton/git/squarephone_app",
      "--debug",
      "service_locator.dart",
      "app/service_locator.dart"
    ]);
  });
}

void run(List<String> arguments) {
  CommandRunner<void> runner =
      CommandRunner("drtimport", "dart import management");

  runner.addCommand(MoveCommand());
  runner.addCommand(PatchCommand());

  runner.run(arguments);
}
