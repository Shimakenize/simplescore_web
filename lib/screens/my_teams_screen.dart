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
}
