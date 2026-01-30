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
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _teamAController = TextEditingController(text: 'Team A');
  final _teamBController = TextEditingController(text: 'Team B');

  int _halfMinutes = 10;
  bool _hasHalftime = true;
  int _halftimeBreakMinutes = 5;

  @override
  void dispose() {
    _teamAController.dispose();
    _teamBController.dispose();
    super.dispose();
  }

  void _start() {
    final a =
        _teamAController.text.trim().isEmpty ? 'Team A' : _teamAController.text.trim();
    final b =
        _teamBController.text.trim().isEmpty ? 'Team B' : _teamBController.text.trim();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchScreen(
          teamA: a,
          teamB: b,
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
      appBar: AppBar(title: const Text('Simple Score（Prototype）')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('チーム名', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          TextField(
            controller: _teamAController,
            decoration: const InputDecoration(labelText: 'Team A'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _teamBController,
            decoration: const InputDecoration(labelText: 'Team B'),
          ),
          const SizedBox(height: 24),
          const Text('前半（分）', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _halfMinutes,
            items: const [
              DropdownMenuItem(value: 5, child: Text('5')),
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 15, child: Text('15')),
              DropdownMenuItem(value: 20, child: Text('20')),
              DropdownMenuItem(value: 30, child: Text('30')),
              DropdownMenuItem(value: 45, child: Text('45')),
            ],
            onChanged: (v) => setState(() => _halfMinutes = v ?? 10),
            decoration: const InputDecoration(labelText: 'Half duration'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: _hasHalftime,
            onChanged: (v) => setState(() => _hasHalftime = v),
            title: const Text('ハーフタイムあり'),
          ),
          if (_hasHalftime) ...[
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              value: _halftimeBreakMinutes,
              items: const [
                DropdownMenuItem(value: 3, child: Text('3')),
                DropdownMenuItem(value: 5, child: Text('5')),
                DropdownMenuItem(value: 10, child: Text('10')),
              ],
              onChanged: (v) => setState(() => _halftimeBreakMinutes = v ?? 5),
              decoration: const InputDecoration(labelText: 'ハーフタイム休憩（分）'),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('試合開始'),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '※ Web版は画面を閉じる/バックグラウンドにするとタイマーが止まりやすいです',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

enum MatchPhase { firstHalf, halftime, secondHalf, finished }

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
  State<MatchScreen> createState() => _MatchScreenState();
}

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

  int _scoreA = 0;
  int _scoreB = 0;

  // events:
  // {
  //  tGlobal:int, tPhase:int,
  //  phase:String("前半"/"後半"),
  //  team:"A"/"B",
  //  playerNo:int,
  //  playerName:String
  // }
  final List<Map<String, dynamic>> _events = [];

  int get _halfPlannedSec => widget.halfMinutes * 60;
  int get _breakPlannedSec => widget.halftimeBreakMinutes * 60;

  int get _phasePlannedSec {
    switch (_phase) {
      case MatchPhase.firstHalf:
        return _halfPlannedSec;
      case MatchPhase.halftime:
        return _breakPlannedSec;
      case MatchPhase.secondHalf:
        return _halfPlannedSec;
      case MatchPhase.finished:
        return 0;
    }
  }

  int get _remainSec => (_phasePlannedSec - _elapsedInPhaseSec).clamp(0, _phasePlannedSec);

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _phaseLabel {
    switch (_phase) {
      case MatchPhase.firstHalf:
        return '前半';
      case MatchPhase.halftime:
        return 'HT';
      case MatchPhase.secondHalf:
        return '後半';
      case MatchPhase.finished:
        return '終了';
    }
  }

  // ★自動遷移はしない：あくまで表示用のグローバル経過
  int get _globalElapsedSec {
    final fh = _firstHalfElapsedSec ?? (_phase == MatchPhase.firstHalf ? _elapsedInPhaseSec : 0);
    final ht = widget.hasHalftime
        ? (_halftimeElapsedSec ?? (_phase == MatchPhase.halftime ? _elapsedInPhaseSec : 0))
        : 0;
    final sh = _secondHalfElapsedSec ?? (_phase == MatchPhase.secondHalf ? _elapsedInPhaseSec : 0);

    // まだ到達してないフェーズは 0 として扱う
    if (_phase == MatchPhase.firstHalf) return _elapsedInPhaseSec;
    if (_phase == MatchPhase.halftime) return fh + _elapsedInPhaseSec;
    if (_phase == MatchPhase.secondHalf) return fh + ht + _elapsedInPhaseSec;
    // finished
    return fh + ht + sh;
  }

  void _startTimer() {
    if (_running) return;
    if (_phase == MatchPhase.finished) return;

    setState(() => _running = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedInPhaseSec++);
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _running = false);
  }

  void _resetAll() {
    _stopTimer();
    setState(() {
      _phase = MatchPhase.firstHalf;
      _elapsedInPhaseSec = 0;

      _firstHalfElapsedSec = null;
      _halftimeElapsedSec = null;
      _secondHalfElapsedSec = null;

      _scoreA = 0;
      _scoreB = 0;
      _events.clear();
    });
  }

  // ===== 手動遷移 =====

  void _endFirstHalf() {
    if (_phase != MatchPhase.firstHalf) return;

    _stopTimer();
    setState(() {
      _firstHalfElapsedSec = _elapsedInPhaseSec;
      _elapsedInPhaseSec = 0;

      if (widget.hasHalftime) {
        _phase = MatchPhase.halftime;
      } else {
        _phase = MatchPhase.secondHalf;
      }
    });
  }

  void _endHalftime() {
    if (_phase != MatchPhase.halftime) return;

    _stopTimer();
    setState(() {
      _halftimeElapsedSec = _elapsedInPhaseSec;
      _elapsedInPhaseSec = 0;
      _phase = MatchPhase.secondHalf;
    });
  }

  void _finishMatch() {
    if (_phase != MatchPhase.secondHalf) return;

    _stopTimer();
    setState(() {
      _secondHalfElapsedSec = _elapsedInPhaseSec;
      _phase = MatchPhase.finished;
    });

    final totalElapsed = _globalElapsedSec;

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
          // per half
          firstHalfElapsedSec: _firstHalfElapsedSec ?? 0,
          secondHalfElapsedSec: _secondHalfElapsedSec ?? 0,
          events: List<Map<String, dynamic>>.from(_events),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>?> _pickScorer() async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.75,
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('得点者（背番号＋名前）', style: TextStyle(fontSize: 16)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: '名前（任意）',
                        hintText: '例：Takumi',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.6,
                      ),
                      itemCount: 100,
                      itemBuilder: (_, i) {
                        return OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop({
                            'no': i,
                            'name': nameCtrl.text.trim(),
                          }),
                          child: Text('$i'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _eventPhaseForLog() {
    // HT中は得点させないが、万一呼ばれても安全に
    if (_phase == MatchPhase.firstHalf) return '前半';
    if (_phase == MatchPhase.secondHalf) return '後半';
    return _phaseLabel;
    // 将来：AT/ET/PK を追加するならここに拡張
  }

  Future<void> _goal(String team) async {
    if (_phase == MatchPhase.halftime || _phase == MatchPhase.finished) return;

    final picked = await _pickScorer();
    if (picked == null) return;

    final no = picked['no'] as int;
    final name = (picked['name'] as String).trim();

    setState(() {
      _events.add({
        'tGlobal': _globalElapsedSec,
        'tPhase': _elapsedInPhaseSec,
        'phase': _eventPhaseForLog(), // "前半"/"後半"
        'team': team, // "A" or "B"
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
      if (team == 'A') _scoreA = (_scoreA - 1).clamp(0, 9999);
      if (team == 'B') _scoreB = (_scoreB - 1).clamp(0, 9999);
    });
  }

  // ====== ★試合中の得点履歴：左右2カラム（左=TeamA / 右=TeamB）、チーム名不要 ======

  List<Map<String, dynamic>> get _eventsA =>
      _events.where((e) => e['team'] == 'A').toList();

  List<Map<String, dynamic>> get _eventsB =>
      _events.where((e) => e['team'] == 'B').toList();

  String _eventTextInMatch(Map<String, dynamic> e) {
    final phase = e['phase'] as String;
    final time = _fmt(e['tPhase'] as int);
    final no = e['playerNo'] as int;
    final name = (e['playerName'] as String?) ?? '';
    final who = name.isEmpty ? '#$no' : '#$no $name';
    return '$phase $time  $who';
  }

  Widget _eventListColumn({
    required List<Map<String, dynamic>> items,
    required TextAlign align,
  }) {
    final reversed = items.reversed.toList(); // 最新が上
    if (reversed.isEmpty) {
      return const Text('—', style: TextStyle(color: Colors.black38));
    }
    return Column(
      crossAxisAlignment:
          align == TextAlign.right ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        for (final e in reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(_eventTextInMatch(e), textAlign: align),
          ),
      ],
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
        title: const Text('Match'),
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
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  Text(
                    // 自動遷移しないので「残り」は目安として表示
                    '残り(目安) ${_fmt(_remainSec)}   /   経過 ${_fmt(_elapsedInPhaseSec)}',
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

                  const SizedBox(height: 12),

                  // ★手動遷移ボタン（自動遷移しない）
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
                          onPressed: _endHalftime,
                          icon: const Icon(Icons.skip_next),
                          label: const Text('HT終了'),
                        ),
                      if (_phase == MatchPhase.secondHalf)
                        FilledButton.icon(
                          onPressed: _finishMatch,
                          icon: const Icon(Icons.flag),
                          label: const Text('試合終了'),
                        ),
                    ],
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
                    onPressed: (_phase == MatchPhase.halftime || _phase == MatchPhase.finished)
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
                    onPressed: (_phase == MatchPhase.halftime || _phase == MatchPhase.finished)
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
                    child: _eventListColumn(items: _eventsA, align: TextAlign.left),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _eventListColumn(items: _eventsB, align: TextAlign.right),
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
    required this.events,
  });

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  List<Map<String, dynamic>> _eventsOf(String phase) {
    return events.where((e) => e['phase'] == phase).toList();
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

    // Flutter Web: txt ダウンロード
    // ignore: avoid_web_libraries_in_flutter
    final blob = html.Blob([text], 'text/plain');
    // ignore: avoid_web_libraries_in_flutter
    final url = html.Url.createObjectUrlFromBlob(blob);
    // ignore: avoid_web_libraries_in_flutter
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', fileName)
      ..click();
    // ignore: avoid_web_libraries_in_flutter
    html.Url.revokeObjectUrl(url);
  }

  Widget _resultBlock({
    required String title,
    required int elapsedSec,
    required List<Map<String, dynamic>> evs,
    required VoidCallback onExport,
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

            const SizedBox(height: 12),

            SizedBox(
              height: 40,
              child: FilledButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.download),
                label: const Text('書き出し'),
              ),
            ),

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
    final firstHalfEvents = _eventsOf('前半');
    final secondHalfEvents = _eventsOf('後半');

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _resultBlock(
            title: 'Result（試合全体）',
            elapsedSec: totalElapsedSec,
            evs: events,
            onExport: () => _exportText(
              title: 'Result（試合全体）',
              fileName: 'result_full.txt',
              elapsedSec: totalElapsedSec,
              evs: events,
            ),
          ),

          _resultBlock(
            title: 'Result（前半）',
            elapsedSec: firstHalfElapsedSec,
            evs: firstHalfEvents,
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
            onExport: () => _exportText(
              title: 'Result（後半）',
              fileName: 'result_2nd.txt',
              elapsedSec: secondHalfElapsedSec,
              evs: secondHalfEvents,
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('戻る'),
            ),
          ),
        ],
      ),
    );
  }
}


