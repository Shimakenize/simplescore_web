import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';

void main() {
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
  State<SetupScreen> createState() => _SetupScreenState(); }

class _SetupScreenState extends State<SetupScreen> {
  final _teamAController = TextEditingController(text: 'Team A');
  final _teamBController = TextEditingController(text: 'Team B');

  int _halfMinutes = 20;
  bool _hasHalftime = true;
  int _halftimeBreakMinutes = 5;

  @override
  void dispose() {
    _teamAController.dispose();
    _teamBController.dispose();
    super.dispose();
  }

  void _startMatch() {
    final teamA = _teamAController.text.trim().isEmpty
        ? 'Team A'
        : _teamAController.text.trim();
    final teamB = _teamBController.text.trim().isEmpty
        ? 'Team B'
        : _teamBController.text.trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchScreen(
          teamA: teamA,
          teamB: teamB,
          halfMinutes: _halfMinutes,
          hasHalftime: _hasHalftime,
          halftimeBreakMinutes: _halftimeBreakMinutes,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                  TextField(
                    controller: _teamAController,
                    decoration: const InputDecoration(labelText: 'Team A'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _teamBController,
                    decoration: const InputDecoration(labelText: 'Team B'),
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
                  const SizedBox(height: 12),
                  SwitchListTile(
                    value: _hasHalftime,
                    onChanged: (v) => setState(() => _hasHalftime = v),
                    title: const Text('Halftime'),
                  ),
                  if (_hasHalftime) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Expanded(child: Text('Halftime break (minutes)')),
                        DropdownButton<int>(
                          value: _halftimeBreakMinutes,
                          items: const [1, 3, 5, 8, 10, 15]
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
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _startMatch,
                      child: const Text('Start'),
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
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState(); }

class _MatchScreenState extends State<MatchScreen> {
  Timer? _timer;
  bool _running = false;

  MatchPhase _phase = MatchPhase.firstHalf;

  // 現在フェーズの経過秒
  int _elapsedInPhaseSec = 0;

  // フェーズ終了時に確定させる（手動遷移のため）
  int? _firstHalfElapsedSec;
  int? _halftimeElapsedSec;
  int? _secondHalfElapsedSec;
  int? _extraFirstHalfElapsedSec;
  int? _extraSecondHalfElapsedSec;

  int _scoreA = 0;
  int _scoreB = 0;

  // PKは通常スコアとは別管理
  int _pkA = 0;
  int _pkB = 0;

  // events:
  // {
  //  tGlobal:int, tPhase:int,
  //  phase:String("前半"/"後半"/"延長前半"/"延長後半"),
  //  team:"A"/"B",
  //  playerNo:int,
  //  playerName:String
  // }
  final List<Map<String, dynamic>> _events = [];

  // 延長は固定（シンプル版）
  static const int _extraMinutes = 5;

  int get _halfPlannedSec => widget.halfMinutes * 60;
  int get _breakPlannedSec => widget.halftimeBreakMinutes * 60;
  int get _extraPlannedSec => _extraMinutes * 60;

  int get _phasePlannedSec {
    switch (_phase) {
      case MatchPhase.halftime:
        return _breakPlannedSec;
      case MatchPhase.extraFirstHalf:
      case MatchPhase.extraSecondHalf:
        return _extraPlannedSec;
      case MatchPhase.penaltyShootout:
      case MatchPhase.finished:
        return 0;
      default:
        return _halfPlannedSec;
    }
  }

  int get _phaseRemainingSec => _phasePlannedSec - _elapsedInPhaseSec;

  String get _phaseLabel {
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
        return '試合終了';
    }
  }

  int get _globalElapsedSec {
    int sec = 0;

    // 前半
    sec += _firstHalfElapsedSec ??
        (_phase == MatchPhase.firstHalf ? _elapsedInPhaseSec : 0);

    // HT
    sec += _halftimeElapsedSec ??
        (_phase == MatchPhase.halftime ? _elapsedInPhaseSec : 0);

    // 後半
    sec += _secondHalfElapsedSec ??
        (_phase == MatchPhase.secondHalf ? _elapsedInPhaseSec : 0);

    // 延長前半
    sec += _extraFirstHalfElapsedSec ??
        (_phase == MatchPhase.extraFirstHalf ? _elapsedInPhaseSec : 0);

    // 延長後半
    sec += _extraSecondHalfElapsedSec ??
        (_phase == MatchPhase.extraSecondHalf ? _elapsedInPhaseSec : 0);

    // PKは時間に含めない
    return sec;
  }

  void _startTimer() {
    if (_running) return;
    if (_phase == MatchPhase.finished) return;
    if (_phase == MatchPhase.penaltyShootout) return;

    setState(() => _running = true);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedInPhaseSec++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() => _running = false);
  }

  void _resetAll() {
    _stopTimer();
    setState(() {
      _phase = MatchPhase.firstHalf;
      _elapsedInPhaseSec = 0;

      _firstHalfElapsedSec = null;
      _halftimeElapsedSec = null;
      _secondHalfElapsedSec = null;
      _extraFirstHalfElapsedSec = null;
      _extraSecondHalfElapsedSec = null;

      _scoreA = 0;
      _scoreB = 0;
      _pkA = 0;
      _pkB = 0;
      _events.clear();
    });
  }

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
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
        return '試合終了';
    }
  }

  Future<Map<String, dynamic>?> _pickScorer() async {
    int no = 0;
    String name = '';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('得点者'),
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
    if (_phase == MatchPhase.finished) return;

    // PKは専用UIで +1 する（通常入力は使わない）
    if (_phase == MatchPhase.penaltyShootout) return;

    final picked = await _pickScorer();
    if (picked == null) return;

    final no = picked['no'] as int;
    final name = (picked['name'] as String).trim();

    setState(() {
      _events.add({
        'tGlobal': _globalElapsedSec,
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

  void _undoLastGoal() {
    if (_events.isEmpty) return;
    setState(() {
      final last = _events.removeLast();
      final team = last['team'] as String;
      if (team == 'A') _scoreA = (_scoreA - 1).clamp(0, 999);
      if (team == 'B') _scoreB = (_scoreB - 1).clamp(0, 999);
    });
  }

  // ===== Step6: 前半終了 → HT画面へ =====
  Future<void> _endFirstHalf() async {
    if (_phase != MatchPhase.firstHalf) return;

    _stopTimer();
    final firstHalfSec = _elapsedInPhaseSec;

    setState(() {
      _firstHalfElapsedSec = firstHalfSec;
      _elapsedInPhaseSec = 0;

      if (widget.hasHalftime) {
        _phase = MatchPhase.halftime;
      } else {
        _phase = MatchPhase.secondHalf;
      }
    });

    if (!widget.hasHalftime) return;
    await _openHalftimeScreen();
  }

  Future<void> _openHalftimeScreen() async {
    if (_phase != MatchPhase.halftime) return;

    final firstHalfSec = _firstHalfElapsedSec ?? 0;

    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => HalftimeScreen(
          teamA: widget.teamA,
          teamB: widget.teamB,
          halftimeBreakMinutes: widget.halftimeBreakMinutes,
          firstHalfElapsedSec: firstHalfSec,
          scoreA: _scoreA,
          scoreB: _scoreB,
          events: _events,
        ),
      ),
    );

    if (!mounted) return;
    if (result == null) return; // back で戻った場合は HTのまま

    setState(() {
      _halftimeElapsedSec = result['halftimeElapsedSec'] as int;
      _scoreA = result['scoreA'] as int;
      _scoreB = result['scoreB'] as int;

      _events
        ..clear()
        ..addAll(List<Map<String, dynamic>>.from(result['events'] as List));

      _elapsedInPhaseSec = 0;
      _phase = MatchPhase.secondHalf;
    });
  }

  // ===== Step7: 後半終了（同点なら延長/PK/終了を選ぶ）=====
  Future<void> _finishSecondHalf() async {
    if (_phase != MatchPhase.secondHalf) return;

    _stopTimer();
    setState(() {
      _secondHalfElapsedSec = _elapsedInPhaseSec;
      _elapsedInPhaseSec = 0;
    });

    if (_scoreA != _scoreB) {
      _goResult();
      return;
    }

    final choice = await _showDrawDialog(
      title: '引き分けです',
      message: '延長戦、PK、または試合終了を選んでください。',
      allowOvertime: true,
      allowPK: true,
      allowEnd: true,
    );

    if (!mounted) return;

    if (choice == _DrawChoice.overtime) {
      setState(() {
        _phase = MatchPhase.extraFirstHalf;
        _elapsedInPhaseSec = 0;
      });
      return;
    }
    if (choice == _DrawChoice.pk) {
      setState(() {
        _phase = MatchPhase.penaltyShootout;
        _elapsedInPhaseSec = 0;
        _pkA = 0;
        _pkB = 0;
      });
      return;
    }

    // end または null（ダイアログ閉じた）→ ここでは「試合終了」押下の意図を尊重して Resultへ
    _goResult();
  }

  void _endExtraFirstHalf() {
    if (_phase != MatchPhase.extraFirstHalf) return;

    _stopTimer();
    setState(() {
      _extraFirstHalfElapsedSec = _elapsedInPhaseSec;
      _elapsedInPhaseSec = 0;
      _phase = MatchPhase.extraSecondHalf;
    });
  }

  Future<void> _endExtraSecondHalf() async {
    if (_phase != MatchPhase.extraSecondHalf) return;

    _stopTimer();
    setState(() {
      _extraSecondHalfElapsedSec = _elapsedInPhaseSec;
      _elapsedInPhaseSec = 0;
    });

    if (_scoreA != _scoreB) {
      _goResult();
      return;
    }

    final choice = await _showDrawDialog(
      title: '延長でも引き分けです',
      message: 'PKに進むか、試合終了を選んでください。',
      allowOvertime: false,
      allowPK: true,
      allowEnd: true,
    );

    if (!mounted) return;

    if (choice == _DrawChoice.pk) {
      setState(() {
        _phase = MatchPhase.penaltyShootout;
        _elapsedInPhaseSec = 0;
        _pkA = 0;
        _pkB = 0;
      });
      return;
    }

    _goResult();
  }

  Future<_DrawChoice?> _showDrawDialog({
    required String title,
    required String message,
    required bool allowOvertime,
    required bool allowPK,
    required bool allowEnd,
  }) {
    return showDialog<_DrawChoice>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          if (allowEnd)
            TextButton(
              onPressed: () => Navigator.pop(context, _DrawChoice.end),
              child: const Text('試合終了'),
            ),
          if (allowOvertime)
            FilledButton(
              onPressed: () => Navigator.pop(context, _DrawChoice.overtime),
              child: const Text('延長へ'),
            ),
          if (allowPK)
            FilledButton.tonal(
              onPressed: () => Navigator.pop(context, _DrawChoice.pk),
              child: const Text('PKへ'),
            ),
        ],
      ),
    );
  }

  void _pkPlus(String team) {
    if (_phase != MatchPhase.penaltyShootout) return;
    setState(() {
      if (team == 'A') _pkA++;
      if (team == 'B') _pkB++;
    });
  }

  void _finishPK() {
    if (_phase != MatchPhase.penaltyShootout) return;
    _goResult();
  }

  void _goResult() {
    setState(() => _phase = MatchPhase.finished);

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
          events: _events,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _eventsOfTeam(String team) =>
      _events.where((e) => e['team'] == team).toList();

  Widget _buildTeamEventsColumn({
    required List<Map<String, dynamic>> events,
    required bool alignRight,
  }) {
    if (events.isEmpty) {
      return Text(
        '—',
        textAlign: alignRight ? TextAlign.right : TextAlign.left,
        style: const TextStyle(color: Colors.black45),
      );
    }

    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: events.map((e) {
        final t = _fmt(e['tGlobal'] as int);
        final no = e['playerNo'] as int;
        final name = (e['playerName'] as String?)?.trim() ?? '';
        final who = name.isEmpty ? '#$no' : '#$no $name';
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            '$t  $who',
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
          ),
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scoreText = '${widget.teamA}  $_scoreA  -  $_scoreB  ${widget.teamB}';

    return Scaffold(
      appBar: AppBar(
        title: Text('Match（$_phaseLabel）'),
        actions: [
          IconButton(
            onPressed: _resetAll,
            tooltip: '全リセット',
            icon: const Icon(Icons.restart_alt),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Chip(
                        label: Text(_phaseLabel),
                        avatar: const Icon(Icons.sports_soccer, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    scoreText,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_phase == MatchPhase.penaltyShootout) ...[
                    const SizedBox(height: 6),
                    Text(
                      'PK  $_pkA  -  $_pkB',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  if (_phase != MatchPhase.penaltyShootout) ...[
                    Text(
                      '残り(目安) ${_fmt(_phaseRemainingSec)}   /   経過 ${_fmt(_elapsedInPhaseSec)}',
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FilledButton(
                          onPressed: (_running || _phase == MatchPhase.finished)
                              ? null
                              : _startTimer,
                          child: const Text('開始'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: _running ? _stopTimer : null,
                          child: const Text('停止'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: _events.isEmpty ? null : _undoLastGoal,
                          icon: const Icon(Icons.undo),
                          label: const Text('取り消し'),
                        ),
                      ],
                    ),
                  ] else ...[
                    // PK中はタイマー無し
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _events.isEmpty ? null : _undoLastGoal,
                          icon: const Icon(Icons.undo),
                          label: const Text('取り消し（通常得点のみ）'),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 12),

                  // 手動遷移ボタン（自動遷移しない）
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_phase == MatchPhase.firstHalf)
                        FilledButton.icon(
                          onPressed: _endFirstHalf,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('前半終了'),
                        ),
                      if (_phase == MatchPhase.halftime)
                        FilledButton.icon(
                          onPressed: _openHalftimeScreen,
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('HT画面'),
                        ),
                      if (_phase == MatchPhase.secondHalf)
                        FilledButton.icon(
                          onPressed: _finishSecondHalf,
                          icon: const Icon(Icons.flag),
                          label: const Text('試合終了'),
                        ),
                      if (_phase == MatchPhase.extraFirstHalf)
                        FilledButton.icon(
                          onPressed: _endExtraFirstHalf,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('延長前半終了'),
                        ),
                      if (_phase == MatchPhase.extraSecondHalf)
                        FilledButton.icon(
                          onPressed: _endExtraSecondHalf,
                          icon: const Icon(Icons.flag),
                          label: const Text('延長後半終了'),
                        ),
                      if (_phase == MatchPhase.penaltyShootout)
                        FilledButton.icon(
                          onPressed: _finishPK,
                          icon: const Icon(Icons.flag),
                          label: const Text('PK終了 → Result'),
                        ),
                    ],
                  ),

                  if (_phase == MatchPhase.penaltyShootout) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: () => _pkPlus('A'),
                              child: Text('${widget.teamA} PK+1'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: () => _pkPlus('B'),
                              child: Text('${widget.teamB} PK+1'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 通常の得点入力（PK中は無効）
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: (_phase == MatchPhase.finished ||
                            _phase == MatchPhase.penaltyShootout)
                        ? null
                        : () => _goal('A'),
                    child: Text('${widget.teamA} 得点'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: (_phase == MatchPhase.finished ||
                            _phase == MatchPhase.penaltyShootout)
                        ? null
                        : () => _goal('B'),
                    child: Text('${widget.teamB} 得点'),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Text('得点履歴（試合中）', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTeamEventsColumn(
                      events: _eventsOfTeam('A'),
                      alignRight: false,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTeamEventsColumn(
                      events: _eventsOfTeam('B'),
                      alignRight: true,
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
  State<HalftimeScreen> createState() => _HalftimeScreenState(); }

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
                    child: _eventListColumn(items: _eventsA, align: TextAlign.left),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child:
                        _eventListColumn(items: _eventsB, align: TextAlign.right),
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
  }) {
    // ★書き出し内容は変更しない（要望どおり）
    final buffer = StringBuffer();
    final score = _scoreOf(evs);

    buffer.writeln(title);
    buffer.writeln('$teamA  ${score.a} - ${score.b}  $teamB');
    buffer.writeln('経過：${_fmt(elapsedSec)}');
    buffer.writeln('');
    buffer.writeln('得点詳細（時刻順）');

    if (evs.isEmpty) {
      buffer.writeln('得点なし');
    } else {
      for (final e in evs) {
        final time = _fmt(e['tGlobal'] as int);
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
                      final time = _fmt(e['tGlobal'] as int);
                      final no = e['playerNo'] as int;
                      final name = (e['playerName'] as String?) ?? '';
                      final who = name.isEmpty ? '#$no' : '#$no $name';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('$time  $who'),
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
                      final time = _fmt(e['tGlobal'] as int);
                      final no = e['playerNo'] as int;
                      final name = (e['playerName'] as String?) ?? '';
                      final who = name.isEmpty ? '#$no' : '#$no $name';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '$time  $who',
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
    final extraEvents =
        _eventsOfPhases(['延長前半', '延長後半']); // 表示用
    final hasExtra = extraEvents.isNotEmpty ||
        extraFirstHalfElapsedSec > 0 ||
        extraSecondHalfElapsedSec > 0;

    final hasPK = (pkA + pkB) > 0;

    // 延長の経過（表示用）
    final extraElapsed = extraFirstHalfElapsedSec + extraSecondHalfElapsedSec;

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ===== Result（全体）=====
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

          // ===== 前半 / 後半 =====
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

          // ===== 延長（表示のみ）=====
          if (hasExtra) ...[
            const Divider(height: 24),
            _resultBlock(
              title: 'Result（延長：前半＋後半）',
              elapsedSec: extraElapsed,
              evs: extraEvents,
              showExport: false,
            ),
          ],

          // ===== PK（表示のみ）=====
          if (hasPK) ...[
            const Divider(height: 24),
            Card(
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
                    const Text('Result（PK）', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        '$teamA  $pkA  -  $pkB  $teamB',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        pkA == pkB
                            ? 'PK：同点'
                            : (pkA > pkB ? 'PK勝者：$teamA' : 'PK勝者：$teamB'),
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: Text(
                        '※PKは得点履歴（選手/時刻）を記録していません（簡易版）',
                        style: TextStyle(color: Colors.black45, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const SetupScreen()),
                (route) => false,
              ),
              icon: const Icon(Icons.home),
              label: const Text('Setupへ戻る'),
            ),
          ),
        ],
      ),
    );
  }
}
