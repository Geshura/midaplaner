import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl', null);
  runApp(
    ChangeNotifierProvider(
      create: (context) => TaskProvider(),
      child: const PlannerApp(),
    ),
  );
}

// --- 1. MODEL DANYCH ---

class Podzadanie {
  String tytul;
  bool wykonane;

  Podzadanie({required this.tytul, this.wykonane = false});

  Map<String, dynamic> naMape() => {'tytul': tytul, 'wykonane': wykonane};

  factory Podzadanie.zMapy(Map<String, dynamic> mapa) {
    return Podzadanie(tytul: mapa['tytul'], wykonane: mapa['wykonane'] ?? false);
  }
}

class Zadanie {
  String id;
  String tytul;
  String opis;
  DateTime termin;
  String kategoria;
  bool wykonane;
  List<Podzadanie> podzadania;

  Zadanie({
    required this.id,
    required this.tytul,
    required this.opis,
    required this.termin,
    required this.kategoria,
    this.wykonane = false,
    List<Podzadanie>? podzadania,
  }) : podzadania = podzadania ?? [];

  bool get poTerminie {
    if (wykonane) return false;
    return termin.isBefore(DateTime.now());
  }

  Map<String, dynamic> naMape() {
    return {
      'id': id,
      'tytul': tytul,
      'opis': opis,
      'termin': termin.toIso8601String(),
      'kategoria': kategoria,
      'wykonane': wykonane,
      'podzadania': podzadania.map((s) => s.naMape()).toList(),
    };
  }

  factory Zadanie.zMapy(Map<String, dynamic> mapa) {
    return Zadanie(
      id: mapa['id'],
      tytul: mapa['tytul'],
      opis: mapa['opis'],
      termin: DateTime.parse(mapa['termin']),
      kategoria: mapa['kategoria'],
      wykonane: mapa['wykonane'] ?? false,
      podzadania: mapa['podzadania'] != null
          ? (mapa['podzadania'] as List).map((s) => Podzadanie.zMapy(s)).toList()
          : [],
    );
  }
}

// --- 2. ZARZĄDZANIE STANEM (LOGIKA ODHACZANIA I CSV) ---

class PlanerProvider extends ChangeNotifier {
  List<Zadanie> _zadania = [];
  List<Zadanie> get zadania => _zadania;

  PlanerProvider() {
    wczytajZadania();
  }

  void zapiszZadanie(Zadanie zadanie, {bool edycja = false}) {
    if (edycja) {
      final index = _zadania.indexWhere((z) => z.id == zadanie.id);
      if (index != -1) _zadania[index] = zadanie;
    } else {
      _zadania.add(zadanie);
    }
    zapiszDoPrefs();
    notifyListeners();
  }

  void usunZadanie(String id) {
    _zadania.removeWhere((z) => z.id == id);
    zapiszDoPrefs();
    notifyListeners();
  }

  void przelaczStatusZadania(String id) {
    final index = _zadania.indexWhere((z) => z.id == id);
    if (index != -1) {
      final zadanie = _zadania[index];
      zadanie.wykonane = !zadanie.wykonane;
      for (var pod in zadanie.podzadania) {
        pod.wykonane = zadanie.wykonane;
      }
      zapiszDoPrefs();
      notifyListeners();
    }
  }

  void przelaczStatusPodzadania(String zadanieId, int podzadanieIndex) {
    final index = _zadania.indexWhere((z) => z.id == zadanieId);
    if (index != -1) {
      final zadanie = _zadania[index];
      zadanie.podzadania[podzadanieIndex].wykonane = !zadanie.podzadania[podzadanieIndex].wykonane;
      if (zadanie.podzadania.isNotEmpty) {
        bool wszystkieWykonane = zadanie.podzadania.every((p) => p.wykonane);
        zadanie.wykonane = wszystkieWykonane;
      }
      zapiszDoPrefs();
      notifyListeners();
    }
  }

  String _oczysc(String tekst) {
    return tekst.replaceAll(';', ',').replaceAll('\n', ' ');
  }

  Future<void> eksportujCSV() async {
    try {
      StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln('ID;Tytul;Opis;Termin;Kategoria;Status;Podzadania');
      for (var z in _zadania) {
        String podzadaniaStr = z.podzadania.map((p) => '${_oczysc(p.tytul)}|${p.wykonane ? "1" : "0"}').join('#');
        csvBuffer.writeln(
          '${z.id};'
          '${_oczysc(z.tytul)};'
          '${_oczysc(z.opis)};'
          '${z.termin.toIso8601String()};'
          '${z.kategoria};'
          '${z.wykonane ? "1" : "0"};'
          '$podzadaniaStr'
        );
      }
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/Planer_Export_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv');
      await file.writeAsString(csvBuffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Mój plan zadań (CSV)');
    } catch (e) {
      debugPrint("Błąd eksportu CSV: $e");
    }
  }

  Future<bool> importujCSV() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom, allowedExtensions: ['csv', 'txt'],
      );
      if (result != null && result.files.single.path != null) {
        File file = File(result.files.single.path!);
        List<String> lines = await file.readAsLines();
        if (lines.isEmpty) return false;
        List<Zadanie> zaimportowane = [];
        for (int i = 1; i < lines.length; i++) {
          String line = lines[i];
          if (line.trim().isEmpty) continue;
          List<String> parts = line.split(';');
          if (parts.length < 6) continue;
          List<Podzadanie> pods = [];
          if (parts.length > 6 && parts[6].isNotEmpty) {
            var podsRaw = parts[6].split('#');
            for (var p in podsRaw) {
              var pParts = p.split('|');
              if (pParts.length == 2) {
                pods.add(Podzadanie(tytul: pParts[0], wykonane: pParts[1] == '1'));
              }
            }
          }
          zaimportowane.add(Zadanie(
            id: parts[0].isNotEmpty ? parts[0] : DateTime.now().millisecondsSinceEpoch.toString(),
            tytul: parts[1],
            opis: parts[2],
            termin: DateTime.tryParse(parts[3]) ?? DateTime.now(),
            kategoria: parts[4],
            wykonane: parts[5] == '1',
            podzadania: pods,
          ));
        }
        _zadania = zaimportowane;
        await zapiszDoPrefs();
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Błąd importu CSV: $e");
      return false;
    }
  }

  Future<void> zapiszDoPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zadania_data', json.encode(_zadania.map((z) => z.naMape()).toList()));
  }

  Future<void> wczytajZadania() async {
    final prefs = await SharedPreferences.getInstance();
    final String? zadaniaString = prefs.getString('zadania_data');
    if (zadaniaString != null) {
      try {
        final List<dynamic> decodedData = json.decode(zadaniaString);
        _zadania = decodedData.map((item) => Zadanie.zMapy(item)).toList();
        notifyListeners();
      } catch (_) {}
    }
  }
}

// --- 3. UI: GŁÓWNY EKRAN ---

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Planer PRO',
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF2F5F9),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const TaskListScreen(),
    );
  }
}

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context);
    final sortedTasks = List<Task>.from(provider.tasks);
    sortedTasks.sort((a, b) {
      if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
      return a.date.compareTo(b.date);
    });

    TextEditingController _searchController = TextEditingController();
    String _searchText = '';
    return StatefulBuilder(
      builder: (context, setState) {
        final filteredTasks = _searchText.isEmpty
            ? sortedTasks
            : sortedTasks.where((t) => t.title.toLowerCase().contains(_searchText.toLowerCase()) || t.category.toLowerCase().contains(_searchText.toLowerCase())).toList();
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('MÓJ PLANER', style: TextStyle(fontWeight: FontWeight.w900)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black),
                onSelected: (value) async {
                  if (value == 'export') await provider.exportTasksToCSV();
                  if (value == 'import') {
                    bool success = await provider.importTasksFromCSV();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(success ? "Zaimportowano z pliku CSV!" : "Błąd importu"),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ));
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'export', child: Row(children: [Icon(Icons.table_chart), SizedBox(width: 8), Text('Eksport do Excela (CSV)')])),
                  const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.upload_file), SizedBox(width: 8), Text('Importuj z CSV')])),
                ],
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Szukaj zadania lub kategorii...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchText = val),
                ),
              ),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFE0EAFC), Color(0xFFCFDEF3)],
              ),
            ),
            child: SafeArea(
              child: filteredTasks.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 80),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        return _TaskCard(task: filteredTasks[index], onDelete: () async {
                          bool? confirm = await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Potwierdź usunięcie'),
                              content: const Text('Czy na pewno chcesz usunąć to zadanie?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anuluj')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Usuń', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            provider.deleteTask(filteredTasks[index].id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Usunięto zadanie!'), backgroundColor: Colors.red)
                            );
                          }
                        });
                      },
                    ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskFormScreen())),
            backgroundColor: const Color(0xFF6C63FF),
            icon: const Icon(Icons.add_task, color: Colors.white),
            label: const Text("Nowe Zadanie", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_month_rounded, size: 80, color: Colors.grey.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('Brak zadań', style: TextStyle(fontSize: 22, color: Colors.grey[600], fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --- 4. KARTA ZADANIA ---

class _TaskCard extends StatelessWidget {
  final Task task;
  final Future<void> Function()? onDelete;
  const _TaskCard({required this.task, this.onDelete});

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Praca': return Icons.work_outline;
      case 'Zakupy': return Icons.shopping_cart_outlined;
      case 'Dom': return Icons.home_outlined;
      case 'Nauka': return Icons.school_outlined;
      default: return Icons.label_outline;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Praca': return Colors.blue;
      case 'Zakupy': return Colors.orange;
      case 'Dom': return Colors.green;
      case 'Nauka': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context, listen: false);
    final catColor = _getCategoryColor(task.category);
    final isOverdue = task.isOverdue;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Transform.scale(
            scale: 1.3,
            child: Checkbox(
              value: task.isDone,
              activeColor: catColor,
              shape: const CircleBorder(),
              onChanged: (_) => provider.toggleTaskStatus(task.id),
            ),
          ),
          title: Text(
            task.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              decoration: task.isDone ? TextDecoration.lineThrough : null,
              color: task.isDone ? Colors.grey : Colors.black87,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: task.isDone ? Colors.grey[200] : catColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getCategoryIcon(task.category), size: 14, color: task.isDone ? Colors.grey : catColor),
                        const SizedBox(width: 4),
                        Text(task.category, style: TextStyle(fontSize: 12, color: task.isDone ? Colors.grey : catColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(Icons.access_time, size: 14, color: isOverdue ? Colors.red : Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd.MM HH:mm').format(task.date),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isOverdue ? Colors.red : Colors.grey[600],
                      backgroundColor: isOverdue ? Colors.red.withOpacity(0.1) : null,
                    ),
                  ),
                  if (isOverdue) ...[
                    const SizedBox(width: 5),
                    const Text("(!)", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  ]
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                color: Colors.grey[700],
                tooltip: 'Edytuj',
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TaskFormScreen(taskToEdit: task)));
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red),
                tooltip: 'Usuń',
                onPressed: onDelete,
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.description.isNotEmpty) ...[
                    const Divider(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.notes, size: 20, color: Colors.grey),
                        const SizedBox(width: 10),
                        Expanded(child: Text(task.description, style: const TextStyle(color: Colors.black87))),
                      ],
                    ),
                  ],
                  if (task.subtasks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(),
                    const Text("PODZADANIA:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ...task.subtasks.asMap().entries.map((entry) {
                      int idx = entry.key;
                      SubTask s = entry.value;
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        leading: Checkbox(
                          value: s.isDone,
                          onChanged: (_) => provider.toggleSubtaskStatus(task.id, idx),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        title: Text(
                          s.title,
                          style: TextStyle(
                            decoration: s.isDone ? TextDecoration.lineThrough : null,
                            color: s.isDone ? Colors.grey : Colors.black,
                          ),
                        ),
                      );
                    }),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 5. FORMULARZ ---

class TaskFormScreen extends StatefulWidget {
  final Task? taskToEdit;
  const TaskFormScreen({super.key, this.taskToEdit});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  late String _selectedCategory;
  late bool _isDone;
  List<SubTask> _subtasks = [];
  final TextEditingController _subTaskController = TextEditingController();

  final List<String> _categories = ['Dom', 'Praca', 'Zakupy', 'Nauka', 'Inne'];

  @override
  void initState() {
    super.initState();
    final t = widget.taskToEdit;
    _titleController = TextEditingController(text: t?.title ?? '');
    _descController = TextEditingController(text: t?.description ?? '');
    _selectedDate = t?.date ?? DateTime.now();
    _selectedTime = t != null ? TimeOfDay.fromDateTime(t.date) : TimeOfDay.now();
    _selectedCategory = t?.category ?? 'Dom';
    _isDone = t?.isDone ?? false;
    if (t != null) {
      _subtasks = t.subtasks.map((s) => SubTask(title: s.title, isDone: s.isDone)).toList();
    }
  }

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pl'),
    );
    if (date != null) {
      if (!mounted) return;
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: _selectedTime,
        builder: (context, child) {
          return MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!);
        }
      );
      if (time != null) {
        setState(() {
          _selectedDate = date;
          _selectedTime = time;
        });
      }
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final DateTime finalDateTime = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        _selectedTime.hour, _selectedTime.minute,
      );

      final task = Task(
        id: widget.taskToEdit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text,
        description: _descController.text,
        date: finalDateTime,
        category: _selectedCategory,
        isDone: _isDone,
        subtasks: _subtasks,
      );

      Provider.of<TaskProvider>(context, listen: false).saveTask(task, isEditing: widget.taskToEdit != null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.taskToEdit != null ? 'Zadanie zaktualizowane!' : 'Dodano zadanie!'), backgroundColor: Colors.green)
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.taskToEdit != null ? 'Edycja' : 'Nowe Zadanie', style: const TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Tytuł',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                validator: (val) => val!.isEmpty ? 'Wpisz tytuł' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Opis (opcjonalnie)',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
              ),
              const SizedBox(height: 20),

              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.blue),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Termin (Data i Godzina)", style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            "${DateFormat('dd.MM.yyyy').format(_selectedDate)}  |  ${_selectedTime.format(context)}",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.edit, size: 16, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Kategoria',
                  prefixIcon: Icon(Icons.category),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),

              const SizedBox(height: 20),
              Row(
                children: [
                  Checkbox(
                    value: _isDone,
                    onChanged: (v) {
                      setState(() {
                        _isDone = v!;
                        for (var s in _subtasks) {
                          s.isDone = _isDone;
                        }
                      });
                    },
                  ),
                  const Text('Zadanie wykonane', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (_subtasks.isNotEmpty)
                    TextButton.icon(
                      icon: const Icon(Icons.done_all),
                      label: const Text('Wszystkie podzadania'),
                      onPressed: () {
                        setState(() {
                          bool allDone = _subtasks.every((s) => s.isDone);
                          for (var s in _subtasks) {
                            s.isDone = !allDone;
                          }
                          _isDone = !allDone;
                        });
                      },
                    ),
                ],
              ),

              const SizedBox(height: 20),
              const Text("LISTA KONTROLNA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),

              ..._subtasks.asMap().entries.map((e) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Checkbox(
                  value: e.value.isDone,
                  onChanged: (v) => setState(() {
                    e.value.isDone = v!;
                    if (_subtasks.isNotEmpty) {
                      bool allDone = _subtasks.every((s) => s.isDone);
                      _isDone = allDone;
                    }
                  }),
                ),
                title: TextFormField(
                  initialValue: e.value.title,
                  decoration: const InputDecoration(border: InputBorder.none),
                  onChanged: (val) => setState(() => e.value.title = val),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => setState(() => _subtasks.removeAt(e.key)),
                ),
              )),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subTaskController,
                      decoration: const InputDecoration(hintText: "Dodaj podzadanie..."),
                      onSubmitted: (_) {
                        if (_subTaskController.text.isNotEmpty && !_subtasks.any((s) => s.title == _subTaskController.text)) {
                          setState(() {
                            _subtasks.add(SubTask(title: _subTaskController.text));
                            _subTaskController.clear();
                          });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFF6C63FF), size: 30),
                    onPressed: () {
                      if (_subTaskController.text.isNotEmpty && !_subtasks.any((s) => s.title == _subTaskController.text)) {
                        setState(() {
                          _subtasks.add(SubTask(title: _subTaskController.text));
                          _subTaskController.clear();
                        });
                      }
                    },
                  )
                ],
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save, color: Colors.white),
                  label: const Text('ZAPISZ ZADANIE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}