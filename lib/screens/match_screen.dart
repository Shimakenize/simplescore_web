part of simplescore_web_app;

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
  final int minutes;
  final bool hasHalftime;

  const MatchScreen({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.teamAId,
    required this.teamBId,
    required this.minutes,
    required this.hasHalftime,
  });

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  Timer? _timer;
  int _sec = 0;

  int _scoreA = 0;
  int _scoreB = 0;

  MatchPhase _phase = MatchPhase.firstHalf;

  final List<Map<String, dynamic>> _events = [];

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _sec++;
      });
    });
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
        return 'ハーフタイム';
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

  void _addGoal({
    required bool isTeamA,
    required TeamMember scorer,
  }) {
    setState(() {
      if (isTeamA) {
        _scoreA++;
      } else {
        _scoreB++;
      }

      _events.add({
        'phase': _eventPhaseForLog(),
        'time': _fmt(_sec),
        'team': isTeamA ? widget.teamA : widget.teamB,
        'number': scorer.number,
        'name': scorer.name,
      });

      saveLatestMatchResultBestEffort({
        'teamA': widget.teamA,
        'teamB': widget.teamB,
        'scoreA': _scoreA,
        'scoreB': _scoreB,
        'events': _events,
      });
    });
  }

  void _endMatch() {
    _timer?.cancel();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          teamA: widget.teamA,
          teamB: widget.teamB,
          scoreA: _scoreA,
          scoreB: _scoreB,
          events: _events,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamA = (widget.teamAId == null)
        ? null
        : myTeamsCache.firstWhere((t) => t.id == widget.teamAId);
    final teamB = (widget.teamBId == null)
        ? null
        : myTeamsCache.firstWhere((t) => t.id == widget.teamBId);

    final total = widget.minutes * 60;
    final remaining = (total - _sec).clamp(0, total);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flag),
            onPressed: _endMatch,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            '${_fmt(remaining)}',
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(height: 12),
          Text(
            '${widget.teamA} $_scoreA  -  $_scoreB ${widget.teamB}',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                if (teamA != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.teamA,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Wrap(
                    children: [
                      for (final m in teamA.members)
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: ElevatedButton(
                            onPressed: () => _addGoal(
                              isTeamA: true,
                              scorer: m,
                            ),
                            child: Text('${m.number} ${m.name}'),
                          ),
                        ),
                    ],
                  ),
                ],
                if (teamB != null) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.teamB,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Wrap(
                    children: [
                      for (final m in teamB.members)
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: ElevatedButton(
                            onPressed: () => _addGoal(
                              isTeamA: false,
                              scorer: m,
                            ),
                            child: Text('${m.number} ${m.name}'),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
