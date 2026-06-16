import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'avaliacao_neuromotores_widgets.dart';

// SQL (run once in Supabase):
// CREATE TABLE avaliacao_neuromotores_flexibilidade (
//   id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
//   aluno_id uuid REFERENCES alunos(id) ON DELETE CASCADE,
//   data_avaliacao date DEFAULT CURRENT_DATE,
//   genero text, idade integer,
//   alcance real,
//   analise text,
//   excluida boolean DEFAULT false,
//   created_at timestamptz DEFAULT now()
// );
// ALTER TABLE avaliacao_neuromotores_flexibilidade ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "access_neuro_flex" ON avaliacao_neuromotores_flexibilidade
//   FOR ALL USING (auth.role() = 'authenticated');

// Wells & Dillon (1952) norms — cm, by gender & age group
const _wellsMale = [
  [20, 29, 24, 29, 30, 33, 34, 39],
  [30, 39, 23, 28, 29, 32, 33, 38],
  [40, 49, 21, 26, 27, 30, 31, 36],
  [50, 99, 19, 24, 25, 28, 29, 34],
];
const _wellsFemale = [
  [20, 29, 29, 33, 34, 37, 38, 42],
  [30, 39, 27, 31, 32, 35, 36, 40],
  [40, 49, 24, 28, 29, 32, 33, 37],
  [50, 99, 22, 26, 27, 30, 31, 35],
];

String _classFlexibilidade(double alcance, String genero, int idade) {
  final isMale = !genero.toLowerCase().startsWith('f');
  final normas = isMale ? _wellsMale : _wellsFemale;
  List<int> row = normas.last;
  for (final r in normas) {
    if (idade >= r[0] && idade <= r[1]) { row = r; break; }
  }
  // row: [ageMin, ageMax, fracoMax, abaixoMax, mediaMax, acimaMax]
  // Fraco: < row[2], Abaixo: row[2]-row[3], Média: row[4]-row[5], Acima: row[6]-row[7], Excelente: >row[7]
  final cm = alcance;
  if (cm < row[2]) return 'Fraco';
  if (cm <= row[3]) return 'Abaixo da Média';
  if (cm <= row[5]) return 'Média';
  if (cm <= row[7]) return 'Acima da Média';
  return 'Excelente';
}

Color _corFlexClass(String? c) {
  switch (c) {
    case 'Excelente': return Colors.green;
    case 'Acima da Média': return const Color(0xFF8BC34A);
    case 'Média': return Colors.amber;
    case 'Abaixo da Média': return Colors.orange;
    case 'Fraco': return Colors.red;
    default: return Colors.grey;
  }
}

class AvaliacaoFlexibilidadeScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  const AvaliacaoFlexibilidadeScreen({super.key, required this.aluno});
  @override
  State<AvaliacaoFlexibilidadeScreen> createState() => _AvaliacaoFlexibilidadeScreenState();
}

class _AvaliacaoFlexibilidadeScreenState extends State<AvaliacaoFlexibilidadeScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _lista = [];
  bool _carregando = true;

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final data = await _db
          .from('avaliacao_neuromotores_flexibilidade')
          .select()
          .eq('aluno_id', widget.aluno['id'] as String)
          .eq('excluida', false)
          .order('data_avaliacao', ascending: false);
      setState(() => _lista = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
    setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    return NeuromotoresListScaffold(
      aluno: widget.aluno,
      titulo: 'Flexibilidade',
      subtitulo: 'Banco de Wells e Dillon (1952)',
      carregando: _carregando,
      lista: _lista,
      onNova: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AvaliacaoFlexibilidadeFormScreen(aluno: widget.aluno),
      )).then((_) => _carregar()),
      onEditar: (av) => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AvaliacaoFlexibilidadeFormScreen(aluno: widget.aluno, avaliacao: av),
      )).then((_) => _carregar()),
      buildMetrica: (av) {
        final m = (av['alcance'] as num?)?.toDouble();
        return m != null ? NeuroMetrica('${m.toStringAsFixed(1)} cm', 'alcance') : null;
      },
    );
  }
}

class AvaliacaoFlexibilidadeFormScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  final Map<String, dynamic>? avaliacao;
  const AvaliacaoFlexibilidadeFormScreen({super.key, required this.aluno, this.avaliacao});
  @override
  State<AvaliacaoFlexibilidadeFormScreen> createState() => _AvaliacaoFlexibilidadeFormScreenState();
}

class _AvaliacaoFlexibilidadeFormScreenState extends State<AvaliacaoFlexibilidadeFormScreen> {
  final _db = Supabase.instance.client;
  bool _salvando = false;
  DateTime _data = DateTime.now();
  String genero = 'Masculino';
  int? idade;
  double? alcance;
  final _analiseCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    genero = widget.aluno['genero'] as String? ?? 'Masculino';
    // derive age from birthdate
    final nasc = widget.aluno['data_nascimento'] as String?;
    if (nasc != null) {
      final dt = DateTime.tryParse(nasc);
      if (dt != null) { idade = DateTime.now().year - dt.year; }
    }
    final av = widget.avaliacao;
    if (av != null) {
      if (av['data_avaliacao'] != null) {
        _data = DateTime.tryParse(av['data_avaliacao'] as String) ?? _data;
      }
      genero = av['genero'] as String? ?? genero;
      idade = (av['idade'] as num?)?.toInt() ?? idade;
      alcance = (av['alcance'] as num?)?.toDouble();
      _analiseCtrl.text = av['analise'] as String? ?? '';
    }
  }

  @override
  void dispose() { _analiseCtrl.dispose(); super.dispose(); }

  bool get _podeSalvar => alcance != null;

  String? get _classif => alcance != null && idade != null
      ? _classFlexibilidade(alcance!, genero, idade!)
      : null;

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
        if (idade != null) 'idade': idade,
        'alcance': alcance,
        'analise': _analiseCtrl.text.trim(),
      };
      if (widget.avaliacao != null) {
        await _db.from('avaliacao_neuromotores_flexibilidade')
            .update(payload).eq('id', widget.avaliacao!['id'] as String);
      } else {
        await _db.from('avaliacao_neuromotores_flexibilidade').insert(payload);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) neuroShowErro(context, e); }
    if (mounted) setState(() => _salvando = false);
  }

  @override
  Widget build(BuildContext context) {
    final classif = _classif;
    final normas = genero.toLowerCase().startsWith('f') ? _wellsFemale : _wellsMale;

    return NeuromotoresFormScaffold(
      titulo: 'Banco de Wells e Dillon (1952)',
      aluno: widget.aluno,
      salvando: _salvando,
      podeSalvar: _podeSalvar,
      onSalvar: _salvar,
      sections: [
        NeuroSecao('', [
          NeuroLinhaEdit(
            'Alcance máximo obtido',
            alcance != null ? '${alcance!.toStringAsFixed(1)} cm' : '—',
            () => neuroEditDouble(context, 'Alcance máximo obtido', 'cm', alcance,
                (v) => setState(() => alcance = v)),
          ),
          NeuroLinhaDate('Data', _data, (d) => setState(() => _data = d)),
          if (classif != null)
            NeuroLinhaCalc('Classificação', classif,
                badge: classif, badgeColor: _corFlexClass(classif)),
        ]),
        NeuroSecao('Análise', [
          NeuroLinhaTextarea('', _analiseCtrl),
        ]),
        NeuroSecao('Tabela de Referência', [
          _TabelaReferencia(normas: normas, genero: genero),
        ]),
      ],
    );
  }
}

class _TabelaReferencia extends StatelessWidget {
  final List<List<int>> normas;
  final String genero;
  const _TabelaReferencia({required this.normas, required this.genero});

  @override
  Widget build(BuildContext context) {
    final labels = ['Fraco', 'Abaixo da Média', 'Média', 'Acima da Média', 'Excelente'];
    final cores = [Colors.red, Colors.orange, Colors.amber, const Color(0xFF8BC34A), Colors.green];

    return Column(
      children: normas.map((row) {
        final ageLabel = '${row[0]}-${row[1] == 99 ? '60+' : row[1]}';
        // thresholds: row[2]=fracoMax, row[3]=abaixoMax, row[4..5]=média, row[6..7]=acima
        final ranges = [
          '<${row[2]}',
          '${row[2]}-${row[3]}',
          '${row[4]}-${row[5]}',
          '${row[6]}-${row[7]}',
          '>${row[7]}',
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
                child: Text('Idade $ageLabel',
                    style: GoogleFonts.montserrat(
                        color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
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
          Text('$valor cm', style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
