// ===== main.dart (FULL, MERGE-FREE) =====
import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'dart:js_util' as js_util;

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

class MyTeamsScreen extends StatefulWidget {
  const MyTeamsScreen({super.key});

  @override
  State<MyTeamsScreen> createState() => _MyTeamsScreenState();
}

class _MyTeamsScreenState extends State<MyTeamsScreen> {
  void _addTeam() {
    if (myTeamsCache.length >= 10) return;

    final newTeam = MyTeam(
      id: 'team_${DateTime.now().millisecondsSinceEpoch}',
      name: '',
      members: [],
    );

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => TeamEditorScreen(team: newTeam, isNew: true),
      ),
    )
        .then((_) {
      setState(() {});
    });
  }

  void _editTeam(MyTeam team) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => TeamEditorScreen(team: team, isNew: false),
      ),
    )
        .then((_) {
      setState(() {});
    });
  }

  void _deleteTeam(MyTeam team) {
    setState(() {
      myTeamsCache.removeWhere((t) => t.id == team.id);
      saveMyTeamsBestEffort();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = myTeamsCache.length < 10;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Teams'),
        actions: [
          IconButton(
            onPressed: canAdd ? _addTeam : null,
            icon: const Icon(Icons.add),
            tooltip: 'Add team',
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: myTeamsCache.length + (canAdd ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (canAdd && index == myTeamsCache.length) {
            return Card(
              child: ListTile(
                title: const Text('Add new team'),
                subtitle: const Text('Up to 10 teams'),
                trailing: const Icon(Icons.add),
                onTap: _addTeam,
              ),
            );
          }

          final team = myTeamsCache[index];
          final displayName =
              team.name.trim().isEmpty ? '(Unnamed team)' : team.name.trim();

          return Card(
            child: ListTile(
              title: Text(displayName),
              subtitle: Text('Members: ${team.members.length}'),
              onTap: () => _editTeam(team),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteTeam(team),
                tooltip: 'Delete',
              ),
            ),
          );
        },
      ),
    );
  }
}

class TeamEditorScreen extends StatefulWidget {
  final MyTeam team;
  final bool isNew;

  const TeamEditorScreen({
    super.key,
    required this.team,
    required this.isNew,
  });

  @override
  State<TeamEditorScreen> createState() => _TeamEditorScreenState();
}

class _TeamEditorScreenState extends State<TeamEditorScreen> {
  late final TextEditingController _teamNameController;

  final List<TextEditingController> _numberControllers = [];
  final List<TextEditingController> _nameControllers = [];

  @override
  void initState() {
    super.initState();

    _teamNameController = TextEditingController(text: widget.team.name);

    for (final m in widget.team.members) {
      _numberControllers.add(TextEditingController(text: '${m.number}'));
      _nameControllers.add(TextEditingController(text: m.name));
    }

    _ensureMinRows(12);
  }

  void _ensureMinRows(int min) {
    while (_numberControllers.length < min) {
      _numberControllers.add(TextEditingController());
      _nameControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    for (final c in _numberControllers) {
      c.dispose();
    }
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _numberControllers.add(TextEditingController());
      _nameControllers.add(TextEditingController());
    });
  }

  void _save() {
    final name = _teamNameController.text.trim();

    final List<TeamMember> members = [];
    final seenNumbers = <int>{};

    for (int i = 0; i < _numberControllers.length; i++) {
      final numText = _numberControllers[i].text.trim();
      final playerName = _nameControllers[i].text.trim();

      if (numText.isEmpty && playerName.isEmpty) continue;

      final n = int.tryParse(numText);
      if (n == null || n < 0 || n > 99) continue;
      if (playerName.isEmpty) continue;

      if (seenNumbers.contains(n)) continue;
      seenNumbers.add(n);

      members.add(TeamMember(number: n, name: playerName));
    }

    final updated = MyTeam(
      id: widget.team.id,
      name: name,
      members: members,
    );

    setState(() {
      if (widget.isNew) {
        if (myTeamsCache.length < 10) {
          myTeamsCache.add(updated);
        }
      } else {
        final idx = myTeamsCache.indexWhere((t) => t.id == widget.team.id);
        if (idx >= 0) {
          myTeamsCache[idx] = updated;
        }
      }
      saveMyTeamsBestEffort();
    });

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New Team' : 'Edit Team'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _teamNameController,
            decoration: const InputDecoration(
              labelText: 'Team name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Members (No. / Name)')),
              IconButton(
                onPressed: _addRow,
                icon: const Icon(Icons.add),
                tooltip: 'Add row',
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_numberControllers.length, (i) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _numberControllers[i],
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'No.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _nameControllers[i],
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
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
    if (teamsRaw is! List) {
      myTeamsCache = [];
      return;
    }

    final List<MyTeam> teams = [];
    for (final t in teamsRaw) {
      final team = MyTeam.tryFromJson(t);
      if (team != null) teams.add(team);
    }

    // Max 10 teams
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

Map<String, dynamic>? latestMatchResult;

void loadLatestMatchResult() {
  try {
    final jsonString = html.window.localStorage['latest_match_result'];
    if (jsonString == null) return;

    final decoded = jsonDecode(jsonString);
    if (decoded is Map) {
      latestMatchResult = decoded.map((k, v) => MapEntry('$k', v));
    }
  } catch (_) {}
}

void saveLatestMatchResultBestEffort(Map<String, dynamic> data) {
  try {
    latestMatchResult = data;
    html.window.localStorage['latest_match_result'] = jsonEncode(data);
  } catch (_) {}
}

void main() {
  loadMyTeamsBestEffort();
  loadLatestMatchResult();
  runApp(const SimpleScoreWebApp());
}

class SimpleScoreWebApp extends StatelessWidget {
  const SimpleScoreWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simple Score Web',
      theme: ThemeData(useMaterial3: true),
      home: const SetupScreen(),
    );
  }
}

// ===============================
// Setup
// ===============================

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _teamAController = TextEditingController(text: 'Team A');
  final _teamBController = TextEditingController(text: 'Team B');

  String _teamASelectedId = '__manual__';
  String _teamBSelectedId = '__manual__';

  int _halfMinutes = 20;
  bool _hasHalftime = true;
  int _halftimeBreakMinutes = 5;

  @override
  void dispose() {
    _teamAController.dispose();
    _teamBController.dispose();
    super.dispose();
  }

  void _openMyTeams() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyTeamsScreen()))
        .then((_) => setState(() {}));
  }

  bool get _hasLatestMatch => latestMatchResult != null;

  void _openLatestMatch() {
    final m = latestMatchResult;
    if (m == null) return;

    String getStr(String key, String fallback) {
      final v = m[key];
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) return t;
      }
      return fallback;
    }

    int getInt(String key) {
      final v = m[key];
      if (v is num) return v.toInt();
      return 0;
    }

    List<Map<String, dynamic>> getEvents(String key) {
      final v = m[key];
      if (v is List) {
        return v
            .whereType<Map>()
            .map((e) => e.map((k, val) => MapEntry('$k', val)))
            .toList();
      }
      return <Map<String, dynamic>>[];
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          teamA: getStr('teamA', 'Team A'),
          teamB: getStr('teamB', 'Team B'),
          halfMinutes: 0,
          hasHalftime: false,
          halftimeBreakMinutes: 0,
          scoreA: getInt('scoreA'),
          scoreB: getInt('scoreB'),
          totalElapsedSec: getInt('totalElapsedSec'),
          firstHalfElapsedSec: getInt('firstHalfElapsedSec'),
          secondHalfElapsedSec: getInt('secondHalfElapsedSec'),
          extraFirstHalfElapsedSec: getInt('extraFirstHalfElapsedSec'),
          extraSecondHalfElapsedSec: getInt('extraSecondHalfElapsedSec'),
          pkA: getInt('pkA'),
          pkB: getInt('pkB'),
          events: getEvents('events'),
        ),
      ),
    );
  }

  void _applyTeamToController({
    required String selectedId,
    required TextEditingController controller,
  }) {
    if (selectedId == '__manual__') return;
    final team = myTeamsCache
        .where((t) => t.id == selectedId)
        .cast<MyTeam?>()
        .firstWhere((t) => t != null, orElse: () => null);
    if (team == null) return;
    final name = team.name.trim();
    if (name.isEmpty) return;
    controller.text = name;
  }

  void _startMatch() {
    final teamA = _teamAController.text.trim().isEmpty
        ? 'Team A'
        : _teamAController.text.trim();
    final teamB = _teamBController.text.trim().isEmpty
        ? 'Team B'
        : _teamBController.text.trim();

    final String? teamAId =
        (_teamASelectedId == '__manual__') ? null : _teamASelectedId;
    final String? teamBId =
        (_teamBSelectedId == '__manual__') ? null : _teamBSelectedId;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchScreen(
          teamA: teamA,
          teamB: teamB,
          teamAId: teamAId,
          teamBId: teamBId,
          halfMinutes: _halfMinutes,
          hasHalftime: _hasHalftime,
          halftimeBreakMinutes: _halftimeBreakMinutes,
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _buildTeamItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: '__manual__',
        child: Text('(manual)'),
      ),
    ];
    for (final t in myTeamsCache) {
      final name = t.name.trim();
      if (name.isEmpty) continue;
      items.add(DropdownMenuItem(value: t.id, child: Text(name)));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final teamItems = _buildTeamItems();
    final validIds = teamItems.map((e) => e.value).toSet();
    if (!validIds.contains(_teamASelectedId)) _teamASelectedId = '__manual__';
    if (!validIds.contains(_teamBSelectedId)) _teamBSelectedId = '__manual__';

    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _openMyTeams,
                      child: const Text('My Teams'),
                    ),
                  ),
                  if (_hasLatestMatch) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _openLatestMatch,
                        child: const Text('View latest match'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Text('Team A (select or type)')),
                      DropdownButton<String>(
                        value: _teamASelectedId,
                        items: teamItems,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _teamASelectedId = v;
                            _applyTeamToController(
                              selectedId: v,
                              controller: _teamAController,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _teamAController,
                    decoration: const InputDecoration(
                      labelText: 'Team A',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Text('Team B (select or type)')),
                      DropdownButton<String>(
                        value: _teamBSelectedId,
                        items: teamItems,
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _teamBSelectedId = v;
                            _applyTeamToController(
                              selectedId: v,
                              controller: _teamBController,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _teamBController,
                    decoration: const InputDecoration(
                      labelText: 'Team B',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Expanded(child: Text('Half minutes')),
                      DropdownButton<int>(
                        value: _halfMinutes,
                        items: const [10, 15, 20, 25, 30, 35, 40, 45]
                            .map((m) =>
                                DropdownMenuItem(value: m, child: Text('$m')))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _halfMinutes = v);
                        },
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Halftime'),
                    value: _hasHalftime,
                    onChanged: (v) => setState(() => _hasHalftime = v),
                  ),
                  if (_hasHalftime)
                    Row(
                      children: [
                        const Expanded(child: Text('Halftime break (min)')),
                        DropdownButton<int>(
                          value: _halftimeBreakMinutes,
                          items: const [0, 3, 5, 10, 15]
                              .map((m) =>
                                  DropdownMenuItem(value: m, child: Text('$m')))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _halftimeBreakMinutes = v);
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _startMatch,
                      child: const Text('Start Match'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===============================
// Match
// ===============================

enum MatchPhase {
  firstHalf,
  halftime,
  secondHalf,
  extraFirstHalf,
  extraSecondHalf,
  penaltyShootout,
  finished,
}

class MatchScreen extends StatefulWidget {
  final String teamA;
  final String teamB;
  final String? teamAId;
  final String? teamBId;
  final int halfMinutes;
  final bool hasHalftime;
  final int halftimeBreakMinutes;

  const MatchScreen({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.halfMinutes,
    required this.hasHalftime,
    required this.halftimeBreakMinutes,
    this.teamAId,
    this.teamBId,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  MatchPhase _phase = MatchPhase.firstHalf;

  Timer? _timer;
  bool _running = false;

  int _scoreA = 0;
  int _scoreB = 0;

  int _elapsedInPhaseSec = 0;

  int? _firstHalfElapsedSec;
  int? _halftimeElapsedSec;
  int? _secondHalfElapsedSec;
  int? _extraFirstHalfElapsedSec;
  int? _extraSecondHalfElapsedSec;

  int _pkA = 0;
  int _pkB = 0;

  final List<Map<String, dynamic>> _events = [];

  static const int _extraMinutes = 5;

  List<TeamMember> _rosterA = [];
  List<TeamMember> _rosterB = [];

  final Map<MatchPhase, bool> _phaseStartedOnce = {
    MatchPhase.firstHalf: false,
    MatchPhase.halftime: false,
    MatchPhase.secondHalf: false,
    MatchPhase.extraFirstHalf: false,
    MatchPhase.extraSecondHalf: false,
    MatchPhase.penaltyShootout: false,
    MatchPhase.finished: true,
  };

  @override
  void initState() {
    super.initState();
    _rosterA = _loadRosterForTeamId(widget.teamAId);
    _rosterB = _loadRosterForTeamId(widget.teamBId);
  }

  List<TeamMember> _loadRosterForTeamId(String? teamId) {
    if (teamId == null) return [];
    final team = myTeamsCache
        .where((t) => t.id == teamId)
        .cast<MyTeam?>()
        .firstWhere((t) => t != null, orElse: () => null);
    if (team == null) return [];
    return team.members;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _eventPhaseForLog() {
    switch (_phase) {
      case MatchPhase.firstHalf:
        return '前半';
      case MatchPhase.halftime:
        return 'HT';
      case MatchPhase.secondHalf:
        return '後半';
      case MatchPhase.extraFirstHalf:
        return '延長前半';
      case MatchPhase.extraSecondHalf:
        return '延長後半';
      case MatchPhase.penaltyShootout:
        return 'PK';
      case MatchPhase.finished:
        return '終了';
    }
  }

  int get _totalElapsedSecSoFar {
    int sum = 0;
    if (_firstHalfElapsedSec != null) sum += _firstHalfElapsedSec!;
    if (_halftimeElapsedSec != null) sum += _halftimeElapsedSec!;
    if (_secondHalfElapsedSec != null) sum += _secondHalfElapsedSec!;
    if (_extraFirstHalfElapsedSec != null) sum += _extraFirstHalfElapsedSec!;
    if (_extraSecondHalfElapsedSec != null) sum += _extraSecondHalfElapsedSec!;
    if (_phase != MatchPhase.penaltyShootout &&
        _phase != MatchPhase.finished) {
      sum += _elapsedInPhaseSec;
    }
    return sum;
  }

  void _startTicking() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedInPhaseSec++);
    });
  }

  void _startOrResumePhase(MatchPhase phase) {
    if (_running) return;
    if (phase == MatchPhase.finished) return;

    final startedOnce = _phaseStartedOnce[phase] ?? false;

    setState(() {
      _phase = phase;
      if (!startedOnce) {
        _elapsedInPhaseSec = 0;
        _phaseStartedOnce[phase] = true;
      }
      _running = true;
    });
    _startTicking();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (_running) setState(() => _running = false);
  }

  Future<Map<String, dynamic>?> _pickScorer({
    required String team,
    required List<TeamMember> roster,
  }) async {
    final noController = TextEditingController();
    final nameController = TextEditingController();
    String selected = '__manual__';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              Text('Scorer (${team == 'A' ? widget.teamA : widget.teamB})'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (roster.isNotEmpty) ...[
                DropdownButton<String>(
                  value: selected,
                  items: [
                    const DropdownMenuItem(
                      value: '__manual__',
                      child: Text('(manual)'),
                    ),
                    ...roster.map(
                      (m) => DropdownMenuItem(
                        value: '${m.number}:${m.name}',
                        child: Text('#${m.number} ${m.name}'),
                      ),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    selected = v;
                    if (v != '__manual__') {
                      final parts = v.split(':');
                      final no = int.tryParse(parts[0]) ?? 0;
                      final name =
                          parts.length > 1 ? parts.sublist(1).join(':') : '';
                      noController.text = '$no';
                      nameController.text = name;
                    }
                    (context as Element).markNeedsBuild();
                  },
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: noController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Jersey No (0-99)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final no = int.tryParse(noController.text.trim()) ?? 0;
                final clamped = no.clamp(0, 99);
                final name = nameController.text.trim();
                Navigator.pop(context, {'no': clamped, 'name': name});
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    return result;
  }

  Future<void> _goal(String team) async {
    if (_phase == MatchPhase.finished) return;
    if (_phase == MatchPhase.penaltyShootout) return;

    final roster = (team == 'A') ? _rosterA : _rosterB;
    final picked = await _pickScorer(team: team, roster: roster);
    if (picked == null) return;

    final no = picked['no'] as int;
    final name = (picked['name'] as String).trim();

    setState(() {
      _events.add({
        // 累積時間は不要なので記録しない
        'tGlobal': _totalElapsedSecSoFar,
        'tPhase': _elapsedInPhaseSec,
        'phase': _eventPhaseForLog(),
        'team': team,
        'playerNo': no,
        'playerName': name,
      });
      if (team == 'A') _scoreA++;
      if (team == 'B') _scoreB++;
    });
  }

  Widget _inMatchGoalHistoryCard() {
    final aEvents = _events.where((e) => e['team'] == 'A').toList();
    final bEvents = _events.where((e) => e['team'] == 'B').toList();

    Widget col(List<Map<String, dynamic>> items, TextAlign align) {
      if (items.isEmpty) return Text('—', textAlign: align);
      return Column(
        crossAxisAlignment:
            align == TextAlign.left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: items.map((e) {

          final t = ((e['tPhase'] as num?)?.toInt() ?? 0);
          final phase = (e['phase'] ?? '').toString().trim();
          final no = (e['playerNo'] as num).toInt();
          final name = (e['playerName'] ?? '').toString().trim();
          final who = name.isEmpty ? '#$no' : '#$no $name';
          final teamName = e['team'] == 'A' ? widget.teamA : widget.teamB;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              '${_fmt(t)}  $phase  $teamName  $who',
              textAlign: align,
            ),
          );
        }).toList(),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('得点履歴', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: col(aEvents, TextAlign.left)),
                const SizedBox(width: 12),
                Expanded(child: col(bEvents, TextAlign.right)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _finishMatch() {
    _stopTimer();
    final firstHalf = _firstHalfElapsedSec ?? 0;
    final halftime = _halftimeElapsedSec ?? 0;
    final secondHalf = _secondHalfElapsedSec ?? 0;
    final extra1 = _extraFirstHalfElapsedSec ?? 0;
    final extra2 = _extraSecondHalfElapsedSec ?? 0;
    final totalElapsed = firstHalf + halftime + secondHalf + extra1 + extra2;

    final data = <String, dynamic>{
      'teamA': widget.teamA,
      'teamB': widget.teamB,
      'scoreA': _scoreA,
      'scoreB': _scoreB,
      'totalElapsedSec': totalElapsed,
      'firstHalfElapsedSec': firstHalf,
      'secondHalfElapsedSec': secondHalf,
      'extraFirstHalfElapsedSec': extra1,
      'extraSecondHalfElapsedSec': extra2,
      'pkA': _pkA,
      'pkB': _pkB,
      'events': List<Map<String, dynamic>>.from(_events),
    };
    saveLatestMatchResultBestEffort(data);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          teamA: widget.teamA,
          teamB: widget.teamB,
          halfMinutes: widget.halfMinutes,
          hasHalftime: widget.hasHalftime,
          halftimeBreakMinutes: widget.halftimeBreakMinutes,
          scoreA: _scoreA,
          scoreB: _scoreB,
          totalElapsedSec: totalElapsed,
          firstHalfElapsedSec: firstHalf,
          secondHalfElapsedSec: secondHalf,
          extraFirstHalfElapsedSec: extra1,
          extraSecondHalfElapsedSec: extra2,
          pkA: _pkA,
          pkB: _pkB,
          events: List<Map<String, dynamic>>.from(_events),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.teamA} vs ${widget.teamB}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(widget.teamA),
                            Text('$_scoreA',
                                style: Theme.of(context).textTheme.displaySmall),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: () => _goal('A'),
                              child: const Text('+ Goal'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text(widget.teamB),
                            Text('$_scoreB',
                                style: Theme.of(context).textTheme.displaySmall),
                            const SizedBox(height: 8),
                            FilledButton(
                              onPressed: () => _goal('B'),
                              child: const Text('+ Goal'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _inMatchGoalHistoryCard(),
        ],
      ),
    );
  }
}

// ===============================
// Result
// ===============================

class ResultScreen extends StatelessWidget {
  final String teamA;
  final String teamB;
  final int halfMinutes;
  final bool hasHalftime;
  final int halftimeBreakMinutes;
  final int scoreA;
  final int scoreB;
  final int totalElapsedSec;
  final int firstHalfElapsedSec;
  final int secondHalfElapsedSec;
  final int extraFirstHalfElapsedSec;
  final int extraSecondHalfElapsedSec;
  final int pkA;
  final int pkB;
  final List<Map<String, dynamic>> events;

  const ResultScreen({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.halfMinutes,
    required this.hasHalftime,
    required this.halftimeBreakMinutes,
    required this.scoreA,
    required this.scoreB,
    required this.totalElapsedSec,
    required this.firstHalfElapsedSec,
    required this.secondHalfElapsedSec,
    required this.extraFirstHalfElapsedSec,
    required this.extraSecondHalfElapsedSec,
    required this.pkA,
    required this.pkB,
    required this.events,
  });

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<Map<String, dynamic>> _eventsOfPhases(List<String> phases) {
    return events.where((e) => phases.contains(e['phase'])).toList();
  }

  ({int a, int b}) _scoreOf(List<Map<String, dynamic>> evs) {
    int a = 0, b = 0;
    for (final e in evs) {
      if (e['team'] == 'A') a++;
      if (e['team'] == 'B') b++;
    }
    return (a: a, b: b);
  }

  void _exportText({
    required String title,
    required String fileName,
    required int elapsedSec,
    required List<Map<String, dynamic>> evs,
  }) async {
    final buffer = StringBuffer();
    final score = _scoreOf(evs);

    buffer.writeln(title);
    buffer.writeln('$teamA  ${score.a} - ${score.b}  $teamB');
    buffer.writeln('経過：${_fmt(elapsedSec)}');
    buffer.writeln('');
    buffer.writeln('得点詳細（表示と同一）');

    if (evs.isEmpty) {
      buffer.writeln('得点なし');
    } else {
      for (final e in evs) {
        //
        // 表示と完全一致：常に tPhase を使い、phase と teamName を含める
        final timeSec = ((e['tPhase'] as num?)?.toInt() ?? 0);
        final time = _fmt(timeSec);
        final phase = (e['phase'] ?? '').toString().trim();
        final teamName = e['team'] == 'A' ? teamA : teamB;
        final no = (e['playerNo'] as num).toInt();
        final name = (e['playerName'] as String?) ?? '';
        final who = name.isEmpty ? '#$no' : '#$no $name';
        buffer.writeln('$time  $phase  $teamName  $who');
      }
    }

    final text = buffer.toString();
    final bom = <int>[0xEF, 0xBB, 0xBF];
    final bytes = utf8.encode(text);
    final data = Uint8List.fromList([...bom, ...bytes]);

    final file =
        html.File([data], fileName, {'type': 'text/plain;charset=utf-8'});

    try {
      final nav = html.window.navigator;
      final canShareFiles = (js_util.getProperty(nav, 'canShare') != null) &&
          (js_util.callMethod(nav, 'canShare', [
            js_util.jsify({'files': [file]})
          ]) as bool);
      final hasShare = js_util.getProperty(nav, 'share') != null;

      if (hasShare && canShareFiles) {
        await js_util.promiseToFuture(
          js_util.callMethod(nav, 'share', [
            js_util.jsify({
              'title': 'SimpleScore',
              'text': '試合結果を共有します',
              'files': [file],
            })
          ]),
        );
        return;
      }
    } catch (_) {}

    final blob = html.Blob([data], 'text/plain;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  Widget _resultBlock({
    required String title,
    required int elapsedSec,
    required List<Map<String, dynamic>> evs,
    required bool showExport,
    VoidCallback? onExport,
  }) {
    final score = _scoreOf(evs);
    final aEvents = evs.where((e) => e['team'] == 'A').toList();
    final bEvents = evs.where((e) => e['team'] == 'B').toList();

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '$teamA  ${score.a}  -  ${score.b}  $teamB',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '経過：${_fmt(elapsedSec)}',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            if (showExport) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: FilledButton.icon(
                  onPressed: onExport,
                  icon: const Icon(Icons.download),
                  label: const Text('共有/保存'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: aEvents.map((e) {
                      //表示と同一②する為､常にtPhaseを使う
                      final time =
                          _fmt((e['tPhase'] as num?)?.toInt() ?? 0);
                      final phase = (e['phase'] ?? '').toString().trim();
                      final no = (e['playerNo'] as num).toInt();
                      final name = (e['playerName'] as String?) ?? '';
                      final who = name.isEmpty ? '#$no' : '#$no $name';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child:
                            Text('$time  $phase  $teamA  $who'),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: bEvents.map((e) {
                      final time =
                          _fmt((e['tPhase'] as num?)?.toInt() ?? 0);
                      final phase = (e['phase'] ?? '').toString().trim();
                      final no = (e['playerNo'] as num).toInt();
                      final name = (e['playerName'] as String?) ?? '';
                      final who = name.isEmpty ? '#$no' : '#$no $name';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '$time  $phase  $teamB  $who',
                          textAlign: TextAlign.right,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fullEvents = events;
    final firstHalfEvents = _eventsOfPhases(['前半']);
    final secondHalfEvents = _eventsOfPhases(['後半']);
    final extraEvents = _eventsOfPhases(['延長前半', '延長後半']);

    final hasExtra = extraEvents.isNotEmpty ||
        extraFirstHalfElapsedSec > 0 ||
        extraSecondHalfElapsedSec > 0;

    final hasPK = (pkA + pkB) > 0;
    final extraElapsed = extraFirstHalfElapsedSec + extraSecondHalfElapsedSec;

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SizedBox(
            height: 44,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home),
              label: const Text('Setupへ戻る'),
            ),
          ),
          const SizedBox(height: 8),
          _resultBlock(
            title: 'Result（試合全体）',
            elapsedSec: totalElapsedSec,
            evs: fullEvents,
            showExport: true,
            onExport: () => _exportText(
              title: 'Result（試合全体）',
              fileName: 'result_full.txt',
              elapsedSec: totalElapsedSec,
              evs: fullEvents,
            ),
          ),
          const Divider(height: 24),
          _resultBlock(
            title: 'Result（前半）',
            elapsedSec: firstHalfElapsedSec,
            evs: firstHalfEvents,
            showExport: true,
            onExport: () => _exportText(
              title: 'Result（前半）',
              fileName: 'result_1st.txt',
              elapsedSec: firstHalfElapsedSec,
              evs: firstHalfEvents,
            ),
          ),
          _resultBlock(
            title: 'Result（後半）',
            elapsedSec: secondHalfElapsedSec,
            evs: secondHalfEvents,
            showExport: true,
            onExport: () => _exportText(
              title: 'Result（後半）',
              fileName: 'result_2nd.txt',
              elapsedSec: secondHalfElapsedSec,
              evs: secondHalfEvents,
            ),
          ),
          if (hasExtra) ...[
            const Divider(height: 24),
            _resultBlock(
              title: 'Result（延長）',
              elapsedSec: extraElapsed,
              evs: extraEvents,
              showExport: true,
              onExport: () => _exportText(
                title: 'Result（延長）',
                fileName: 'result_extra.txt',
                elapsedSec: extraElapsed,
                evs: extraEvents,
              ),
            ),
          ],
          if (hasPK) ...[
            const Divider(height: 24),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Result（PK）', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Text(
                      '$teamA  $pkA  -  $pkB  $teamB',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
