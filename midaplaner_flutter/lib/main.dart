import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await initializeDateFormatting('pl', null); // Popraw: importuj 'intl/date_symbol_data_local.dart' jeśli chcesz użyć tej funkcji
  runApp(
    ChangeNotifierProvider(
      create: (context) => PlanerProvider(),
      child: const PlanerAplikacja(),
    ),
  );
}

// --- MODELE ---
class Podzadanie {
  String tytul;
  bool wykonane;
  Podzadanie({required this.tytul, this.wykonane = false});
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
    required this.wykonane,
    required this.podzadania,
  });
}

// --- PROVIDER ---
class PlanerProvider extends ChangeNotifier {
  final List<Zadanie> _zadania = [];
  List<Zadanie> get zadania => _zadania;

  void zapiszZadanie(Zadanie zadanie, {bool edycja = false}) {
    if (edycja) {
      int idx = _zadania.indexWhere((z) => z.id == zadanie.id);
      if (idx != -1) _zadania[idx] = zadanie;
    } else {
      _zadania.add(zadanie);
    }
    notifyListeners();
  }
}

// --- ROOT WIDGET ---
class PlanerAplikacja extends StatelessWidget {
  const PlanerAplikacja({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiDaPlaner',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF20243A), // główny granat
        primaryColor: const Color(0xFF283593), // fiolet granatowy
        colorScheme: ThemeData.dark().colorScheme.copyWith(
          primary: const Color(0xFF283593),
          secondary: const Color(0xFF64B5F6), // jasny błękit
          surface: const Color(0xFF23284D),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF23284D),
          foregroundColor: Color(0xFF64B5F6),
          elevation: 4,
          shadowColor: Color(0xFF101325),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF283593),
            foregroundColor: Color(0xFF64B5F6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
            elevation: 4,
            shadowColor: Color(0xFF101325),
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF23284D),
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          labelStyle: TextStyle(color: Color(0xFF64B5F6)),
          hintStyle: TextStyle(color: Colors.white70),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF23284D),
          elevation: 6,
          shadowColor: Color(0xFF101325),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: Color(0xFF64B5F6),
          displayColor: Color(0xFF64B5F6),
        ),
      ),
      home: const ListaZadanEkran(),
      debugShowCheckedModeBanner: false,
    );
  }
}
// --- 1. MODEL DANYCH ---

class FormularzZadaniaEkran extends StatefulWidget {
  final Zadanie? zadanieDoEdycji;
  const FormularzZadaniaEkran({super.key, this.zadanieDoEdycji});

  @override
  State<FormularzZadaniaEkran> createState() => _FormularzZadaniaEkranState();
}

class _FormularzZadaniaEkranState extends State<FormularzZadaniaEkran> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _tytulController;
  late TextEditingController _opisController;
  late DateTime _wybranyTermin;
  late TimeOfDay _wybranaGodzina;
  late String _wybranaKategoria;
  late bool _wykonane;
  List<Podzadanie> _podzadania = [];
  final Map<int, TextEditingController> _podzadanieKontrolery = {};
  final TextEditingController _podzadanieController = TextEditingController();

  final List<String> _kategorie = ['Dom', 'Praca', 'Zakupy', 'Nauka', 'Inne'];

  @override
  void initState() {
    super.initState();
    final z = widget.zadanieDoEdycji;
    _tytulController = TextEditingController(text: z?.tytul ?? '');
    _opisController = TextEditingController(text: z?.opis ?? '');
    _wybranyTermin = z?.termin ?? DateTime.now();
    _wybranaGodzina = z != null ? TimeOfDay.fromDateTime(z.termin) : TimeOfDay.now();
    _wybranaKategoria = z?.kategoria ?? 'Dom';
    _wykonane = z?.wykonane ?? false;
    if (z != null) {
      _podzadania = z.podzadania.map((p) => Podzadanie(tytul: p.tytul, wykonane: p.wykonane)).toList();
      for (var i = 0; i < _podzadania.length; i++) {
        _podzadanieKontrolery[i] = TextEditingController(text: _podzadania[i].tytul);
      }
    }
  }

  Future<void> wybierzTerminGodzine() async {
    final DateTime? data = await showDatePicker(
      context: context,
      initialDate: _wybranyTermin,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pl'),
    );
    if (data != null) {
      if (!mounted) return;
      final TimeOfDay? godzina = await showTimePicker(
        context: context,
        initialTime: _wybranaGodzina,
        builder: (context, child) {
          return MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!);
        }
      );
      if (godzina != null) {
        setState(() {
          _wybranyTermin = data;
          _wybranaGodzina = godzina;
        });
      }
    }
  }

  void zapisz() {
    if (_formKey.currentState!.validate()) {
      final DateTime finalTermin = DateTime(
        _wybranyTermin.year, _wybranyTermin.month, _wybranyTermin.day,
        _wybranaGodzina.hour, _wybranaGodzina.minute,
      );
      final zadanie = Zadanie(
        id: widget.zadanieDoEdycji?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        tytul: _tytulController.text,
        opis: _opisController.text,
        termin: finalTermin,
        kategoria: _wybranaKategoria,
        wykonane: _wykonane,
        podzadania: _podzadania,
      );
      Provider.of<PlanerProvider>(context, listen: false).zapiszZadanie(zadanie, edycja: widget.zadanieDoEdycji != null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.zadanieDoEdycji != null ? 'Zadanie zaktualizowane!' : 'Dodano zadanie!'), backgroundColor: Colors.green)
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11131A),
      appBar: AppBar(
        title: Text(widget.zadanieDoEdycji != null ? 'Edycja' : 'Nowe Zadanie', style: const TextStyle(color: Color(0xFF64B5F6))),
        backgroundColor: const Color(0xFF181A22),
        elevation: 4,
        iconTheme: const IconThemeData(color: Color(0xFF64B5F6)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF11131A), Color(0xFF181A22), Color(0xFF23284D)],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _tytulController,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF64B5F6)),
                  decoration: const InputDecoration(
                    labelText: 'Tytuł',
                    prefixIcon: Icon(Icons.title, color: Color(0xFF64B5F6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  validator: (val) => val!.isEmpty ? 'Wpisz tytuł' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _opisController,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Opis (opcjonalnie)',
                    prefixIcon: Icon(Icons.notes, color: Color(0xFF64B5F6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                ),
                const SizedBox(height: 20),

                InkWell(
                  onTap: wybierzTerminGodzine,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF181A22), Color(0xFF23284D)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF23284D)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month, color: Color(0xFF64B5F6)),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Termin (Data i Godzina)", style: TextStyle(fontSize: 12, color: Colors.white70)),
                            Text(
                              "${DateFormat('dd.MM.yyyy').format(_wybranyTermin)}  |  ${_wybranaGodzina.format(context)}",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF64B5F6)),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.edit, size: 16, color: Colors.white70),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                DropdownButtonFormField<String>(
                  value: _wybranaKategoria,
                  decoration: const InputDecoration(
                    labelText: 'Kategoria',
                    prefixIcon: Icon(Icons.category, color: Color(0xFF64B5F6)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  ),
                  items: _kategorie.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setState(() => _wybranaKategoria = val!),
                ),

                const SizedBox(height: 20),
                Row(
                  children: [
                    Checkbox(
                      value: _wykonane,
                      activeColor: const Color(0xFF64B5F6),
                      onChanged: (v) {
                        setState(() {
                          _wykonane = v!;
                          for (var p in _podzadania) {
                            p.wykonane = _wykonane;
                          }
                        });
                      },
                    ),
                    const Text('Zadanie wykonane', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    const Spacer(),
                    if (_podzadania.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.done_all, color: Color(0xFF64B5F6)),
                        label: const Text('Wszystkie podzadania', style: TextStyle(color: Colors.white)),
                        onPressed: () {
                          setState(() {
                            bool wszystkieWykonane = _podzadania.every((p) => p.wykonane);
                            for (var p in _podzadania) {
                              p.wykonane = !wszystkieWykonane;
                            }
                            _wykonane = !wszystkieWykonane;
                          });
                        },
                      ),
                  ],
                ),

                const SizedBox(height: 20),
                const Text("LISTA KONTROLNA", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
                const SizedBox(height: 10),

                ..._podzadania.asMap().entries.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: e.value.wykonane,
                    activeColor: const Color(0xFF64B5F6),
                    onChanged: (v) => setState(() {
                      e.value.wykonane = v!;
                      if (_podzadania.isNotEmpty) {
                        bool wszystkieWykonane = _podzadania.every((p) => p.wykonane);
                        _wykonane = wszystkieWykonane;
                      }
                    }),
                  ),
                  title: TextFormField(
                    controller: _podzadanieKontrolery[e.key] ??= TextEditingController(text: e.value.tytul),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(border: InputBorder.none),
                    onChanged: (val) => setState(() => e.value.tytul = val),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () => setState(() {
                      _podzadania.removeAt(e.key);
                      _podzadanieKontrolery.remove(e.key);
                    }),
                  ),
                )),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _podzadanieController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(hintText: "Dodaj podzadanie...", hintStyle: TextStyle(color: Colors.white70)),
                        onSubmitted: (_) {
                          if (_podzadanieController.text.isNotEmpty && !_podzadania.any((p) => p.tytul == _podzadanieController.text)) {
                            setState(() {
                              _podzadania.add(Podzadanie(tytul: _podzadanieController.text));
                              _podzadanieController.clear();
                            });
                          }
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Color(0xFF64B5F6), size: 30),
                      onPressed: () {
                        if (_podzadanieController.text.isNotEmpty && !_podzadania.any((p) => p.tytul == _podzadanieController.text)) {
                          setState(() {
                            _podzadania.add(Podzadanie(tytul: _podzadanieController.text));
                            _podzadanieController.clear();
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
                    onPressed: zapisz,
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('ZAPISZ ZADANIE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF64B5F6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- EKRAN LISTY ZADAŃ ---
class ListaZadanEkran extends StatelessWidget {
  const ListaZadanEkran({super.key});

  @override
  Widget build(BuildContext context) {
    final zadania = context.watch<PlanerProvider>().zadania;
    return Scaffold(
      backgroundColor: const Color(0xFF11131A),
      appBar: AppBar(
        title: const Text('MiDaPlaner', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF181A22),
        elevation: 4,
        iconTheme: const IconThemeData(color: Color(0xFF64B5F6)),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF11131A), Color(0xFF181A22), Color(0xFF23284D)],
          ),
        ),
        child: zadania.isEmpty
            ? const Center(
                child: Text('Brak zadań', style: TextStyle(color: Colors.white70, fontSize: 18)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: zadania.length,
                itemBuilder: (context, idx) {
                  final z = zadania[idx];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF181A22), Color(0xFF23284D)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      title: Text(z.tytul, style: const TextStyle(color: Color(0xFF64B5F6), fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(z.termin), style: const TextStyle(color: Colors.white70)),
                      trailing: Icon(z.wykonane ? Icons.check_circle : Icons.radio_button_unchecked, color: z.wykonane ? Color(0xFF64B5F6) : Colors.white70),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FormularzZadaniaEkran(zadanieDoEdycji: z))),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF64B5F6),
        icon: const Icon(Icons.add, color: Color(0xFF181A22)),
        label: const Text('Dodaj zadanie', style: TextStyle(color: Color(0xFF181A22), fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FormularzZadaniaEkran())),
      ),
    );
  }
}