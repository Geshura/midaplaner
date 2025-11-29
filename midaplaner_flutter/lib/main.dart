import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
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
      debugShowCheckedModeBanner: false,
      title: 'MiDaPlaner',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF11131A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF64B5F6),
          secondary: Color(0xFF23284D),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF181A22),
          elevation: 4,
        ),
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('pl'),
        const Locale('en'),
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/zadania': (context) => const ListaZadanEkran(),
      },
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
                  int podzDone = z.podzadania.where((p) => p.wykonane).length;
                  int podzAll = z.podzadania.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF181A22), Color(0xFF23284D)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.35 * 255).round()),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: Color(0xFF64B5F6).withAlpha(60), width: 1.5),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        cardColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                        childrenPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        backgroundColor: Colors.transparent,
                        title: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(z.tytul, style: const TextStyle(color: Color(0xFF64B5F6), fontWeight: FontWeight.bold, fontSize: 19)),
                                  const SizedBox(height: 2),
                                  Text(DateFormat('dd.MM.yyyy HH:mm').format(z.termin), style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                ],
                              ),
                            ),
                            if (podzAll > 0)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF23284D),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text('$podzDone/$podzAll', style: const TextStyle(color: Color(0xFF64B5F6), fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                              ),
                            Switch(
                              value: z.wykonane,
                              activeThumbColor: Color(0xFF64B5F6),
                              inactiveTrackColor: Colors.white24,
                              onChanged: (v) {
                                final provider = Provider.of<PlanerProvider>(context, listen: false);
                                provider.zapiszZadanie(Zadanie(
                                  id: z.id,
                                  tytul: z.tytul,
                                  opis: z.opis,
                                  termin: z.termin,
                                  kategoria: z.kategoria,
                                  wykonane: v,
                                  podzadania: z.podzadania,
                                ), edycja: true);
                              },
                            ),
                          ],
                        ),
                        trailing: null,
                        children: [
                          if (z.opis.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(z.opis, style: const TextStyle(color: Colors.white70)),
                            ),
                          Text('Kategoria: ${z.kategoria}', style: const TextStyle(color: Colors.white54)),
                          const SizedBox(height: 8),
                          if (z.podzadania.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Podzadania:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                                ...z.podzadania.map((p) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    children: [
                                      Icon(p.wykonane ? Icons.check_box : Icons.check_box_outline_blank, color: p.wykonane ? Color(0xFF64B5F6) : Colors.white38, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(p.tytul, style: const TextStyle(color: Colors.white)) ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (podzAll > 0)
                                Text('Wykonanych podzadań: $podzDone/$podzAll', style: const TextStyle(color: Color(0xFF64B5F6), fontWeight: FontWeight.bold)),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => FormularzZadaniaEkran(zadanieDoEdycji: z),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit, color: Color(0xFF64B5F6)),
                                label: const Text('Edytuj', style: TextStyle(color: Color(0xFF64B5F6))),                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF64B5F6),
        icon: const Icon(Icons.add, color: Color(0xFF181A22)),
        label: const Text('Dodaj zadanie', style: TextStyle(color: Color(0xFF181A22), fontWeight: FontWeight.bold)),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FormularzZadaniaEkran())),
      ),
    );
  }
}

// --- EKRAN FORMULARZA ZADANIA ---
class FormularzZadaniaEkran extends StatefulWidget {
  final Zadanie? zadanieDoEdycji;
  const FormularzZadaniaEkran({Key? key, this.zadanieDoEdycji}) : super(key: key);

  @override
  State<FormularzZadaniaEkran> createState() => _FormularzZadaniaEkranState();
}

class _FormularzZadaniaEkranState extends State<FormularzZadaniaEkran> {
  late TextEditingController tytulController;
  late TextEditingController opisController;
  late DateTime wybranyTermin;
  late TimeOfDay wybranaGodzina;
  late String wybranaKategoria;
  late bool wykonane;
  late List<Podzadanie> podzadania;
  late TextEditingController podzadanieController;

  final List<String> kategorie = ['Praca', 'Dom', 'Szkoła', 'Inne'];

  @override
  void initState() {
    super.initState();
    final z = widget.zadanieDoEdycji;
    tytulController = TextEditingController(text: z?.tytul ?? '');
    opisController = TextEditingController(text: z?.opis ?? '');
    wybranyTermin = z?.termin ?? DateTime.now();
    wybranaGodzina = TimeOfDay.fromDateTime(z?.termin ?? DateTime.now());
    wybranaKategoria = z?.kategoria ?? kategorie.first;
    wykonane = z?.wykonane ?? false;
    podzadania = z?.podzadania.map((p) => Podzadanie(tytul: p.tytul, wykonane: p.wykonane)).toList() ?? [];
    podzadanieController = TextEditingController();
  }

  @override
  void dispose() {
    tytulController.dispose();
    opisController.dispose();
    podzadanieController.dispose();
    super.dispose();
  }

  Future<void> wybierzTermin() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: wybranyTermin,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('pl'),
    );
    if (picked != null) setState(() => wybranyTermin = picked);
  }

  Future<void> wybierzGodzine() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: wybranaGodzina,
    );
    if (picked != null) setState(() => wybranaGodzina = picked);
  }

  void zapisz() {
    final provider = Provider.of<PlanerProvider>(context, listen: false);
    final termin = DateTime(
      wybranyTermin.year,
      wybranyTermin.month,
      wybranyTermin.day,
      wybranaGodzina.hour,
      wybranaGodzina.minute,
    );
    final noweZadanie = Zadanie(
      id: widget.zadanieDoEdycji?.id ?? UniqueKey().toString(),
      tytul: tytulController.text,
      opis: opisController.text,
      termin: termin,
      kategoria: wybranaKategoria,
      wykonane: wykonane,
      podzadania: podzadania,
    );
    provider.zapiszZadanie(noweZadanie, edycja: widget.zadanieDoEdycji != null);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF11131A),
      appBar: AppBar(
        title: Text(widget.zadanieDoEdycji == null ? 'Dodaj zadanie' : 'Edytuj zadanie'),
        backgroundColor: const Color(0xFF181A22),
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: tytulController,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              decoration: const InputDecoration(
                labelText: 'Tytuł zadania',
                labelStyle: TextStyle(color: Color(0xFF64B5F6)),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: opisController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Opis (opcjonalnie)',
                labelStyle: TextStyle(color: Color(0xFF64B5F6)),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: wybierzTermin,
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
                              const Text("Data", style: TextStyle(fontSize: 12, color: Colors.white70)),
                              Text(
                                DateFormat('dd.MM.yyyy').format(wybranyTermin),
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: wybierzGodzine,
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
                          const Icon(Icons.access_time, color: Color(0xFF64B5F6)),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Godzina", style: TextStyle(fontSize: 12, color: Colors.white70)),
                              Text(
                                wybranaGodzina.format(context),
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
                ),
              ],
            ),
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
              value: wybranaKategoria,
              decoration: const InputDecoration(
                labelText: 'Kategoria',
                labelStyle: TextStyle(color: Color(0xFF64B5F6)),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              items: kategorie.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (val) => setState(() => wybranaKategoria = val!),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text('Status:', style: TextStyle(color: Colors.white70)),
                const SizedBox(width: 10),
                Switch(
                  value: wykonane,
                  activeThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  onChanged: (v) => setState(() => wykonane = v),
                ),
                Text(wykonane ? 'WYKONANE' : 'NIEWYKONANE', style: TextStyle(color: wykonane ? Colors.white : const Color(0xFF64B5F6), fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 18),
            const Text("Podzadania", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            ...podzadania.asMap().entries.map((e) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: TextFormField(
                initialValue: e.value.tytul,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(border: InputBorder.none),
                onChanged: (val) => setState(() => podzadania[e.key].tytul = val),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: () => setState(() => podzadania.removeAt(e.key)),
              ),
            )),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: podzadanieController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(hintText: "Dodaj podzadanie...", hintStyle: TextStyle(color: Colors.white70)),
                    onSubmitted: (_) {
                      if (podzadanieController.text.isNotEmpty && !podzadania.any((p) => p.tytul == podzadanieController.text)) {
                        setState(() {
                          podzadania.add(Podzadanie(tytul: podzadanieController.text));
                          podzadanieController.clear();
                        });
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFF64B5F6), size: 30),
                  onPressed: () {
                    if (podzadanieController.text.isNotEmpty && !podzadania.any((p) => p.tytul == podzadanieController.text)) {
                      setState(() {
                        podzadania.add(Podzadanie(tytul: podzadanieController.text));
                        podzadanieController.clear();
                      });
                    }
                  },
                )
              ],
            ),
            const SizedBox(height: 30),
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
          ],
        ),
      ),
    );
  }
}