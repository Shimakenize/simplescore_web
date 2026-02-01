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
  late TextEditingController _nameCtrl;
  final List<TeamMember> _members = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.team.name);
    _members.addAll(widget.team.members);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final saved = MyTeam(
      id: widget.team.id,
      name: name,
      members: List<TeamMember>.from(_members),
    );

    if (widget.isNew) {
      myTeamsCache.add(saved);
    } else {
      final idx = myTeamsCache.indexWhere((t) => t.id == widget.team.id);
      if (idx >= 0) {
        myTeamsCache[idx] = saved;
      }
    }

    saveMyTeamsBestEffort();
    Navigator.pop(context);
  }

  void _addMember() async {
    final numberCtrl = TextEditingController();
    final nameCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Add Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Number (0-99)'),
              ),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final num = int.tryParse(numberCtrl.text.trim());
    final name = nameCtrl.text.trim();

    if (num == null || num < 0 || num > 99 || name.isEmpty) return;

    setState(() {
      _members.add(TeamMember(number: num, name: name));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Editor'),
        actions: [
          IconButton(
            tooltip: 'Save',
            onPressed: _save,
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Team Name'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _members.length,
                itemBuilder: (context, index) {
                  final m = _members[index];
                  return ListTile(
                    title: Text('${m.number}  ${m.name}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
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
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _addMember,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Add Member'),
            ),
          ],
        ),
      ),
    );
  }
}
