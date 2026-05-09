enum InterEventWeatherType { rain, frost, dry }

class InterEventWeatherEvent {
  final InterEventWeatherType type;
  final DateTime from;
  final DateTime to;
  final double? valueMm;

  const InterEventWeatherEvent({
    required this.type,
    required this.from,
    required this.to,
    this.valueMm,
  });
}

class InterEventWeatherDto {
  final List<InterEventWeatherEvent> events;
  const InterEventWeatherDto({required this.events});
  bool get isEmpty => events.isEmpty;
  bool get isNotEmpty => events.isNotEmpty;
}
