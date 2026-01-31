part of simplescore_web_app;

// ===============================
// Result
// ===============================

class ResultScreen extends StatelessWidget {
  final String teamA;
  final String teamB;
  final int scoreA;
  final int scoreB;
  final List<Map<String, dynamic>> events;

  const ResultScreen({
    super.key,
    required this.teamA,
    required this.teamB,
    required this.scoreA,
    required this.scoreB,
    required this.events,
  });

  String _fmt(int sec) {
    final m = (sec ~/ 60).toString().padLeft(2, '0');
    final s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              '$teamA $scoreA  -  $scoreB $teamB',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final e = events[index];
                  return ListTile(
                    title: Text('${e['team']}  #${e['number']} ${e['name']}'),
                    subtitle: Text('${e['phase']}  ${e['time']}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.popUntil(context, (r) => r.isFirst);
                },
                child: const Text('Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
