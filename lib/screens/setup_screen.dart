part of simplescore_web_app;

// ===============================
// Setup
// ===============================

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  String? teamAId;
  String? teamBId;

  int matchMinutes = 10;
  bool hasHalftime = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group),
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
            const Text('Team A'),
            DropdownButton<String>(
              isExpanded: true,
              value: teamAId,
              hint: const Text('Select Team A'),
              items: myTeamsCache
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t.id,
                      child: Text(t.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => teamAId = v),
            ),
            const SizedBox(height: 12),
            const Text('Team B'),
            DropdownButton<String>(
              isExpanded: true,
              value: teamBId,
              hint: const Text('Select Team B'),
              items: myTeamsCache
                  .map(
                    (t) => DropdownMenuItem<String>(
                      value: t.id,
                      child: Text(t.name),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => teamBId = v),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Minutes:'),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: matchMinutes,
                  items: const [
                    DropdownMenuItem(value: 5, child: Text('5')),
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 15, child: Text('15')),
                    DropdownMenuItem(value: 20, child: Text('20')),
                  ],
                  onChanged: (v) => setState(() => matchMinutes = v ?? 10),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Checkbox(
                  value: hasHalftime,
                  onChanged: (v) => setState(() => hasHalftime = v ?? true),
                ),
                const Text('Halftime'),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (teamAId == null || teamBId == null)
                    ? null
                    : () {
                        final teamA =
                            myTeamsCache.firstWhere((t) => t.id == teamAId);
                        final teamB =
                            myTeamsCache.firstWhere((t) => t.id == teamBId);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchScreen(
                              teamA: teamA.name,
                              teamB: teamB.name,
                              teamAId: teamA.id,
                              teamBId: teamB.id,
                              minutes: matchMinutes,
                              hasHalftime: hasHalftime,
                            ),
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
}
