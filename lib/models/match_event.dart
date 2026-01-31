part of simplescore_web_app;

// ===============================
// Match Events (Model)
// ===============================

abstract class MatchEvent {
  final int timeSeconds; // seconds from match start

  MatchEvent(this.timeSeconds);

  Map<String, dynamic> toJson();

  static MatchEvent? tryFromJson(dynamic json) {
    if (json is! Map) return null;
    final type = json['type'];
    final timeRaw = json['timeSeconds'];

    if (timeRaw is! int) return null;

    switch (type) {
      case 'goal':
        return GoalEvent.tryFromJson(json);
      default:
        return null;
    }
  }
}

class GoalEvent extends MatchEvent {
  final String teamId;
  final int playerNumber;
  final String playerName;

  GoalEvent({
    required int timeSeconds,
    required this.teamId,
    required this.playerNumber,
    required this.playerName,
  }) : super(timeSeconds);

  @override
  Map<String, dynamic> toJson() => {
        'type': 'goal',
        'timeSeconds': timeSeconds,
        'teamId': teamId,
        'playerNumber': playerNumber,
        'playerName': playerName,
      };

  static GoalEvent? tryFromJson(dynamic json) {
    if (json is! Map) return null;

    final timeRaw = json['timeSeconds'];
    final teamIdRaw = json['teamId'];
    final numberRaw = json['playerNumber'];
    final nameRaw = json['playerName'];

    if (timeRaw is! int) return null;
    if (teamIdRaw is! String || teamIdRaw.trim().isEmpty) return null;
    if (numberRaw is! int || numberRaw < 0 || numberRaw > 99) return null;
    if (nameRaw is! String || nameRaw.trim().isEmpty) return null;

    return GoalEvent(
      timeSeconds: timeRaw,
      teamId: teamIdRaw,
      playerNumber: numberRaw,
      playerName: nameRaw.trim(),
    );
  }
}
