import 'dart:async';
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
  int _durationMinutes = 10;

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
          durationMinutes: _durationMinutes,
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
          const Text('試合時間（分）', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _durationMinutes,
            items: const [
              DropdownMenuItem(value: 5, child: Text('5')),
              DropdownMenuItem(value: 10, child: Text('10')),
              DropdownMenuItem(value: 15, child: Text('15')),
              DropdownMenuItem(value: 20, child: Text('20')),
              DropdownMenuItem(value: 30, child: Text('30')),
              DropdownMenuItem(value: 45, child: Text('45')),
            ],
            onChanged: (v) => setState(() => _durationMinutes = v ?? 10),
            decoration: const InputDecoration(labelText: 'Duration'),
          ),
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
            '※ Web版は画面を閉じる/バックグラウンドにするとタイマーが止まりやすいです（後で対策可能）',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class MatchScreen extends StatefulWidget {
  final String teamA;
  final String teamB;
  final int durationMinutes;

  const MatchScreen({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.durationMinutes,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  Timer? _timer;
  bool _running = false;
  int _elapsedSec = 0;

  int _scoreA = 0;
  int _scoreB = 0;

  // events: {t:int, team:"A"/"B", player:int}
  final List<Map<String, dynamic>> _events = [];

  int get _totalSec => widget.durationMinutes * 60;
  int get _remainSec => (_totalSec - _elapsedSec).clamp(0, _totalSec);

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _start() {
    if (_running) return;
    setState(() => _running = true);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_elapsedSec >= _totalSec) {
        _stop();
        return;
      }
      setState(() => _elapsedSec++);
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    if (mounted) setState(() => _running = false);
  }

  void _reset() {
    _stop();
    setState(() {
      _elapsedSec = 0;
      _scoreA = 0;
      _scoreB = 0;
      _events.clear();
    });
  }

  Future<int?> _pickNumber() async {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.65,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('背番号を選択（0〜99）', style: TextStyle(fontSize: 16)),
                ),
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
                        onPressed: () => Navigator.of(ctx).pop(i),
                        child: Text('$i'),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _goal(String team) async {
    final number = await _pickNumber();
    if (number == null) return;

    setState(() {
      _events.add({'t': _elapsedSec, 'team': team, 'player': number});
      if (team == 'A') _scoreA++;
      if (team == 'B') _scoreB++;
    });
  }

  void _finish() {
    _stop();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          teamA: widget.teamA,
          teamB: widget.teamB,
          durationMinutes: widget.durationMinutes,
          scoreA: _scoreA,
          scoreB: _scoreB,
          elapsedSec: _elapsedSec,
          events: List<Map<String, dynamic>>.from(_events),
        ),
      ),
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
            onPressed: _reset,
            tooltip: 'リセット',
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
                  Text(
                    scoreText,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '残り ${_fmt(_remainSec)}   /   経過 ${_fmt(_elapsedSec)}',
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: _running ? null : _start,
                        child: const Text('開始'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _running ? _stop : null,
                        child: const Text('停止'),
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
                    onPressed: () => _goal('A'),
                    child: Text('${widget.teamA} 得点'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: () => _goal('B'),
                    child: Text('${widget.teamB} 得点'),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Text('得点ログ（最新が上）', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),

          if (_events.isEmpty)
            const Text('まだ得点がありません', style: TextStyle(color: Colors.black54))
          else
            ..._events.reversed.map((e) {
              final t = _fmt(e['t'] as int);
              final team = e['team'] as String;
              final p = e['player'] as int;
              final teamName = team == 'A' ? widget.teamA : widget.teamB;
              return ListTile(
                dense: true,
                leading: Text(t),
                title: Text('$teamName  #$p'),
              );
            }),

          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _finish,
              icon: const Icon(Icons.flag),
              label: const Text('試合終了'),
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
  final int durationMinutes;
  final int scoreA;
  final int scoreB;
  final int elapsedSec;
  final List<Map<String, dynamic>> events;

  const ResultScreen({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.durationMinutes,
    required this.scoreA,
    required this.scoreB,
    required this.elapsedSec,
    required this.events,
  });

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scoreText = '$teamA  $scoreA  -  $scoreB  $teamB';

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    scoreText,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text('試合時間：$durationMinutes 分', style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 4),
                  Text('経過：${_fmt(elapsedSec)}', style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          const Text('得点詳細（時刻順）', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),

          if (events.isEmpty)
            const Text('得点なし', style: TextStyle(color: Colors.black54))
          else
            ...events.map((e) {
              final t = _fmt(e['t'] as int);
              final team = e['team'] as String;
              final p = e['player'] as int;
              final teamName = team == 'A' ? teamA : teamB;
              return ListTile(
                dense: true,
                leading: Text(t),
                title: Text('$teamName  #$p'),
              );
            }),

          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const HomeScreen()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.home),
              label: const Text('ホームへ'),
            ),
          ),
        ],
      ),
    );
  }
}
