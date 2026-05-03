import '../punch/punch_type.dart';

class BoxingComboGame {
  BoxingComboGame({
    List<PunchType> combo = const [
      PunchType.jab,
      PunchType.cross,
      PunchType.jab,
    ],
  }) : _combo = List.unmodifiable(combo) {
    if (_combo.isEmpty || _combo.contains(PunchType.none)) {
      throw ArgumentError('Combo must contain at least one real punch.');
    }
  }

  final List<PunchType> _combo;
  int _targetIndex = 0;
  String _feedback = 'Ready';

  List<PunchType> get combo => _combo;
  PunchType get currentTarget => _combo[_targetIndex];
  String get feedback => _feedback;

  void processPunch(PunchType punch) {
    if (punch == PunchType.none) {
      return;
    }

    final expected = currentTarget;
    if (punch != expected) {
      _feedback = 'Expected ${expected.label}, got ${punch.label}';
      return;
    }

    final completed = _targetIndex == _combo.length - 1;
    _targetIndex = completed ? 0 : _targetIndex + 1;
    _feedback = completed ? 'Combo complete' : 'Good: ${punch.label}';
  }

  void reset() {
    _targetIndex = 0;
    _feedback = 'Ready';
  }
}
