import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'avaliacao_neuromotores_widgets.dart';

// SQL (Supabase):
// ALTER TABLE avaliacao_neuromotores_resistencia
//   ADD COLUMN IF NOT EXISTS tipo text DEFAULT 'abdominal',
//   ADD COLUMN IF NOT EXISTS analise text;
// (columns abdominal_reps and flexao_braco_reps already exist)

// Pollock & Willmore (1993) norms — [ageMin, ageMax, t1, t2, t3, t4]
// Fraco < t1 | Abaixo t1-t2 | Média t2+1-t3 | Acima t3+1-t4 | Excelente > t4
const _abdMale = [
  [20, 29, 28, 32, 36, 42],
  [30, 39, 22, 26, 30, 36],
  [40, 49, 18, 22, 26, 31],
  [50, 59, 15, 19, 23, 28],
  [60, 99, 10, 14, 18, 23],
];
const _abdFemale = [
  [20, 29, 28, 32, 35, 42],
  [30, 39, 17, 22, 27, 32],
  [40, 49, 14, 18, 23, 28],
  [50, 59, 10, 14, 18, 23],
  [60, 99,  6, 10, 14, 18],
];
const _bracMale = [
  [20, 29, 16, 21, 28, 35],
  [30, 39, 12, 16, 21, 28],
  [40, 49, 10, 14, 19, 24],
  [50, 59,  7, 11, 16, 20],
  [60, 99,  5, 10, 14, 18],
];
const _bracFemale = [
  [20, 29, 11, 15, 20, 29],
  [30, 39,  8, 12, 19, 26],
  [40, 49,  5,  9, 14, 23],
  [50, 59,  3,  7, 11, 20],
  [60, 99,  2,  4,  9, 16],
];

String _classResist(int reps, List<int> row) {
  if (reps < row[2]) return 'Fraco';
  if (reps <= row[3]) return 'Abaixo da Média';
  if (reps <= row[4]) return 'Média';
  if (reps <= row[5]) return 'Acima da Média';
  return 'Excelente';
}

Color _corResistClass(String? c) {
  switch (c) {
    case 'Excelente': return Colors.green;
    case 'Acima da Média': return const Color(0xFF8BC34A);
    case 'Média': return Colors.amber;
    case 'Abaixo da Média': return Colors.orange;
    case 'Fraco': return Colors.red;
    default: return Colors.grey;
  }
}

// ─────────────────────────────────────────────────────────────
// LIST SCREEN — tabbed (Abdominal / Braços)
// ─────────────────────────────────────────────────────────────
class AvaliacaoResistenciaScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  const AvaliacaoResistenciaScreen({super.key, required this.aluno});
  @override
  State<AvaliacaoResistenciaScreen> createState() => _AvaliacaoResistenciaScreenState();
}

class _AvaliacaoResistenciaScreenState extends State<AvaliacaoResistenciaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _abd = [];
  List<Map<String, dynamic>> _brac = [];
  bool _carregando = true;

  @override
  void initState() { super.initState(); _carregar(); }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final data = await _db
          .from('avaliacao_neuromotores_resistencia')
          .select()
          .eq('aluno_id', widget.aluno['id'] as String)
          .eq('excluida', false)
          .order('data_avaliacao', ascending: false);
      final list = List<Map<String, dynamic>>.from(data);
      setState(() {
        _abd  = list.where((r) => (r['tipo'] ?? 'abdominal') == 'abdominal').toList();
        _brac = list.where((r) => r['tipo'] == 'braco').toList();
      });
    } catch (_) {}
    setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    final nome = (widget.aluno['nome'] as String? ?? '').split(' ').take(2).join(' ');
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          title: Text(nome, style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w600)),
          bottom: TabBar(
            controller: _tab,
            indicatorColor: AppColors.textPrimary,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            labelStyle: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [Tab(text: 'Abdominal'), Tab(text: 'Braços')],
          ),
        ),
        body: TabBarView(
          controller: _tab,
          children: [
            _ListaTab(
              aluno: widget.aluno,
              tipo: 'abdominal',
              titulo: 'Res. Muscular Localizada / Abdominal (RML)',
              lista: _abd,
              carregando: _carregando,
              onNova: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AvaliacaoResistenciaFormScreen(aluno: widget.aluno, tipo: 'abdominal'),
              )).then((_) => _carregar()),
              onEditar: (av) => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AvaliacaoResistenciaFormScreen(aluno: widget.aluno, tipo: 'abdominal', avaliacao: av),
              )).then((_) => _carregar()),
            ),
            _ListaTab(
              aluno: widget.aluno,
              tipo: 'braco',
              titulo: 'Res. Muscular Localizada / Braços (RML)',
              lista: _brac,
              carregando: _carregando,
              onNova: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AvaliacaoResistenciaFormScreen(aluno: widget.aluno, tipo: 'braco'),
              )).then((_) => _carregar()),
              onEditar: (av) => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AvaliacaoResistenciaFormScreen(aluno: widget.aluno, tipo: 'braco', avaliacao: av),
              )).then((_) => _carregar()),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaTab extends StatelessWidget {
  final Map<String, dynamic> aluno;
  final String tipo;
  final String titulo;
  final List<Map<String, dynamic>> lista;
  final bool carregando;
  final VoidCallback onNova;
  final void Function(Map<String, dynamic>) onEditar;
  const _ListaTab({
    required this.aluno, required this.tipo, required this.titulo,
    required this.lista, required this.carregando,
    required this.onNova, required this.onEditar,
  });

  String _dataFmt(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2,'0')}/${dt.month.toString().padLeft(2,'0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // section header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(titulo,
                style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          // add button
          GestureDetector(
            onTap: onNova,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text('Realizar novo teste',
                    style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          if (carregando)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (lista.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Column(children: [
                  const Icon(Icons.description_outlined, color: Colors.white38, size: 48),
                  const SizedBox(height: 12),
                  Text('Você ainda não realizou nenhum teste para esse aluno',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 13)),
                ]),
              ),
            )
          else
            ...lista.map((av) {
              final reps = tipo == 'abdominal'
                  ? (av['abdominal_reps'] as num?)?.toInt()
                  : (av['flexao_braco_reps'] as num?)?.toInt();
              return GestureDetector(
                onTap: () => onEditar(av),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_dataFmt(av['data_avaliacao'] as String?),
                          style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 14)),
                      if (reps != null)
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('$reps reps',
                              style: GoogleFonts.montserrat(
                                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                          Text('repetições',
                              style: GoogleFonts.montserrat(
                                  color: AppColors.textSecondary, fontSize: 11)),
                        ]),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FORM SCREEN
// ─────────────────────────────────────────────────────────────
class AvaliacaoResistenciaFormScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  final String tipo; // 'abdominal' | 'braco'
  final Map<String, dynamic>? avaliacao;
  const AvaliacaoResistenciaFormScreen({
    super.key, required this.aluno, required this.tipo, this.avaliacao,
  });
  @override
  State<AvaliacaoResistenciaFormScreen> createState() => _AvaliacaoResistenciaFormScreenState();
}

class _AvaliacaoResistenciaFormScreenState extends State<AvaliacaoResistenciaFormScreen> {
  final _db = Supabase.instance.client;
  bool _salvando = false;
  DateTime _data = DateTime.now();
  String genero = 'Masculino';
  int? idade;
  int? reps;
  final _analiseCtrl = TextEditingController();

  bool get _isAbd => widget.tipo == 'abdominal';

  @override
  void initState() {
    super.initState();
    genero = widget.aluno['genero'] as String? ?? 'Masculino';
    final nasc = widget.aluno['data_nascimento'] as String?;
    if (nasc != null) {
      final dt = DateTime.tryParse(nasc);
      if (dt != null) {
        idade = DateTime.now().year - dt.year;
      }
    }
    final av = widget.avaliacao;
    if (av != null) {
      if (av['data_avaliacao'] != null) {
        _data = DateTime.tryParse(av['data_avaliacao'] as String) ?? _data;
      }
      genero = av['genero'] as String? ?? genero;
      idade = (av['idade'] as num?)?.toInt() ?? idade;
      reps = _isAbd
          ? (av['abdominal_reps'] as num?)?.toInt()
          : (av['flexao_braco_reps'] as num?)?.toInt();
      _analiseCtrl.text = av['analise'] as String? ?? '';
    }
  }

  @override
  void dispose() { _analiseCtrl.dispose(); super.dispose(); }

  bool get _podeSalvar => reps != null;

  List<int>? get _normaRow {
    if (idade == null) return null;
    final isFemale = genero.toLowerCase().startsWith('f');
    final tabela = _isAbd
        ? (isFemale ? _abdFemale : _abdMale)
        : (isFemale ? _bracFemale : _bracMale);
    return _normaRow2(tabela, idade!);
  }

  List<int> _normaRow2(List<List<int>> tabela, int idade) {
    for (final r in tabela) {
      if (idade >= r[0] && idade <= r[1]) return r;
    }
    return tabela.last;
  }

  String? get _classif {
    final row = _normaRow;
    if (row == null || reps == null) return null;
    return _classResist(reps!, row);
  }

  Future<void> _salvar() async {
    if (!_podeSalvar) return;
    setState(() => _salvando = true);
    try {
      String dtStr(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      final payload = <String, dynamic>{
        'aluno_id': widget.aluno['id'] as String,
        'data_avaliacao': dtStr(_data),
        'genero': genero,
        'tipo': widget.tipo,
        if (idade != null) 'idade': idade,
        if (_isAbd) 'abdominal_reps': reps else 'flexao_braco_reps': reps,
        'analise': _analiseCtrl.text.trim(),
      };
      if (widget.avaliacao != null) {
        await _db.from('avaliacao_neuromotores_resistencia')
            .update(payload).eq('id', widget.avaliacao!['id'] as String);
      } else {
        await _db.from('avaliacao_neuromotores_resistencia').insert(payload);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) neuroShowErro(context, e); }
    if (mounted) setState(() => _salvando = false);
  }

  String get _titulo => _isAbd
      ? 'Res. Muscular Localizada / Abdominal (RML)'
      : 'Res. Muscular Localizada / Braços (RML)';

  String get _fieldLabel => _isAbd
      ? 'Flexões abdominais por minuto'
      : 'Flexões de braço por minuto';

  @override
  Widget build(BuildContext context) {
    final classif = _classif;
    final isFemale = genero.toLowerCase().startsWith('f');
    final tabela = _isAbd
        ? (isFemale ? _abdFemale : _abdMale)
        : (isFemale ? _bracFemale : _bracMale);

    return NeuromotoresFormScaffold(
      titulo: _titulo,
      subtitulo: 'Pollock & Willmore (1993)',
      aluno: widget.aluno,
      salvando: _salvando,
      podeSalvar: _podeSalvar,
      onSalvar: _salvar,
      sections: [
        NeuroSecao('', [
          NeuroLinhaEdit(
            _fieldLabel,
            reps != null ? '$reps reps' : '—',
            () => neuroEditInt(context, _fieldLabel, 'reps', reps, (v) => setState(() => reps = v)),
          ),
          NeuroLinhaDate('Data', _data, (d) => setState(() => _data = d)),
          if (classif != null)
            NeuroLinhaCalc('Classificação', classif,
                badge: classif, badgeColor: _corResistClass(classif)),
        ]),
        NeuroSecao('Análise', [
          NeuroLinhaTextarea('', _analiseCtrl),
        ]),
        NeuroSecao('Tabela de Referência', [
          _TabelaReferencia(tabela: tabela, titulo: _titulo),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reference table widget
// ─────────────────────────────────────────────────────────────
class _TabelaReferencia extends StatelessWidget {
  final List<List<int>> tabela;
  final String titulo;
  const _TabelaReferencia({required this.tabela, required this.titulo});

  @override
  Widget build(BuildContext context) {
    final labels = ['Fraco', 'Abaixo da Média', 'Média', 'Acima da Média', 'Excelente'];
    final cores = [Colors.red, Colors.orange, Colors.amber, const Color(0xFF8BC34A), Colors.green];

    return Column(
      children: tabela.map((row) {
        final ageLabel = '${row[0]}-${row[1] == 99 ? '60+' : row[1]}';
        final ranges = [
          '<${row[2]}',
          '${row[2]}-${row[3]}',
          '${row[3] + 1}-${row[4]}',
          '${row[4] + 1}-${row[5]}',
          '${row[5] + 1}+',
        ];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(titulo,
                      style: GoogleFonts.montserrat(
                          color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('Idade $ageLabel',
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary, fontSize: 11)),
                ]),
              ),
              const Divider(height: 1, color: Colors.white12),
              ...List.generate(5, (i) => _LinhaTabela(labels[i], ranges[i], cores[i])),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _LinhaTabela extends StatelessWidget {
  final String label;
  final String valor;
  final Color cor;
  const _LinhaTabela(this.label, this.valor, this.cor);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 13)),
          ]),
          Text('$valor reps', style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
