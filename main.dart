import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

const apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://10.0.2.2:3000');
const bg = Color(0xFF0D0F14);
const panel = Color(0xFF191C24);
const lime = Color(0xFFB8D94A);

void main() => runApp(const KoraApp());

class KoraApp extends StatelessWidget {
  const KoraApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'كورة AI',
    theme: ThemeData.dark().copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: lime, surface: panel),
      appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0),
      cardColor: panel,
    ),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime selected = DateTime.now();
  int tab = 0;
  bool loading = false;
  String? error;
  List<dynamic> matches = [];
  final leagues = const [
    {'id': 39, 'name': 'الإنجليزي'}, {'id': 140, 'name': 'الإسباني'},
    {'id': 78, 'name': 'الألماني'}, {'id': 135, 'name': 'الإيطالي'},
    {'id': 61, 'name': 'الفرنسي'}, {'id': 2, 'name': 'أبطال أوروبا'}
  ];
  final Set<int> selectedLeagues = {39, 140, 78, 135, 61, 2};

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final date = DateFormat('yyyy-MM-dd').format(selected);
      final ids = selectedLeagues.join(',');
      final uri = Uri.parse('$apiBase/fixtures?date=$date&leagues=$ids&season=${selected.year}');
      final r = await http.get(uri).timeout(const Duration(seconds: 25));
      if (r.statusCode != 200) throw Exception(jsonDecode(r.body)['error'] ?? 'تعذر جلب المباريات');
      matches = jsonDecode(r.body) as List<dynamic>;
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => loading = false);
  }

  void shift(int days) { selected = selected.add(Duration(days: days)); load(); }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('MM/dd').format(selected);
    return Scaffold(
      appBar: AppBar(
        title: const Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('كورة AI', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
          Text('تحليل وتوقعات المباريات بالذكاء الاصطناعي', style: TextStyle(fontSize: 11, color: Colors.white54))
        ]),
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh, color: lime))],
      ),
      body: Column(children: [
        SizedBox(height: 54, child: ListView(scrollDirection: Axis.horizontal, reverse: true, children: [
          _dateChip('أمس', -1), _dateChip('اليوم', 0), _dateChip('غداً', 1),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Center(child: Text(dateText, style: const TextStyle(color: lime))))
        ])),
        SizedBox(height: 54, child: ListView(scrollDirection: Axis.horizontal, reverse: true, children: leagues.map((l) {
          final id = l['id'] as int; final on = selectedLeagues.contains(id);
          return Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), child: FilterChip(
            selected: on, label: Text(l['name'] as String), onSelected: (v) {
              setState(() { v ? selectedLeagues.add(id) : selectedLeagues.remove(id); }); load();
            }, selectedColor: lime.withOpacity(.2), checkmarkColor: lime,
          ));
        }).toList())),
        Expanded(child: loading
          ? const Center(child: CircularProgressIndicator(color: lime))
          : error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.wifi_off, color: Colors.orange, size: 36),
              const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center),
              TextButton(onPressed: load, child: const Text('إعادة المحاولة'))
            ])))
          : matches.isEmpty ? const Center(child: Text('لا توجد مباريات في هذا اليوم'))
          : RefreshIndicator(color: lime, onRefresh: load, child: ListView.builder(
              padding: const EdgeInsets.all(12), itemCount: matches.length,
              itemBuilder: (_, i) => MatchCard(match: matches[i]),
            )),
        ),
        const Padding(padding: EdgeInsets.all(10), child: Text('التوقعات احتمالية وتجريبية وليست ضماناً للنتائج.', style: TextStyle(color: Colors.white38, fontSize: 10)))
      ]),
    );
  }

  Widget _dateChip(String label, int delta) {
    final active = DateUtils.isSameDay(selected, DateTime.now().add(Duration(days: delta)));
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6), child: ChoiceChip(
      label: Text(label), selected: active, onSelected: (_) { selected = DateTime.now().add(Duration(days: delta)); load(); },
      selectedColor: lime.withOpacity(.22), labelStyle: TextStyle(color: active ? lime : Colors.white70),
    ));
  }
}

class MatchCard extends StatelessWidget {
  final dynamic match;
  const MatchCard({super.key, required this.match});
  @override
  Widget build(BuildContext context) {
    final fixture = match['fixture']; final teams = match['teams']; final league = match['league'];
    final home = teams['home']; final away = teams['away'];
    final status = fixture['status']['short'];
    final time = DateFormat('HH:mm').format(DateTime.parse(fixture['date']).toLocal());
    final score = match['goals'];
    return Card(
      margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(league['name'] ?? '', style: const TextStyle(color: lime, fontSize: 11)),
          Text(status == 'NS' ? time : status, style: const TextStyle(color: Colors.white54, fontSize: 11))
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _team(home)), 
          Column(children: [Text('${score['home'] ?? '-'} : ${score['away'] ?? '-'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const Text('النتيجة', style: TextStyle(fontSize: 10, color: Colors.white38))]),
          Expanded(child: _team(away)),
        ]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: lime, side: const BorderSide(color: lime)),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AnalysisPage(id: fixture['id'].toString()))),
          icon: const Icon(Icons.auto_awesome), label: const Text('تحليل المباراة و5 توقعات'),
        ))
      ])),
    );
  }
  Widget _team(dynamic t) => Column(children: [
    if (t['logo'] != null) Image.network(t['logo'], width: 34, height: 34, errorBuilder: (_,__,___) => const Icon(Icons.shield, size: 34)),
    const SizedBox(height: 5), Text(t['name'] ?? '', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))
  ]);
}

class AnalysisPage extends StatefulWidget {
  final String id;
  const AnalysisPage({super.key, required this.id});
  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}
class _AnalysisPageState extends State<AnalysisPage> {
  Map<String, dynamic>? data; String? error;
  @override
  void initState() { super.initState(); fetch(); }
  Future<void> fetch() async {
    try {
      final r = await http.get(Uri.parse('$apiBase/predictions/${widget.id}')).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw Exception(jsonDecode(r.body)['error']);
      data = jsonDecode(r.body);
    } catch (e) { error = e.toString(); }
    if (mounted) setState(() {});
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('تحليل المباراة')),
    body: data == null && error == null ? const Center(child: CircularProgressIndicator(color: lime))
      : error != null ? Center(child: Text(error!))
      : ListView(padding: const EdgeInsets.all(16), children: [
          Text('${data!['home']} × ${data!['away']}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
          const SizedBox(height: 18),
          ...(data!['predictions'] as List).asMap().entries.map((entry) {
            final p = entry.value;
            return Card(color: panel, child: ListTile(
              leading: CircleAvatar(backgroundColor: lime.withOpacity(.15), child: Text('${entry.key + 1}', style: const TextStyle(color: lime))),
              title: Text(p['title']), subtitle: Text('${p['value']}\n${p['note']}'),
              trailing: Text(p['probability'], style: const TextStyle(color: lime, fontWeight: FontWeight.bold)),
              isThreeLine: true,
            ));
          }),
          const SizedBox(height: 10),
          const Text('تنبيه: هذه النسخة تعرض مؤشرات تجريبية وليست نموذجاً مدرباً أو احتمالات موثوقة. لا تستخدمها لاتخاذ قرارات مالية.', style: TextStyle(color: Colors.orangeAccent, fontSize: 12))
        ]),
  );
}
