import 'dart:convert';
import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';

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
    // Ignore any errors (best-effort)
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
  } catch (_) {
    // Ignore any errors (best-effort)
  }
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
  } catch (_) {
    // Ignore any errors (best-effort)
  }
}

void saveLatestMatchResultBestEffort(Map<String, dynamic> data) {
  try {
    // Update in-memory cache first (even if storage fails)
    latestMatchResult = data;

    final jsonString = jsonEncode(data);
    html.window.localStorage['latest_match_result'] = jsonString;
  } catch (_) {
    // Ignore any errors (best-effort)
  }
}

void main() {
  // Startup-only load (best-effort)
  loadMyTeamsBestEffort();

  // REGRESSION FIX: Step7 8.2 silent load for latest_match_result
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
        .then((_) {
      // teams may have changed; keep UI in sync
      setState(() {});
    });
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

    // ResultScreenは match options を使っていないため、ここはダミーでOK（UI非変更）
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

      items.add(
        DropdownMenuItem(
          value: t.id,
          child: Text(name),
        ),
      );
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final teamItems = _buildTeamItems();

    // If selected team was deleted, fall back to manual
    final validIds = teamItems.map((e) => e.value).toSet();
    if (!validIds.contains(_teamASelectedId)) _teamASelectedId = '__manual__';
    if (!validIds.contains(_teamBSelectedId)) _teamBSelectedId = '__manual__';

    return Scaffold(
      appBar: AppBar(title: const Text('設定画面')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // My Teams
                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _openMyTeams,
                      child: const Text('My Teams'),
                    ),
                  ),

                  // REGRESSION FIX: Step7 8.3 manual review button
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

                  // Team A selector + input
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

                  // Team B selector + input
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
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text('$m'),
                              ),
                            )
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
                              .map(
                                (m) => DropdownMenuItem(
                                  value: m,
                                  child: Text('$m'),
                                ),
                              )
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
          final displayName = team.name.trim().isEmpty ? '(Unnamed team)' : team.name.trim();
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

  // Simple row editors
  final List<TextEditingController> _numberControllers = [];
  final List<TextEditingController> _nameControllers = [];

  @override
  void initState() {
    super.initState();

    _teamNameController = TextEditingController(text: widget.team.name);

    // seed from existing members
    for (final m in widget.team.members) {
      _numberControllers.add(TextEditingController(text: '${m.number}'));
      _nameControllers.add(TextEditingController(text: m.name));
    }

    // provide some empty rows for convenience
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
    // Best-effort parse: ignore invalid/empty rows
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

      // Best-effort uniqueness: keep first, ignore duplicates
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
        // Add new (max 10)
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


enum MatchPhase {
  firstHalf,
  halftime,
  secondHalf,
  extraFirstHalf, // 延長前半
  extraSecondHalf, // 延長後半
  penaltyShootout, // PK
  finished,
}

enum _DrawChoice { overtime, pk, end }


class MatchScreen extends StatefulWidget {
  final String teamA;
  final String teamB;

  // NEW: link to My Teams roster (optional)
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

  int _globalElapsedSec = 0;
  int _elapsedInPhaseSec = 0;

  int? _firstHalfElapsedSec;
  int? _secondHalfElapsedSec;

  // Step7追加（延長対応）
  int? _extraFirstHalfElapsedSec;
  int? _extraSecondHalfElapsedSec;

  // PK対応
  int _pkA = 0;
  int _pkB = 0;

  final List<Map<String, dynamic>> _events = [];

  // 延長は固定（シンプル版）
  static const int _extraMinutes = 5;

  // rosters from My Teams (optional)
  List<TeamMember> _rosterA = [];
  List<TeamMember> _rosterB = [];

  String get _phaseLabel {
    switch (_phase) {
      case MatchPhase.firstHalf:
        return 'First Half';
      case MatchPhase.halftime:
        return 'Half Time';
      case MatchPhase.secondHalf:
        return 'Second Half';
      case MatchPhase.extraFirstHalf:
        return 'Extra 1st Half';
      case MatchPhase.extraSecondHalf:
        return 'Extra 2nd Half';
      case MatchPhase.penaltyShootout:
        return 'Penalty Shootout';
      case MatchPhase.finished:
        return 'Match End';
    }
  }

  int get _phasePlannedSec {
    if (_phase == MatchPhase.firstHalf) return widget.halfMinutes * 60;
    if (_phase == MatchPhase.secondHalf) return widget.halfMinutes * 60;
    if (_phase == MatchPhase.halftime) return widget.halftimeBreakMinutes * 60;
    if (_phase == MatchPhase.extraFirstHalf) return _extraMinutes * 60;
    if (_phase == MatchPhase.extraSecondHalf) return _extraMinutes * 60;
    return 0;
  }

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

  void _startTimer() {
    if (_running) return;
    setState(() => _running = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _globalElapsedSec++;
        _elapsedInPhaseSec++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (_running) setState(() => _running = false);
  }

  void _resetMatch() {
    _stopTimer();
    setState(() {
      _phase = MatchPhase.firstHalf;
      _scoreA = 0;
      _scoreB = 0;
      _globalElapsedSec = 0;
      _elapsedInPhaseSec = 0;

      _firstHalfElapsedSec = null;
      _secondHalfElapsedSec = null;
      _extraFirstHalfElapsedSec = null;
      _extraSecondHalfElapsedSec = null;

      _pkA = 0;
      _pkB = 0;

      _events.clear();
    });
  }

  String _fmt(int sec) {
    final m = sec ~/ 60;
    final s = sec % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _canUsePhaseTimer {
    return _phase == MatchPhase.firstHalf ||
        _phase == MatchPhase.secondHalf ||
        _phase == MatchPhase.extraFirstHalf ||
        _phase == MatchPhase.extraSecondHalf;
  }

  String _phaseStartLabel() {
    final base = switch (_phase) {
      MatchPhase.firstHalf => '前半',
      MatchPhase.secondHalf => '後半',
      MatchPhase.extraFirstHalf => '延長前半',
      MatchPhase.extraSecondHalf => '延長後半',
      _ => '',
    };
    if (base.isEmpty) return '開始';
    if (_elapsedInPhaseSec == 0) return '${base}開始';
    return '${base}再開';
  }

  String _eventPhaseForLog() {
    // HT中に得点入力するケースを許す → HT中は前半として記録
    switch (_phase) {
      case MatchPhase.firstHalf:
        return '前半';
      case MatchPhase.halftime:
        return '前半';
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
          title: Text('Scorer (${team == 'A' ? widget.teamA : widget.teamB})'),
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
        'tGlobal': _globalElapsedSec,
        'tPhase': _elapsedInPhaseSec,
        'phase': _eventPhaseForLog(), // ★前半/後半が入る
        'team': team,
        'playerNo': no,
        'playerName': name,
      });

      if (team == 'A') _scoreA++;
      if (team == 'B') _scoreB++;
    });
  }

  void _undoLastGoal() {
    if (_events.isEmpty) return;
    setState(() {
      final last = _events.removeLast();
      final team = last['team'] as String;
      if (team == 'A' && _scoreA > 0) _scoreA--;
      if (team == 'B' && _scoreB > 0) _scoreB--;
    });
  }

  void _endFirstHalf() {
    _stopTimer();
    setState(() {
      _firstHalfElapsedSec = _elapsedInPhaseSec;
      _phase = MatchPhase.halftime;
      _elapsedInPhaseSec = 0;
    });
  }

  void _endHalftime() {
    _stopTimer();
    setState(() {
      _phase = MatchPhase.secondHalf;
      _elapsedInPhaseSec = 0;
    });
    _startTimer();
  }

  void _endSecondHalf() {
    _stopTimer();

    if (_scoreA == _scoreB) {
      _askExtraOrPk();
      return;
    }

    setState(() {
      _secondHalfElapsedSec = _elapsedInPhaseSec;
      _phase = MatchPhase.finished;
    });

    _finishMatch();
  }

  void _askExtraOrPk() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Draw'),
        content: const Text('Proceed to Extra Time or Penalty Shootout?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _secondHalfElapsedSec = _elapsedInPhaseSec;
                _phase = MatchPhase.extraFirstHalf;
                _elapsedInPhaseSec = 0;
              });
            },
            child: const Text('Extra'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _secondHalfElapsedSec = _elapsedInPhaseSec;
                _phase = MatchPhase.penaltyShootout;
                _elapsedInPhaseSec = 0;
              });
            },
            child: const Text('PK'),
          ),
        ],
      ),
    );
  }

  void _endExtraFirstHalf() {
    _stopTimer();
    setState(() {
      _extraFirstHalfElapsedSec = _elapsedInPhaseSec;
      _phase = MatchPhase.extraSecondHalf;
      _elapsedInPhaseSec = 0;
    });
  }

  void _endExtraSecondHalf() {
    _stopTimer();
    setState(() {
      _extraSecondHalfElapsedSec = _elapsedInPhaseSec;
      _phase = MatchPhase.finished;
    });

    if (_scoreA == _scoreB) {
      setState(() {
        _phase = MatchPhase.penaltyShootout;
        _elapsedInPhaseSec = 0;
      });
      return;
    }

    _finishMatch();
  }

  void _pkGoal(String team) {
    if (_phase != MatchPhase.penaltyShootout) return;
    setState(() {
      if (team == 'A') _pkA++;
      if (team == 'B') _pkB++;
    });
  }

  void _endPkAndFinish() {
    setState(() => _phase = MatchPhase.finished);
    _finishMatch();
  }

  // ★試合中の得点履歴（前半/後半 表示）
  Widget _inMatchGoalHistoryCard() {
    final aEvents = _events.where((e) => (e['team'] ?? '') == 'A').toList();
    final bEvents = _events.where((e) => (e['team'] ?? '') == 'B').toList();

    Widget col(List<Map<String, dynamic>> items, TextAlign align) {
      if (items.isEmpty) return Text('—', textAlign: align);

      return Column(
        crossAxisAlignment:
            align == TextAlign.left ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: items.map((e) {
          final phase = (e['phase'] ?? '').toString().trim(); // 前半/後半/延長
          final tGlobal =
              (e['tGlobal'] is num) ? (e['tGlobal'] as num).toInt() : 0;
          final tPhase =
              (e['tPhase'] is num) ? (e['tPhase'] as num).toInt() : tGlobal;
          final t = (phase == '後半' || phase == '延長前半' || phase == '延長後半')
              ? tPhase
              : tGlobal;
          final no = (e['playerNo'] is num) ? (e['playerNo'] as num).toInt() : 0;
          final name = (e['playerName'] ?? '').toString().trim();
          final scorer = name.isEmpty ? '#$no' : '#$no $name';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${_fmt(t)}  $phase  $scorer', textAlign: align),
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

    // ★不具合修正：Step7 8.1 保存（遷移直前、best-effort）
    final data = <String, dynamic>{
      'teamA': widget.teamA,
      'teamB': widget.teamB,
      'scoreA': _scoreA,
      'scoreB': _scoreB,
      'totalElapsedSec': _globalElapsedSec,
      'firstHalfElapsedSec': _firstHalfElapsedSec ?? 0,
      'secondHalfElapsedSec': _secondHalfElapsedSec ?? 0,
      'extraFirstHalfElapsedSec': _extraFirstHalfElapsedSec ?? 0,
      'extraSecondHalfElapsedSec': _extraSecondHalfElapsedSec ?? 0,
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
          totalElapsedSec: _globalElapsedSec,
          firstHalfElapsedSec: _firstHalfElapsedSec ?? 0,
          secondHalfElapsedSec: _secondHalfElapsedSec ?? 0,
          extraFirstHalfElapsedSec: _extraFirstHalfElapsedSec ?? 0,
          extraSecondHalfElapsedSec: _extraSecondHalfElapsedSec ?? 0,
          pkA: _pkA,
          pkB: _pkB,
          events: List<Map<String, dynamic>>.from(_events),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phaseTimeText = _phasePlannedSec > 0
        ? '${_fmt(_elapsedInPhaseSec)} / ${_fmt(_phasePlannedSec)}'
        : _fmt(_elapsedInPhaseSec);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.teamA} vs ${widget.teamB}'),
        actions: [
          IconButton(
            onPressed: _resetMatch,
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(_phaseLabel, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text(phaseTimeText, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(widget.teamA),
                            Text('$_scoreA', style: Theme.of(context).textTheme.displaySmall),
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
                            Text('$_scoreB', style: Theme.of(context).textTheme.displaySmall),
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
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton(
                        onPressed: _undoLastGoal,
                        child: const Text('Undo'),
                      ),
                      if (_canUsePhaseTimer)
                        FilledButton(
                          onPressed: _running ? _stopTimer : _startTimer,
                          child: Text(_running ? '一時停止' : _phaseStartLabel()),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_phase == MatchPhase.firstHalf)
                    FilledButton(onPressed: _endFirstHalf, child: const Text('前半終了')),
                  if (_phase == MatchPhase.halftime)
                    FilledButton(onPressed: _endHalftime, child: const Text('後半開始')),
                  if (_phase == MatchPhase.secondHalf)
                    FilledButton(onPressed: _endSecondHalf, child: const Text('後半終了')),

                  if (_phase == MatchPhase.extraFirstHalf)
                    FilledButton(onPressed: _endExtraFirstHalf, child: const Text('延長前半終了')),
                  if (_phase == MatchPhase.extraSecondHalf)
                    FilledButton(onPressed: _endExtraSecondHalf, child: const Text('延長後半終了')),

                  if (_phase == MatchPhase.penaltyShootout) ...[
                    const SizedBox(height: 8),
                    Text('PK: ${widget.teamA} $_pkA - $_pkB ${widget.teamB}'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pkGoal('A'),
                            child: Text('+1 ${widget.teamA}'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _pkGoal('B'),
                            child: Text('+1 ${widget.teamB}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _endPkAndFinish,
                        child: const Text('PK終了 → 結果へ'),
                      ),
                    ),
                  ],
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


class HalftimeScreen extends StatefulWidget {
  final String teamA;
  final String teamB;
  final int halftimeBreakMinutes;

  // 前半終了時点の経過秒（前半の経過）
  final int firstHalfElapsedSec;

  final int scoreA;
  final int scoreB;
  final List<Map<String, dynamic>> events;

  const HalftimeScreen({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.halftimeBreakMinutes,
    required this.firstHalfElapsedSec,
    required this.scoreA,
    required this.scoreB,
    required this.events,
  });

  @override
  State<HalftimeScreen> createState() => _HalftimeScreenState();
}

class _HalftimeScreenState extends State<HalftimeScreen> {
  Timer? _timer;
  bool _running = false;
  int _htElapsedSec = 0;

  late int _scoreA;
  late int _scoreB;
  late List<Map<String, dynamic>> _events;

  @override
  void initState() {
    super.initState();
    _scoreA = widget.scoreA;
    _scoreB = widget.scoreB;
    _events = List<Map<String, dynamic>>.from(widget.events);
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

  int get _remainSec => (widget.halftimeBreakMinutes * 60) - _htElapsedSec;

  void _startTimer() {
    if (_running) return;
    setState(() => _running = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _htElapsedSec++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _running = false);
  }

  Future<Map<String, dynamic>?> _pickScorer() async {
    int no = 0;
    String name = '';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('得点者（前半の修正）'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: '背番号 (0-99)'),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final n = int.tryParse(v);
                  if (n != null) no = n.clamp(0, 99);
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: '名前（任意）'),
                onChanged: (v) => name = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, {'no': no, 'name': name}),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _goal(String team) async {
    final picked = await _pickScorer();
    if (picked == null) return;

    final no = picked['no'] as int;
    final name = (picked['name'] as String).trim();

    setState(() {
      // HT中の追加は「前半として記録」する（前半の入力忘れ調整用）
      _events.add({
        'tGlobal': widget.firstHalfElapsedSec,
        'tPhase': widget.firstHalfElapsedSec,
        'phase': '前半',
        'team': team,
        'playerNo': no,
        'playerName': name,
      });

      if (team == 'A') _scoreA++;
      if (team == 'B') _scoreB++;
    });
  }

  void _undoLastGoal() {
    if (_events.isEmpty) return;
    setState(() {
      final last = _events.removeLast();
      final team = last['team'] as String;
      if (team == 'A') _scoreA = (_scoreA - 1).clamp(0, 999);
      if (team == 'B') _scoreB = (_scoreB - 1).clamp(0, 999);
    });
  }

  List<Map<String, dynamic>> get _eventsA =>
      _events.where((e) => e['team'] == 'A').toList();
  List<Map<String, dynamic>> get _eventsB =>
      _events.where((e) => e['team'] == 'B').toList();

  Widget _eventListColumn({
    required List<Map<String, dynamic>> items,
    required TextAlign align,
  }) {
    if (items.isEmpty) {
      return Text(
        '—',
        textAlign: align,
        style: const TextStyle(color: Colors.black45),
      );
    }

    return Column(
      crossAxisAlignment: align == TextAlign.right
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: items.map((e) {
        final t = _fmt(e['tGlobal'] as int);
        final no = e['playerNo'] as int;
        final name = (e['playerName'] as String).trim();
        final who = name.isEmpty ? '#$no' : '#$no $name';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text('$t  $who', textAlign: align),
        );
      }).toList(),
    );
  }

  void _finishHT() {
    _stopTimer();
    Navigator.pop(context, {
      'halftimeElapsedSec': _htElapsedSec,
      'scoreA': _scoreA,
      'scoreB': _scoreB,
      'events': _events,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HT')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Chip(
                        label: Text('HT'),
                        avatar: Icon(Icons.timer, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.teamA}  $_scoreA  -  $_scoreB  ${widget.teamB}',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '残り(目安) ${_fmt(_remainSec)}   /   経過 ${_fmt(_htElapsedSec)}',
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: _running ? null : _startTimer,
                        child: const Text('HT開始'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _running ? _stopTimer : null,
                        child: const Text('HT停止'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _events.isEmpty ? null : _undoLastGoal,
                        icon: const Icon(Icons.undo),
                        label: const Text('取り消し'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _finishHT,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('HT終了 → 後半へ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => _goal('A'),
                    child: Text('${widget.teamA} 得点（前半修正）'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => _goal('B'),
                    child: Text('${widget.teamB} 得点（前半修正）'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('得点履歴（前半・修正含む）', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _eventListColumn(
                        items: _eventsA, align: TextAlign.left),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _eventListColumn(
                        items: _eventsB, align: TextAlign.right),
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

  // Step7追加（表示用）
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
    int a = 0;
    int b = 0;
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
    bool usePhaseRelativeTime = false,
    String? elapsedTextOverride,
  }) {
    // ★書き出し内容は変更しない（要望どおり）
    final buffer = StringBuffer();
    final score = _scoreOf(evs);

    buffer.writeln(title);
    buffer.writeln('$teamA  ${score.a} - ${score.b}  $teamB');
    final elapsedText = elapsedTextOverride ?? _fmt(elapsedSec);
    buffer.writeln('経過：$elapsedText');
    buffer.writeln('');
    buffer.writeln('得点詳細（時刻順）');

    if (evs.isEmpty) {
      buffer.writeln('得点なし');
    } else {
      for (final e in evs) {
        final phase = (e['phase'] ?? '').toString().trim();
        final tGlobal =
            (e['tGlobal'] is num) ? (e['tGlobal'] as num).toInt() : 0;
        final tPhase =
            (e['tPhase'] is num) ? (e['tPhase'] as num).toInt() : tGlobal;
        final isPhaseRelative =
            phase == '後半' || phase == '延長前半' || phase == '延長後半';
        final t = (usePhaseRelativeTime && isPhaseRelative) ? tPhase : tGlobal;
        final time = _fmt(t);
        final teamName = e['team'] == 'A' ? teamA : teamB;
        final no = e['playerNo'] as int;
        final name = (e['playerName'] as String?) ?? '';
        final who = name.isEmpty ? '#$no' : '#$no $name';
        buffer.writeln('$time  $teamName  $who');
      }
    }

    final text = buffer.toString();
    final blob = html.Blob([text], 'text/plain');
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
    bool usePhaseRelativeTime = false,
    String? elapsedTextOverride,
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
                '経過：${elapsedTextOverride ?? _fmt(elapsedSec)}',
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
                  label: const Text('書き出し'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Team A
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: aEvents.map((e) {
                      final phase = (e['phase'] ?? '').toString().trim(); // 前半/後半/延長
                      final tGlobal =
                          (e['tGlobal'] is num) ? (e['tGlobal'] as num).toInt() : 0;
                      final tPhase =
                          (e['tPhase'] is num) ? (e['tPhase'] as num).toInt() : tGlobal;
                      final isPhaseRelative =
                          phase == '後半' || phase == '延長前半' || phase == '延長後半';
                      final t = (usePhaseRelativeTime && isPhaseRelative)
                          ? tPhase
                          : tGlobal;
                      final time = _fmt(t);
                      final no = e['playerNo'] as int;
                      final name = (e['playerName'] as String?) ?? '';
                      final who = name.isEmpty ? '#$no' : '#$no $name';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('$time  $phase  $who'),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 16),
                // Team B
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: bEvents.map((e) {
                      final phase = (e['phase'] ?? '').toString().trim(); // 前半/後半/延長
                      final tGlobal =
                          (e['tGlobal'] is num) ? (e['tGlobal'] as num).toInt() : 0;
                      final tPhase =
                          (e['tPhase'] is num) ? (e['tPhase'] as num).toInt() : tGlobal;
                      final isPhaseRelative =
                          phase == '後半' || phase == '延長前半' || phase == '延長後半';
                      final t = (usePhaseRelativeTime && isPhaseRelative)
                          ? tPhase
                          : tGlobal;
                      final time = _fmt(t);
                      final no = e['playerNo'] as int;
                      final name = (e['playerName'] as String?) ?? '';
                      final who = name.isEmpty ? '#$no' : '#$no $name';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '$time  $phase  $who',
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
          // ★デグレ修正：Setupへ戻る明示ボタン
          SizedBox(
            height: 44,
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.home),
              label: const Text('設定画面へ戻る'),
            ),
          ),

          const SizedBox(height: 8),

          _resultBlock(
            title: 'Result（試合全体）',
            elapsedSec: totalElapsedSec,
            evs: fullEvents,
            showExport: true,
            usePhaseRelativeTime: true,
            onExport: () => _exportText(
              title: 'Result（試合全体）',
              fileName: 'result_full.txt',
              elapsedSec: totalElapsedSec,
              evs: fullEvents,
              usePhaseRelativeTime: true,
            ),
          ),

          const Divider(height: 24),

          _resultBlock(
            title: 'Result（前半）',
            elapsedSec: firstHalfElapsedSec,
            evs: firstHalfEvents,
            showExport: true,
            elapsedTextOverride: _fmt(firstHalfElapsedSec),
            onExport: () => _exportText(
              title: 'Result（前半）',
              fileName: 'result_1st.txt',
              elapsedSec: firstHalfElapsedSec,
              evs: firstHalfEvents,
              elapsedTextOverride: _fmt(firstHalfElapsedSec),
            ),
          ),
          _resultBlock(
            title: 'Result（後半）',
            elapsedSec: secondHalfElapsedSec,
            evs: secondHalfEvents,
            showExport: true,
            usePhaseRelativeTime: true,
            elapsedTextOverride: _fmt(secondHalfElapsedSec),
            onExport: () => _exportText(
              title: 'Result（後半）',
              fileName: 'result_2nd.txt',
              elapsedSec: secondHalfElapsedSec,
              evs: secondHalfEvents,
              usePhaseRelativeTime: true,
              elapsedTextOverride: _fmt(secondHalfElapsedSec),
            ),
          ),

          if (hasExtra) ...[
            const Divider(height: 24),
            _resultBlock(
              title: 'Result（延長）',
              elapsedSec: extraElapsed,
              evs: extraEvents,
              showExport: true,
              usePhaseRelativeTime: true,
              elapsedTextOverride:
                  '前半 ${_fmt(extraFirstHalfElapsedSec)} / 後半 ${_fmt(extraSecondHalfElapsedSec)}',
              onExport: () => _exportText(
                title: 'Result（延長）',
                fileName: 'result_extra.txt',
                elapsedSec: extraElapsed,
                evs: extraEvents,
                usePhaseRelativeTime: true,
                elapsedTextOverride:
                    '前半 ${_fmt(extraFirstHalfElapsedSec)} / 後半 ${_fmt(extraSecondHalfElapsedSec)}',
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
