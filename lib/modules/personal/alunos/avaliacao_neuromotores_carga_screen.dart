import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import 'avaliacao_neuromotores_widgets.dart';

// SQL (Supabase):
// ALTER TABLE avaliacao_neuromotores_carga
//   ADD COLUMN IF NOT EXISTS exercicio text,
//   ADD COLUMN IF NOT EXISTS carga_kg real,
//   ADD COLUMN IF NOT EXISTS repeticoes integer,
//   ADD COLUMN IF NOT EXISTS rm_calculado real,
//   ADD COLUMN IF NOT EXISTS analise text;
// (old columns supino, agachamento, etc. can stay unused)

// McArdle & Katch (1992) / Epley formula
// 1RM = carga × (1 + reps / 30)
double _calcRm(double carga, int reps) {
  if (reps <= 1) return carga;
  return carga * (1 + reps / 30);
}

// ─────────────────────────────────────────────────────────────
// LIST SCREEN
// ─────────────────────────────────────────────────────────────
class AvaliacaoCargaScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  const AvaliacaoCargaScreen({super.key, required this.aluno});
  @override
  State<AvaliacaoCargaScreen> createState() => _AvaliacaoCargaScreenState();
}

class _AvaliacaoCargaScreenState extends State<AvaliacaoCargaScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _lista = [];
  bool _carregando = true;

  @override
  void initState() { super.initState(); _carregar(); }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final data = await _db
          .from('avaliacao_neuromotores_carga')
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
      titulo: 'Rep. máxima (1RM)',
      subtitulo: null,
      carregando: _carregando,
      lista: _lista,
      onNova: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AvaliacaoCargaFormScreen(aluno: widget.aluno),
      )).then((_) => _carregar()),
      onEditar: (av) => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AvaliacaoCargaFormScreen(aluno: widget.aluno, avaliacao: av),
      )).then((_) => _carregar()),
      buildMetrica: (av) {
        final rm = (av['rm_calculado'] as num?)?.toDouble();
        final ex = av['exercicio'] as String?;
        if (rm == null) return null;
        return NeuroMetrica('${rm.toStringAsFixed(1)} kg', ex ?? '1RM');
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// FORM SCREEN
// ─────────────────────────────────────────────────────────────
class AvaliacaoCargaFormScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  final Map<String, dynamic>? avaliacao;
  const AvaliacaoCargaFormScreen({super.key, required this.aluno, this.avaliacao});
  @override
  State<AvaliacaoCargaFormScreen> createState() => _AvaliacaoCargaFormScreenState();
}

class _AvaliacaoCargaFormScreenState extends State<AvaliacaoCargaFormScreen> {
  final _db = Supabase.instance.client;
  bool _salvando = false;
  DateTime _data = DateTime.now();
  String genero = 'Masculino';
  final _exercicioCtrl = TextEditingController();
  double? carga;
  int? reps;
  final _analiseCtrl = TextEditingController();

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
      _exercicioCtrl.text = av['exercicio'] as String? ?? '';
      carga = (av['carga_kg'] as num?)?.toDouble();
      reps  = (av['repeticoes'] as num?)?.toInt();
      _analiseCtrl.text = av['analise'] as String? ?? '';
    }
  }

  @override
  void dispose() {
    _exercicioCtrl.dispose();
    _analiseCtrl.dispose();
    super.dispose();
  }

  bool get _podeSalvar => carga != null && reps != null;

  double? get _rm => _podeSalvar ? _calcRm(carga!, reps!) : null;

  Future<void> _salvar() async {
    if (!_podeSalvar) return;
    setState(() => _salvando = true);
    try {
      String dtStr(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      final rm = _rm!;
      final payload = <String, dynamic>{
        'aluno_id': widget.aluno['id'] as String,
        'data_avaliacao': dtStr(_data),
        'genero': genero,
        'exercicio': _exercicioCtrl.text.trim().isEmpty ? null : _exercicioCtrl.text.trim(),
        'carga_kg': carga,
        'repeticoes': reps,
        'rm_calculado': double.parse(rm.toStringAsFixed(2)),
        'analise': _analiseCtrl.text.trim(),
      };
      if (widget.avaliacao != null) {
        await _db.from('avaliacao_neuromotores_carga')
            .update(payload).eq('id', widget.avaliacao!['id'] as String);
      } else {
        await _db.from('avaliacao_neuromotores_carga').insert(payload);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) { if (mounted) neuroShowErro(context, e); }
    if (mounted) setState(() => _salvando = false);
  }

  @override
  Widget build(BuildContext context) {
    final rm = _rm;

    return NeuromotoresFormScaffold(
      titulo: 'Rep. máxima (1RM)',
      subtitulo: 'McArdle e Katch, 1992',
      aluno: widget.aluno,
      salvando: _salvando,
      podeSalvar: _podeSalvar,
      onSalvar: _salvar,
      sections: [
        NeuroSecao('', [
          // optional exercise name
          _LinhaExercicio(_exercicioCtrl, onChange: () => setState(() {})),
          NeuroLinhaEdit(
            'Carga levantada',
            carga != null ? '${carga!.toStringAsFixed(1)} kg' : '—',
            () => neuroEditDouble(context, 'Carga levantada', 'kg', carga,
                (v) => setState(() => carga = v)),
          ),
          NeuroLinhaEdit(
            'Repetições executadas',
            reps != null ? '$reps reps' : '—',
            () => neuroEditInt(context, 'Repetições executadas', 'reps', reps,
                (v) => setState(() => reps = v)),
          ),
          NeuroLinhaDate('Data', _data, (d) => setState(() => _data = d)),
        ]),
        NeuroSecao('Análise', [
          NeuroLinhaTextarea('', _analiseCtrl),
        ]),
        // result table — appears as soon as carga + reps are filled
        if (rm != null)
          NeuroSecao('Rep. máxima (1RM)', [
            _TabelaRM(rm: rm),
          ]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Exercise name inline field
// ─────────────────────────────────────────────────────────────
class _LinhaExercicio extends StatelessWidget {
  final TextEditingController ctrl;
  final VoidCallback onChange;
  const _LinhaExercicio(this.ctrl, {required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Exercício',
              style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 14)),
          const SizedBox(width: 16),
          Expanded(
            child: TextField(
              controller: ctrl,
              onChanged: (_) => onChange(),
              textAlign: TextAlign.end,
              style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Supino, Agachamento...',
                hintStyle: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 13),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// 1RM result table
// ─────────────────────────────────────────────────────────────
class _TabelaRM extends StatelessWidget {
  final double rm;
  const _TabelaRM({required this.rm});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Rep. Max', rm),
      ('Rep. 50',  rm * 0.50),
      ('Rep. 60',  rm * 0.60),
      ('Rep. 70',  rm * 0.70),
      ('Rep. 80',  rm * 0.80),
      ('Rep. 90',  rm * 0.90),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: rows.map((r) {
          final isFirst = r == rows.first;
          return Column(
            children: [
              if (!isFirst) const Divider(height: 1, color: Colors.white12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(r.$1,
                        style: GoogleFonts.montserrat(
                            color: isFirst ? AppColors.textPrimary : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: isFirst ? FontWeight.w700 : FontWeight.w400)),
                    Text('${r.$2.toStringAsFixed(1)} kg',
                        style: GoogleFonts.montserrat(
                            color: isFirst ? AppColors.textPrimary : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: isFirst ? FontWeight.w700 : FontWeight.w400)),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
