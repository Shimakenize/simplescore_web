part of simplescore_web_app;

// ===============================
// Setup Screen
// ===============================

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  MyTeam? _teamA;
  MyTeam? _teamB;

  int _matchMinutes = 10;
  bool _hasHalfTime = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups),
            tooltip: 'My Teams',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyTeamsScreen()),
              );
              setState(() {});
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Teams',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _teamSelector(
              label: 'Team A',
              selected: _teamA,
              onSelected: (t) => setState(() => _teamA = t),
            ),
            _teamSelector(
              label: 'Team B',
              selected: _teamB,
              onSelected: (t) => setState(() => _teamB = t),
            ),
            const SizedBox(height: 24),
            const Text(
              'Match Options',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Minutes:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _matchMinutes,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 15, child: Text('15')),
                    DropdownMenuItem(value: 20, child: Text('20')),
                  ],
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _matchMinutes = v);
                    }
                  },
                ),
                const SizedBox(width: 24),
                Checkbox(
                  value: _hasHalfTime,
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _hasHalfTime = v);
                    }
                  },
                ),
                const Text('Half Time'),
              ],
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: (_teamA == null || _teamB == null)
                    ? null
                    : () {
                        final match = {
                          'teamAId': _teamA!.id,
                          'teamBId': _teamB!.id,
                          'minutes': _matchMinutes,
                          'hasHalfTime': _hasHalfTime,
                          'events': [],
                          'startedAt': DateTime.now().millisecondsSinceEpoch,
                        };
                        saveLatestMatchResultBestEffort(match);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchScreen(),
                          ),
                        );
                      },
                child: const Text('Start Match'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teamSelector({
    required String label,
    required MyTeam? selected,
    required ValueChanged<MyTeam> onSelected,
  }) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text(label)),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<MyTeam>(
            value: selected,
            isExpanded: true,
            hint: const Text('Select team'),
            items: myTeamsCache
                .map(
                  (t) => DropdownMenuItem(
                    value: t,
                    child: Text(t.name),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) onSelected(v);
            },
          ),
        ),
      ],
    );
  }
}

