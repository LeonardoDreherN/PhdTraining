import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'avaliacao_neuromotores_widgets.dart';

// SQL (Supabase):
// ALTER TABLE avaliacao_neuromotores_impulsao
//   ADD COLUMN IF NOT EXISTS tipo text DEFAULT 'horizontal',
//   ADD COLUMN IF NOT EXISTS analise text;
// (columns impulsao_horizontal and impulsao_vertical already exist)

// Norms — [t1, t2, t3, t4]
// Fraco < t1 | Abaixo t1-t2 | Média t2+1-t3 | Acima t3+1-t4 | Excelente > t4
const _horizMale   = [228, 242, 256, 270]; // standing broad jump (cm)
const _horizFemale = [168, 183, 198, 213];
const _vertMale    = [31, 40, 50, 60];     // Sargent test (cm)
const _vertFemale  = [21, 29, 38, 47];

String _classImpulsao(double val, List<int> norma) {
  if (val < norma[0]) return 'Fraco';
  if (val <= norma[1]) return 'Abaixo da Média';
  if (val <= norma[2]) return 'Média';
  if (val <= norma[3]) return 'Acima da Média';
  return 'Excelente';
}

Color _corImpClass(String? c) {
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
// LIST SCREEN — tabs Horizontal / Vertical
// ─────────────────────────────────────────────────────────────
class AvaliacaoImpulsaoScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  const AvaliacaoImpulsaoScreen({super.key, required this.aluno});
  @override
  State<AvaliacaoImpulsaoScreen> createState() => _AvaliacaoImpulsaoScreenState();
}

class _AvaliacaoImpulsaoScreenState extends State<AvaliacaoImpulsaoScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _horiz = [];
  List<Map<String, dynamic>> _vert  = [];
  bool _carregando = true;

  @override
  void initState() { super.initState(); _carregar(); }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final data = await _db
          .from('avaliacao_neuromotores_impulsao')
          .select()
          .eq('aluno_id', widget.aluno['id'] as String)
          .eq('excluida', false)
          .order('data_avaliacao', ascending: false);
      final list = List<Map<String, dynamic>>.from(data);
      setState(() {
        _horiz = list.where((r) => (r['tipo'] ?? 'horizontal') == 'horizontal').toList();
        _vert  = list.where((r) => r['tipo'] == 'vertical').toList();
      });
    } catch (_) {}
    setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    final nome = (widget.aluno['nome'] as String? ?? '').split(' ').take(2).join(' ');
    return Scaffold(
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
          tabs: const [Tab(text: 'Horizontal'), Tab(text: 'Vertical')],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _ListaTab(
            aluno: widget.aluno, tipo: 'horizontal',
            titulo: 'Impulsão horizontal', lista: _horiz, carregando: _carregando,
            onNova: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AvaliacaoImpulsaoFormScreen(aluno: widget.aluno, tipo: 'horizontal'),
            )).then((_) => _carregar()),
            onEditar: (av) => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AvaliacaoImpulsaoFormScreen(aluno: widget.aluno, tipo: 'horizontal', avaliacao: av),
            )).then((_) => _carregar()),
          ),
          _ListaTab(
            aluno: widget.aluno, tipo: 'vertical',
            titulo: 'Impulsão vertical', lista: _vert, carregando: _carregando,
            onNova: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AvaliacaoImpulsaoFormScreen(aluno: widget.aluno, tipo: 'vertical'),
            )).then((_) => _carregar()),
            onEditar: (av) => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AvaliacaoImpulsaoFormScreen(aluno: widget.aluno, tipo: 'vertical', avaliacao: av),
            )).then((_) => _carregar()),
          ),
        ],
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8)),
            child: Text(titulo,
                style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
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
              final val = tipo == 'horizontal'
                  ? (av['impulsao_horizontal'] as num?)?.toDouble()
                  : (av['impulsao_vertical'] as num?)?.toDouble();
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
                      if (val != null)
                        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text('${val.toStringAsFixed(0)} cm',
                              style: GoogleFonts.montserrat(
                                  color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                          Text('distância',
                              style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 11)),
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
class AvaliacaoImpulsaoFormScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  final String tipo; // 'horizontal' | 'vertical'
  final Map<String, dynamic>? avaliacao;
  const AvaliacaoImpulsaoFormScreen({
    super.key, required this.aluno, required this.tipo, this.avaliacao,
  });
  @override
  State<AvaliacaoImpulsaoFormScreen> createState() => _AvaliacaoImpulsaoFormScreenState();
}

class _AvaliacaoImpulsaoFormScreenState extends State<AvaliacaoImpulsaoFormScreen> {
  final _db = Supabase.instance.client;
  bool _salvando = false;
  DateTime _data = DateTime.now();
  String genero = 'Masculino';
  double? medida;
  final _analiseCtrl = TextEditingController();

  bool get _isHoriz => widget.tipo == 'horizontal';

  @override
  void initState() {
    super.initState();
    genero = widget.aluno['genero'] as String? ?? 'Masculino';
    final av = widget.avaliacao;
    if (av != null) {
      if (av['data_avaliacao'] != null) {
        _data = DateTime.tryParse(av['data_avaliacao'] as String) ?? _data;
      }
      genero = av['genero'] as String? ?? genero;
      medida = _isHoriz
          ? (av['impulsao_horizontal'] as num?)?.toDouble()
          : (av['impulsao_vertical'] as num?)?.toDouble();
      _analiseCtrl.text = av['analise'] as String? ?? '';
    }
  }

  @override
  void dispose() { _analiseCtrl.dispose(); super.dispose(); }

  bool get _podeSalvar => medida != null;

  List<int> get _norma {
    final isFemale = genero.toLowerCase().startsWith('f');
    if (_isHoriz) return isFemale ? _horizFemale : _horizMale;
    return isFemale ? _vertFemale : _vertMale;
  }

  String? get _classif => medida != null ? _classImpulsao(medida!, _norma) : null;

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
        if (_isHoriz) 'impulsao_horizontal': medida else 'impulsao_vertical': medida,
        'analise': _analiseCtrl.text.trim(),
      };
      if (widget.avaliacao != null) {
        await _db.from('avaliacao_neuromotores_impulsao')
            .update(payload).eq('id', widget.avaliacao!['id'] as String);
      } else {
        await _db.from('avaliacao_neuromotores_impulsao').insert(payload);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) neuroShowErro(context, e); }
    if (mounted) setState(() => _salvando = false);
  }

  String get _titulo => _isHoriz ? 'Impulsão horizontal' : 'Impulsão vertical';
  String get _fieldLabel => _isHoriz ? 'Distância do melhor salto' : 'Altura do melhor salto';

  @override
  Widget build(BuildContext context) {
    final classif = _classif;
    final norma = _norma;

    return NeuromotoresFormScaffold(
      titulo: _titulo,
      aluno: widget.aluno,
      salvando: _salvando,
      podeSalvar: _podeSalvar,
      onSalvar: _salvar,
      sections: [
        NeuroSecao('', [
          NeuroLinhaEdit(
            _fieldLabel,
            medida != null ? '${medida!.toStringAsFixed(0)} cm' : '—',
            () => neuroEditDouble(context, _fieldLabel, 'cm', medida, (v) => setState(() => medida = v)),
          ),
          NeuroLinhaDate('Data', _data, (d) => setState(() => _data = d)),
          if (classif != null)
            NeuroLinhaCalc('Classificação', classif,
                badge: classif, badgeColor: _corImpClass(classif)),
        ]),
        NeuroSecao('Análise', [
          NeuroLinhaTextarea('', _analiseCtrl),
        ]),
        NeuroSecao('Tabela de Referência', [
          _TabelaReferencia(titulo: _titulo, norma: norma),
        ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Reference table (single age group for impulsão)
// ─────────────────────────────────────────────────────────────
class _TabelaReferencia extends StatelessWidget {
  final String titulo;
  final List<int> norma;
  const _TabelaReferencia({required this.titulo, required this.norma});

  @override
  Widget build(BuildContext context) {
    final labels = ['Fraco', 'Abaixo da Média', 'Média', 'Acima da Média', 'Excelente'];
    final cores  = [Colors.red, Colors.orange, Colors.amber, const Color(0xFF8BC34A), Colors.green];
    final ranges = [
      '<${norma[0]}',
      '${norma[0]}-${norma[1]}',
      '${norma[1] + 1}-${norma[2]}',
      '${norma[2] + 1}-${norma[3]}',
      '${norma[3] + 1}+',
    ];

    return Container(
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
              Text('Idade 15+',
                  style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 11)),
            ]),
          ),
          const Divider(height: 1, color: Colors.white12),
          ...List.generate(5, (i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: cores[i], shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(labels[i], style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 13)),
                ]),
                Text('${ranges[i]} cm', style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
