part of simplescore_web_app;

// ===============================
// Match Screen
// ===============================

class MatchScreen extends StatefulWidget {
  const MatchScreen({super.key});

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late Timer _timer;
  int _elapsedSeconds = 0;

  Map<String, dynamic> get _match => latestMatchResult ??= <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatSeconds(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    final m = minutes.toString().padLeft(2, '0');
    final s = seconds.toString().padLeft(2, '0');

    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final teamA = myTeamsCache.firstWhere((t) => t.id == _match['teamAId']);
    final teamB = myTeamsCache.firstWhere((t) => t.id == _match['teamBId']);

    return Scaffold(
      appBar: AppBar(title: const Text('Match')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Text(
            _formatSeconds(_elapsedSeconds),
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _teamColumn(teamA),
              _teamColumn(teamB),
            ],
          ),
          const Spacer(),
          ElevatedButton(
            onPressed: () {
              _timer.cancel();
              _match['elapsed'] = _elapsedSeconds;
              saveLatestMatchResultBestEffort(_match);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ResultScreen()),
              );
            },
            child: const Text('End Match'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _teamColumn(MyTeam team) {
    return Column(
      children: [
        Text(team.name, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        for (final m in team.members)
          ElevatedButton(
            onPressed: () {
              final event = {
                'type': 'goal',
                'timeSeconds': _elapsedSeconds,
                'teamId': team.id,
                'playerNumber': m.number,
                'playerName': m.name,
              };
              (_match['events'] as List).add(event);
              saveLatestMatchResultBestEffort(_match);
              setState(() {});
            },
            child: Text('${m.number} ${m.name}'),
          ),
      ],
    );
  }
}


