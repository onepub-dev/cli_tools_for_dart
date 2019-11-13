import 'package:args/command_runner.dart';
import 'package:square_cli/move_command.dart';

import 'package:square_cli/patch_command.dart';
import 'package:square_cli/pubspec.dart';

void main(List<String> arguments) async {
  PubSpec pubSpec = PubSpec();
  await pubSpec.load();
  String version = pubSpec.version;

  CommandRunner<void> runner =
      CommandRunner("drtimport", "dart import management version: ${version}");

  runner.addCommand(MoveCommand());
  runner.addCommand(PatchCommand());

  await runner.run(arguments);
}
