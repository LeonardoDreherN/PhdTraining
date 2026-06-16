import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../personal/alunos/avaliacao_dobras_graficos_screen.dart';

class AlunoAvaliacoesScreen extends StatefulWidget {
  const AlunoAvaliacoesScreen({super.key});

  @override
  State<AlunoAvaliacoesScreen> createState() => _AlunoAvaliacoesScreenState();
}

class _AlunoAvaliacoesScreenState extends State<AlunoAvaliacoesScreen> {
  final _db = Supabase.instance.client;
  bool _carregando = true;
  Map<String, dynamic>? _aluno;
  List<Map<String, dynamic>> _avaliacoes = [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final user = _db.auth.currentUser!;
      Map<String, dynamic>? aluno = await _db
          .from('alunos')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      aluno ??= await _db
          .from('alunos')
          .select()
          .eq('email', user.email!)
          .maybeSingle();
      if (aluno == null) return;
      _aluno = aluno;

      // Try bioimpedância first, fallback to dobras
      final bio = await _db
          .from('avaliacao_morfologica_bioimpedancia')
          .select()
          .eq('aluno_id', aluno['id'] as String)
          .eq('excluida', false)
          .order('data_avaliacao', ascending: true);

      if ((bio as List).isNotEmpty) {
        _avaliacoes = List<Map<String, dynamic>>.from(bio);
      } else {
        final dobras = await _db
            .from('avaliacao_morfologica_dobras')
            .select()
            .eq('aluno_id', aluno['id'] as String)
            .eq('excluida', false)
            .order('data_avaliacao', ascending: true);
        _avaliacoes = List<Map<String, dynamic>>.from(dobras);
      }

      setState(() {});
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text('Avaliação Física',
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _avaliacoes.isEmpty ? _buildVazio() : _buildConteudo(),
            ),
    );
  }

  Widget _buildVazio() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined, color: AppColors.textHint, size: 56),
            const SizedBox(height: 16),
            Text('Nenhuma avaliação registrada',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Seu personal ainda não registrou\numa avaliação física.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                    color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudo() {
    final latest = _avaliacoes.last;
    final perc = (latest['perc_gordura'] as num?)?.toDouble();
    final peso = (latest['peso'] as num?)?.toDouble();
    final mg = (latest['massa_gorda'] as num?)?.toDouble();
    final mm = (latest['massa_magra'] as num?)?.toDouble();
    final data = _fmtData(latest['data_avaliacao'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Última avaliação
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Última avaliação',
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8)),
                  Text(data,
                      style: GoogleFonts.montserrat(
                          color: AppColors.textHint, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (peso != null)
                    Expanded(
                      child: _metrica(
                          '${peso.toStringAsFixed(1)} kg', 'Peso', null),
                    ),
                  if (perc != null)
                    Expanded(
                      child: _metrica(
                          '${perc.toStringAsFixed(1)}%', '% Gordura', AppColors.error),
                    ),
                  if (mm != null)
                    Expanded(
                      child: _metrica(
                          '${mm.toStringAsFixed(1)} kg', 'Massa Magra',
                          const Color(0xFF4FC3F7)),
                    ),
                  if (mg != null)
                    Expanded(
                      child: _metrica(
                          '${mg.toStringAsFixed(1)} kg', 'Massa Gorda',
                          AppColors.error),
                    ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Total avaliações
        if (_avaliacoes.length > 1) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Row(children: [
              const Icon(Icons.history_rounded, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 10),
              Text('${_avaliacoes.length} avaliações registradas',
                  style: GoogleFonts.montserrat(
                      color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 12),
        ],

        // Botão Gráficos
        if (_avaliacoes.length >= 2)
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AvaliacaoDobraGraficosScreen(
                  aluno: _aluno!,
                  avaliacoes: _avaliacoes,
                ),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider, width: 0.5),
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bar_chart_rounded,
                      color: AppColors.textPrimary, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Gráficos de Evolução',
                          style: GoogleFonts.montserrat(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      Text('Composição corporal ao longo do tempo',
                          style: GoogleFonts.montserrat(
                              color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppColors.textSecondary, size: 14),
              ]),
            ),
          ),

        const SizedBox(height: 12),

        // Histórico
        Text('Histórico',
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        for (final av in _avaliacoes.reversed) _buildHistoricoCard(av),
      ],
    );
  }

  Widget _metrica(String valor, String label, Color? cor) {
    return Column(
      children: [
        Text(valor,
            style: GoogleFonts.montserrat(
              color: cor ?? AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.montserrat(
                color: AppColors.textSecondary, fontSize: 10)),
      ],
    );
  }

  Widget _buildHistoricoCard(Map<String, dynamic> av) {
    final perc = (av['perc_gordura'] as num?)?.toDouble();
    final peso = (av['peso'] as num?)?.toDouble();
    final data = _fmtData(av['data_avaliacao'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(data,
                style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
          if (peso != null)
            Text('${peso.toStringAsFixed(1)} kg',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary, fontSize: 12)),
          const SizedBox(width: 12),
          if (perc != null)
            Text('${perc.toStringAsFixed(1)}%',
                style: GoogleFonts.montserrat(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _fmtData(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
