import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'avaliacao_bioimpedancia_form_screen.dart';
import 'avaliacao_dobras_graficos_screen.dart';

// SQL needed in Supabase:
// CREATE TABLE avaliacao_morfologica_bioimpedancia (
//   id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
//   aluno_id uuid REFERENCES alunos(id) ON DELETE CASCADE,
//   data_avaliacao date DEFAULT CURRENT_DATE,
//   genero text, peso real, estatura real, idade integer,
//   pesco_co real, ombro real, torax real,
//   braco_esq real, braco_dir real,
//   cintura real, abdomen real, quadril real,
//   coxa_esq real, coxa_dir real,
//   perna_esq real, perna_dir real,
//   perc_gordura real, massa_gorda real, massa_magra real,
//   peso_ideal real, perc_proposta real,
//   objetivo text, observacoes text,
//   proxima_avaliacao date,
//   excluida boolean DEFAULT false,
//   created_at timestamptz DEFAULT now()
// );
// ALTER TABLE avaliacao_morfologica_bioimpedancia ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "access_avaliacao_bioimpedancia" ON avaliacao_morfologica_bioimpedancia
//   FOR ALL USING (auth.role() = 'authenticated');

class AvaliacaoBioimpedanciaScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  const AvaliacaoBioimpedanciaScreen({super.key, required this.aluno});

  @override
  State<AvaliacaoBioimpedanciaScreen> createState() =>
      _AvaliacaoBioimpedanciaScreenState();
}

class _AvaliacaoBioimpedanciaScreenState
    extends State<AvaliacaoBioimpedanciaScreen> {
  final _db = Supabase.instance.client;
  List<Map<String, dynamic>> _avaliacoes = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final data = await _db
          .from('avaliacao_morfologica_bioimpedancia')
          .select()
          .eq('aluno_id', widget.aluno['id'] as String)
          .eq('excluida', false)
          .order('data_avaliacao', ascending: false);
      setState(() => _avaliacoes = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
    setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.aluno['nome'] as String? ?? 'Aluno',
              style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Bioimpedância',
              style: GoogleFonts.montserrat(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AvaliacaoBioimpedanciaFormScreen(
                        aluno: widget.aluno,
                      ),
                    ),
                  ).then((_) => _carregar());
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Nova avaliação',
                  style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _avaliacoes.isEmpty
                    ? _buildEmpty()
                    : _buildLista(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: const Icon(Icons.folder_open_rounded,
                color: AppColors.textHint, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            'Nenhuma avaliação registrada',
            style: GoogleFonts.montserrat(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Toque em "Nova avaliação" para começar',
            style: GoogleFonts.montserrat(
                color: AppColors.textHint, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildLista() {
    final cronologico = [..._avaliacoes]
      ..sort((a, b) => (a['data_avaliacao'] as String? ?? '')
          .compareTo(b['data_avaliacao'] as String? ?? ''));

    return CustomScrollView(
      slivers: [
        if (_avaliacoes.length >= 2)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AvaliacaoDobraGraficosScreen(
                      aluno: widget.aluno, avaliacoes: cronologico),
                )),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider, width: 0.5),
                  ),
                  child: Row(children: [
                    const Icon(Icons.bar_chart_rounded, color: AppColors.textPrimary, size: 22),
                    const SizedBox(width: 12),
                    Text('Gráficos', style: GoogleFonts.montserrat(
                        color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios_rounded,
                        color: AppColors.textSecondary, size: 14),
                  ]),
                ),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildCard(_avaliacoes[i]),
              childCount: _avaliacoes.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> av) {
    final dataStr = _formatData(av['data_avaliacao'] as String?);
    final perc = (av['perc_gordura'] as num?)?.toDouble();
    final peso = (av['peso'] as num?)?.toDouble();

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AvaliacaoBioimpedanciaFormScreen(
              aluno: widget.aluno,
              avaliacao: av,
            ),
          ),
        ).then((_) => _carregar());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bioimpedância',
                    style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(dataStr,
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary, fontSize: 12)),
                  if (peso != null)
                    Text('${peso.toStringAsFixed(1)} kg',
                        style: GoogleFonts.montserrat(
                            color: AppColors.textHint, fontSize: 11)),
                ],
              ),
            ),
            if (perc != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${perc.toStringAsFixed(1)}%',
                    style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text('gordura',
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _formatData(String? raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
