part of simplescore_web_app;

// ===============================
// Result Screen
// ===============================

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

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
    final match = latestMatchResult!;
    final events = (match['events'] as List).cast<dynamic>();

    return Scaffold(
      appBar: AppBar(title: const Text('Result')),
      body: ListView(
        children: [
          for (final e in events)
            if (e is Map && e['type'] == 'goal')
              ListTile(
                title: Text('${e['playerNumber']} ${e['playerName']}'),
                trailing: Text(_formatSeconds((e['timeSeconds'] as int?) ?? 0)),
              ),
          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: () {
                html.window.localStorage.remove('latestMatchResult');
                latestMatchResult = null;
                Navigator.popUntil(context, (r) => r.isFirst);
              },
              child: const Text('設定画面へ戻る'),
            ),
          ),
        ],
      ),
    );
  }
}

