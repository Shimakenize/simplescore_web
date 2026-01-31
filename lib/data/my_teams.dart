part of simplescore_web_app;

// ===============================
// My Teams (localStorage)
// ===============================

const String _kMyTeamsStorageKey = 'my_teams_v1';

List<MyTeam> myTeamsCache = [];

class TeamMember {
  final int number; // 0-99
  final String name;

  TeamMember({required this.number, required this.name});

  Map<String, dynamic> toJson() => {
        'number': number,
        'name': name,
      };

  static TeamMember? tryFromJson(dynamic json) {
    if (json is! Map) return null;
    final numberRaw = json['number'];
    final nameRaw = json['name'];

    final int? number = (numberRaw is int)
        ? numberRaw
        : (numberRaw is num)
            ? numberRaw.toInt()
            : null;

    final String? name = (nameRaw is String) ? nameRaw : null;

    if (number == null || number < 0 || number > 99) return null;
    if (name == null) return null;

    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;

    return TeamMember(number: number, name: trimmed);
  }
}

class MyTeam {
  final String id; // stable identifier
  final String name;
  final List<TeamMember> members;

  MyTeam({required this.id, required this.name, required this.members});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'members': members.map((m) => m.toJson()).toList(),
      };

  static MyTeam? tryFromJson(dynamic json) {
    if (json is! Map) return null;
    final idRaw = json['id'];
    final nameRaw = json['name'];
    final membersRaw = json['members'];

    if (idRaw is! String || idRaw.trim().isEmpty) return null;
    if (nameRaw is! String) return null;
    final name = nameRaw.trim();

    final List<TeamMember> members = [];
    if (membersRaw is List) {
      for (final m in membersRaw) {
        final member = TeamMember.tryFromJson(m);
        if (member != null) members.add(member);
      }
    }

    return MyTeam(id: idRaw, name: name, members: members);
  }
}

void loadMyTeamsBestEffort() {
  try {
    final jsonString = html.window.localStorage[_kMyTeamsStorageKey];
    if (jsonString == null) {
      myTeamsCache = [];
      return;
    }

    final decoded = jsonDecode(jsonString);
    if (decoded is! Map) {
      myTeamsCache = [];
      return;
    }

    final teamsRaw = decoded['teams'];
    final List<MyTeam> teams = [];
    if (teamsRaw is List) {
      for (final t in teamsRaw) {
        final team = MyTeam.tryFromJson(t);
        if (team != null) teams.add(team);
      }
    }
    myTeamsCache = teams.take(10).toList();
  } catch (_) {
    myTeamsCache = [];
  }
}

void saveMyTeamsBestEffort() {
  try {
    final payload = {
      'version': 1,
      'teams': myTeamsCache.take(10).map((t) => t.toJson()).toList(),
    };
    html.window.localStorage[_kMyTeamsStorageKey] = jsonEncode(payload);
  } catch (_) {}
}
