import 'package:boxing_trainer_app/game/boxing_combo_game.dart';
import 'package:boxing_trainer_app/punch/punch_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('advances through the default jab cross jab combo', () {
    final game = BoxingComboGame();

    expect(game.currentTarget, PunchType.jab);

    game.processPunch(PunchType.jab);
    expect(game.currentTarget, PunchType.cross);
    expect(game.feedback, 'Good: jab');

    game.processPunch(PunchType.cross);
    expect(game.currentTarget, PunchType.jab);
    expect(game.feedback, 'Good: cross');
  });

  test('keeps current target and reports feedback for wrong punch', () {
    final game = BoxingComboGame();

    game.processPunch(PunchType.cross);

    expect(game.currentTarget, PunchType.jab);
    expect(game.feedback, 'Expected jab, got cross');
  });

  test('ignores none punches', () {
    final game = BoxingComboGame();

    game.processPunch(PunchType.none);

    expect(game.currentTarget, PunchType.jab);
    expect(game.feedback, 'Ready');
  });

  test('restarts combo after completion', () {
    final game = BoxingComboGame();

    game
      ..processPunch(PunchType.jab)
      ..processPunch(PunchType.cross)
      ..processPunch(PunchType.jab);

    expect(game.currentTarget, PunchType.jab);
    expect(game.feedback, 'Combo complete');
  });

  test('reset returns to the first target', () {
    final game = BoxingComboGame();

    game
      ..processPunch(PunchType.jab)
      ..reset();

    expect(game.currentTarget, PunchType.jab);
    expect(game.feedback, 'Ready');
  });
}
