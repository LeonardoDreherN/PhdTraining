import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

const _perguntasParq = [
  'Algum médico já disse que você possui algum problema cardíaco e que só deveria fazer atividade física com supervisão médica?',
  'Você sente dores no peito quando realiza atividade física?',
  'No último mês, você teve dor no peito sem estar realizando atividade física?',
  'Você perde o equilíbrio por causa de tonturas ou já perdeu a consciência alguma vez?',
  'Você possui algum problema ósseo ou articular que poderia ser agravado pela prática de atividade física?',
  'Algum médico está atualmente prescrevendo medicamentos para sua pressão arterial ou coração?',
  'Existe alguma outra razão pela qual você não deveria praticar atividade física?',
];

class AvaliacaoAnamneseViewScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  const AvaliacaoAnamneseViewScreen({super.key, required this.aluno});

  @override
  State<AvaliacaoAnamneseViewScreen> createState() =>
      _AvaliacaoAnamneseViewScreenState();
}

class _AvaliacaoAnamneseViewScreenState
    extends State<AvaliacaoAnamneseViewScreen> {
  final _db = Supabase.instance.client;
  Map<String, dynamic>? _anamnese;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final data = await _db
          .from('anamnese')
          .select()
          .eq('aluno_id', widget.aluno['id'] as String)
          .maybeSingle();
      setState(() => _anamnese = data);
    } catch (_) {}
    setState(() => _carregando = false);
  }

  @override
  Widget build(BuildContext context) {
    final tipo = (widget.aluno['anamnese_tipo'] as String?) ?? 'nenhuma';

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
                  fontWeight: FontWeight.w700),
            ),
            Text('Anamnese',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: tipo == 'nenhuma'
                  ? _buildNaoConfigurada()
                  : _anamnese == null
                      ? _buildAguardando(tipo)
                      : _buildRespostas(_anamnese!),
            ),
    );
  }

  Widget _buildNaoConfigurada() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined,
                color: AppColors.textHint, size: 48),
            const SizedBox(height: 16),
            Text('Anamnese não configurada',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Edite o cadastro do aluno para ativar o questionário.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                    color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildAguardando(String tipo) {
    final label = tipo == 'parq' ? 'PAR-Q' : 'Padrão';
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: Color(0xFFFFC107), size: 32),
            ),
            const SizedBox(height: 16),
            Text('Aguardando preenchimento',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('O aluno ainda não preencheu o questionário $label.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                    color: AppColors.textHint, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildRespostas(Map<String, dynamic> anamnese) {
    final tipo = anamnese['tipo'] as String? ?? '';
    final respostas = anamnese['respostas'] as Map<String, dynamic>? ?? {};
    final data = _fmtData(anamnese['preenchida_em'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.active, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Questionário preenchido',
                      style: GoogleFonts.montserrat(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text('${tipo == 'parq' ? 'PAR-Q' : 'Padrão'} · $data',
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 20),

        if (tipo == 'parq')
          _buildRespostasParq(respostas)
        else
          _buildRespostasPadrao(respostas),
      ],
    );
  }

  Widget _buildRespostasParq(Map<String, dynamic> respostas) {
    final algumSim = respostas.values.any((v) => v == true);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (algumSim)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Aluno respondeu SIM a uma ou mais questões. Avalie a necessidade de liberação médica.',
                  style: GoogleFonts.montserrat(color: AppColors.error, fontSize: 12),
                ),
              ),
            ]),
          ),
        for (var i = 0; i < _perguntasParq.length; i++)
          _rowParq(i, respostas['q${i + 1}'] as bool? ?? false),
      ],
    );
  }

  Widget _rowParq(int i, bool resposta) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text('${i + 1}. ${_perguntasParq[i]}',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary, fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: resposta
                  ? AppColors.error.withValues(alpha: 0.12)
                  : AppColors.active.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              resposta ? 'Sim' : 'Não',
              style: GoogleFonts.montserrat(
                color: resposta ? AppColors.error : AppColors.active,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRespostasPadrao(Map<String, dynamic> r) {
    final estresse = (r['nivel_estresse'] as num?)?.toInt() ?? 0;
    final pratica = r['pratica_atividade'] as bool? ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secao('Objetivo'),
        _infoCard(r['objetivo'] as String? ?? '—'),
        const SizedBox(height: 16),

        _secao('Atividade física'),
        _rowInfo('Pratica atividade física', pratica ? 'Sim' : 'Não'),
        if (pratica) ...[
          _rowInfo('Atividades', r['quais_atividades'] as String? ?? '—'),
          _rowInfo('Frequência semanal', r['frequencia_semanal'] as String? ?? '—'),
        ],
        const SizedBox(height: 16),

        _secao('Saúde'),
        _rowInfo('Doenças diagnosticadas', r['doencas'] as String? ?? '—'),
        _rowInfo('Medicamentos', r['medicamentos'] as String? ?? '—'),
        _rowInfo('Cirurgias / lesões', r['cirurgias_lesoes'] as String? ?? '—'),
        _rowInfo('Dores crônicas', r['dores_cronicas'] as String? ?? '—'),
        _rowInfo('Restrições alimentares', r['restricoes_alimentares'] as String? ?? '—'),
        const SizedBox(height: 16),

        _secao('Nível de estresse'),
        Row(
          children: List.generate(5, (i) {
            final v = i + 1;
            final ativo = v <= estresse;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: v < 5 ? 6 : 0),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: v == estresse
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : ativo
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: v == estresse ? AppColors.primary : AppColors.divider,
                      width: v == estresse ? 1.5 : 0.5),
                ),
                child: Text('$v',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      color: v == estresse
                          ? AppColors.primary
                          : ativo
                              ? AppColors.textSecondary
                              : AppColors.textHint,
                      fontWeight: v == estresse ? FontWeight.w700 : FontWeight.w400,
                      fontSize: 13,
                    )),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),

        if ((r['observacoes'] as String?)?.isNotEmpty == true) ...[
          _secao('Observações'),
          _infoCard(r['observacoes'] as String),
        ],
      ],
    );
  }

  Widget _secao(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      );

  Widget _infoCard(String texto) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Text(texto,
            style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 13)),
      );

  Widget _rowInfo(String label, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 150,
              child: Text(label,
                  style: GoogleFonts.montserrat(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            Expanded(
              child: Text(valor.isEmpty ? '—' : valor,
                  style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );

  String _fmtData(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
