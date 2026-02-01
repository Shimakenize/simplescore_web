part of simplescore_web_app;

class MyTeamsScreen extends StatefulWidget {
  const MyTeamsScreen({super.key});

  @override
  State<MyTeamsScreen> createState() => _MyTeamsScreenState();
}

class _MyTeamsScreenState extends State<MyTeamsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Teams'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.upload),
            tooltip: 'Import CSV',
            onPressed: _importCsv,
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: myTeamsCache.length,
        itemBuilder: (context, index) {
          final team = myTeamsCache[index];
          return ListTile(
            title: Text(team.name),
            subtitle: Text('${team.members.length} members'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                setState(() {
                  myTeamsCache.removeAt(index);
                  saveMyTeamsBestEffort();
                });
              },
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeamEditorScreen(team: team),
                ),
              );
              setState(() {});
            },
          );
        },
      ),
      floatingActionButton: myTeamsCache.length >= 10
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final newTeam = MyTeam(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: '',
                  members: [],
                );
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => TeamEditorScreen(team: newTeam, isNew: true),
                  ),
                );
                setState(() {});
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  // ===============================
  // CSV Export
  // ===============================

  void _exportCsv() {
    final buffer = StringBuffer();
    buffer.writeln('team_id,team_name,number,name');

    for (final team in myTeamsCache) {
      for (final m in team.members) {
        buffer.writeln(
          '${team.id},${team.name},${m.number},${m.name}',
        );
      }
    }

    final bytes = utf8.encode(buffer.toString());
    final blob = html.Blob([Uint8List.fromList(bytes)]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', 'my_teams.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  // ===============================
  // CSV Import
  // ===============================

  void _importCsv() {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = '.csv';
    uploadInput.click();

    uploadInput.onChange.listen((_) {
      final file = uploadInput.files?.first;
      if (file == null) return;

      final reader = html.FileReader();
      reader.readAsText(file);

      reader.onLoadEnd.listen((_) {
        final text = reader.result as String;
        final lines = const LineSplitter().convert(text);

        final Map<String, MyTeam> teams = {};

        for (int i = 1; i < lines.length; i++) {
          final parts = lines[i].split(',');
          if (parts.length < 4) continue;

          final teamId = parts[0].trim();
          final teamName = parts[1].trim();
          final number = int.tryParse(parts[2]);
          final name = parts[3].trim();

          if (teamId.isEmpty || teamName.isEmpty) continue;
          if (number == null || number < 0 || number > 99) continue;
          if (name.isEmpty) continue;

          teams.putIfAbsent(
            teamId,
            () => MyTeam(id: teamId, name: teamName, members: []),
          );
          teams[teamId]!.members.add(
            TeamMember(number: number, name: name),
          );
        }

        setState(() {
          myTeamsCache = teams.values.take(10).toList();
          saveMyTeamsBestEffort();
        });
      });
    });
  }
}
