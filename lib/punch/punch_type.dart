enum PunchType {
  none,
  jab,
  cross;

  String get label => switch (this) {
    PunchType.none => 'none',
    PunchType.jab => 'jab',
    PunchType.cross => 'cross',
  };
}
