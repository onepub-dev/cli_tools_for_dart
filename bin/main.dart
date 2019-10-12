import 'package:args/command_runner.dart';
import 'package:square_cli/move_command.dart';

import 'package:square_cli/patch_command.dart';

void main(List<String> arguments) {
  CommandRunner<void> runner =
      CommandRunner("drtimport", "dart import management");

  runner.addCommand(MoveCommand());
  runner.addCommand(PatchCommand());

  runner.run(arguments);
}
