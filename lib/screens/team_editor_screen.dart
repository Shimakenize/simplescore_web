part of simplescore_web_app;

class TeamEditorScreen extends StatefulWidget {
  final MyTeam team;
  final bool isNew;

  const TeamEditorScreen({
    super.key,
    required this.team,
    this.isNew = false,
  });

  @override
  State<TeamEditorScreen> createState() => _TeamEditorScreenState();
}

class _TeamEditorScreenState extends State<TeamEditorScreen> {
  late final TextEditingController _teamNameController;
  late final List<TeamMember> _members;

  @override
  void initState() {
    super.initState();
    _teamNameController = TextEditingController(text: widget.team.name);
    _members = List<TeamMember>.from(widget.team.members);
  }

  @override
  void dispose() {
    _teamNameController.dispose();
    super.dispose();
  }

  void _saveAndPop() {
    final newName = _teamNameController.text.trim();
    final updatedTeam = MyTeam(
      id: widget.team.id,
      name: newName,
      members: _members,
    );

    if (widget.isNew) {
      myTeamsCache.add(updatedTeam);
    } else {
      final idx = myTeamsCache.indexWhere((t) => t.id == widget.team.id);
      if (idx >= 0) {
        myTeamsCache[idx] = updatedTeam;
      }
    }

    saveMyTeamsBestEffort();
    Navigator.pop(context);
  }

  void _addMemberDialog() {
    final numberController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Number (0-99)'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final num = int.tryParse(numberController.text.trim());
              final name = nameController.text.trim();
              if (num == null || num < 0 || num > 99 || name.isEmpty) {
                Navigator.pop(context);
                return;
              }
              setState(() {
                _members.add(TeamMember(number: num, name: name));
              });
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Team'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveAndPop,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _teamNameController,
              decoration: const InputDecoration(labelText: 'Team Name'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final m = _members[index];
                  return ListTile(
                    title: Text('${m.number} ${m.name}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          _members.removeAt(index);
                        });
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addMemberDialog,
              child: const Text('Add Member'),
            ),
          ],
        ),
      ),
    );
  }
}
