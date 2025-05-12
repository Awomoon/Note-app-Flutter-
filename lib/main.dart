import 'package:flutter/material.dart';
import 'note_database.dart';
import 'note_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Note App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<Note> _notes = [];
  List<Note> _filteredNotes = [];

  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _tagController = TextEditingController();
  final List<int> _colorOptions = [
    0xFFFFFFFF, // White
    0xFFFFF9C4, // Light yellow
    0xFFE1BEE7, // Light purple
    0xFFBBDEFB, // Light blue
    0xFFC8E6C9, // Light green
    0xFFFFCCBC, // Light orange
  ];
  int _selectedColor = 0xFFFFFFFF;
  String _searchQuery = '';
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await NoteDatabase.instance.readAllNotes();
    setState(() {
      _notes = notes;
      _filteredNotes = _filterNotes(notes, _searchQuery);
    });
  }

  List<Note> _filterNotes(List<Note> notes, String query) {
    if (query.isEmpty) return notes;
    final lower = query.toLowerCase();
    return notes.where((note) {
      return note.title.toLowerCase().contains(lower) ||
             note.content.toLowerCase().contains(lower) ||
             note.tag.toLowerCase().contains(lower);
    }).toList();
  }

  void _updateSearch(String query) {
    setState(() {
      _searchQuery = query;
      _filteredNotes = _filterNotes(_notes, _searchQuery);
    });
  }

  Future<void> _addNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    final tag = _tagController.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    final note = Note(
      title: title, 
      content: content, 
      tag: tag, 
      color: _selectedColor,
      createdAt: DateTime.now(),
    );
    await NoteDatabase.instance.create(note);

    _titleController.clear();
    _contentController.clear();
    _tagController.clear();
    _selectedColor = 0xFFFFFFFF;
    setState(() => _isExpanded = false);

    _loadNotes();
  }

  Future<void> _editNoteDialog(Note note) async {
    final titleController = TextEditingController(text: note.title);
    final contentController = TextEditingController(text: note.content);
    final tagController = TextEditingController(text: note.tag);
    int selectedColor = note.color;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Note'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tagController,
                decoration: const InputDecoration(
                  labelText: 'Tag',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('Note Color', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _colorOptions.map((color) => GestureDetector(
                  onTap: () {
                    setState(() => selectedColor = color);
                    Navigator.of(context).pop();
                    _editNoteDialog(note.copyWith(color: color));
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedColor == color 
                          ? Theme.of(context).colorScheme.primary 
                          : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: selectedColor == color 
                      ? Icon(Icons.check, size: 16, color: _getContrastColor(Color(color)))
                      : null,
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updated = note.copyWith(
                title: titleController.text,
                content: contentController.text,
                tag: tagController.text,
                color: selectedColor,
                updatedAt: DateTime.now(),
              );
              await NoteDatabase.instance.update(updated);
              Navigator.pop(context);
              _loadNotes();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteNote(int id) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await NoteDatabase.instance.delete(id);
              Navigator.pop(context);
              _loadNotes();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getContrastColor(Color color) {
    double luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📝 Notes'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              showSearch(
                context: context,
                delegate: NoteSearchDelegate(_notes, _editNoteDialog, _deleteNote),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Collapsible note creation form
          Card(
            margin: const EdgeInsets.all(12),
            elevation: 2,
            child: ExpansionPanelList(
              elevation: 0,
              expandedHeaderPadding: EdgeInsets.zero,
              expansionCallback: (int index, bool isExpanded) {
                setState(() => _isExpanded = !_isExpanded);
              },
              children: [
                ExpansionPanel(
                  headerBuilder: (context, isExpanded) => const ListTile(
                    leading: Icon(Icons.add),
                    title: Text('Add new note'),
                  ),
                  body: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        TextField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _contentController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Content',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _tagController,
                          decoration: const InputDecoration(
                            labelText: 'Tag',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Note Color', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _colorOptions.map((color) => GestureDetector(
                            onTap: () => setState(() => _selectedColor = color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(color),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _selectedColor == color 
                                    ? Theme.of(context).colorScheme.primary 
                                    : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: _selectedColor == color 
                                ? Icon(Icons.check, size: 16, color: _getContrastColor(Color(color)))
                                : null,
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.add),
                            label: const Text('Add Note'),
                            onPressed: _addNote,
                          ),
                        ),
                      ],
                    ),
                  ),
                  isExpanded: _isExpanded,
                ),
              ],
            ),
          ),
          // Notes list
          Expanded(
            child: _filteredNotes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.note, size: 64, color: Theme.of(context).disabledColor),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty 
                            ? 'No notes yet!\nTap + to add a new note'
                            : 'No notes found',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).disabledColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _filteredNotes.length,
                    itemBuilder: (context, index) {
                      final note = _filteredNotes[index];
                      return Dismissible(
                        key: Key(note.id.toString()),
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Colors.red,
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Note'),
                              content: const Text('Are you sure you want to delete this note?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) => _deleteNote(note.id!),
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: Color(note.color),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _editNoteDialog(note),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          note.title,
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (note.tag.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '#${note.tag}',
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (note.content.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      note.content,
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Text(
                                    _formatDate(note.createdAt),
                                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).disabledColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _isExpanded = true),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class NoteSearchDelegate extends SearchDelegate {
  final List<Note> notes;
  final Function(Note) onEditNote;
  final Function(int) onDeleteNote;

  NoteSearchDelegate(this.notes, this.onEditNote, this.onDeleteNote);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    final filteredNotes = notes.where((note) {
      final lowerQuery = query.toLowerCase();
      return note.title.toLowerCase().contains(lowerQuery) ||
             note.content.toLowerCase().contains(lowerQuery) ||
             note.tag.toLowerCase().contains(lowerQuery);
    }).toList();

    return _buildSearchResults(filteredNotes);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filteredNotes = notes.where((note) {
      final lowerQuery = query.toLowerCase();
      return note.title.toLowerCase().contains(lowerQuery) ||
             note.content.toLowerCase().contains(lowerQuery) ||
             note.tag.toLowerCase().contains(lowerQuery);
    }).toList();

    return _buildSearchResults(filteredNotes);
  }

  Widget _buildSearchResults(List<Note> filteredNotes) {
    return ListView.builder(
      itemCount: filteredNotes.length,
      itemBuilder: (context, index) {
        final note = filteredNotes[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          color: Color(note.color),
          child: ListTile(
            title: Text(note.title),
            subtitle: Text(note.content, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => onDeleteNote(note.id!),
            ),
            onTap: () {
              close(context, null);
              onEditNote(note);
            },
          ),
        );
      },
    );
  }
}