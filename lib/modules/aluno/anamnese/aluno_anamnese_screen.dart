import 'package:flutter/material.dart';
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

class AlunoAnamneseScreen extends StatefulWidget {
  final String tipo; // 'parq' | 'padrao'
  final String alunoId;
  const AlunoAnamneseScreen({super.key, required this.tipo, required this.alunoId});

  @override
  State<AlunoAnamneseScreen> createState() => _AlunoAnamneseScreenState();
}

class _AlunoAnamneseScreenState extends State<AlunoAnamneseScreen> {
  final _db = Supabase.instance.client;
  bool _salvando = false;

  // PAR-Q
  final List<bool> _parq = List.filled(7, false);

  // Padrão
  String _objetivo = '';
  bool _praticaAtividade = false;
  int _nivelEstresse = 3;
  final _cAtividades   = TextEditingController();
  final _cFrequencia   = TextEditingController();
  final _cDoencas      = TextEditingController();
  final _cMedicamentos = TextEditingController();
  final _cCirurgias    = TextEditingController();
  final _cDores        = TextEditingController();
  final _cRestricoes   = TextEditingController();
  final _cObs          = TextEditingController();

  @override
  void dispose() {
    _cAtividades.dispose(); _cFrequencia.dispose(); _cDoencas.dispose();
    _cMedicamentos.dispose(); _cCirurgias.dispose(); _cDores.dispose();
    _cRestricoes.dispose(); _cObs.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      final Map<String, dynamic> respostas;
      if (widget.tipo == 'parq') {
        respostas = {for (var i = 0; i < 7; i++) 'q${i + 1}': _parq[i]};
      } else {
        respostas = {
          'objetivo': _objetivo,
          'pratica_atividade': _praticaAtividade,
          'quais_atividades': _cAtividades.text.trim(),
          'frequencia_semanal': _cFrequencia.text.trim(),
          'doencas': _cDoencas.text.trim(),
          'medicamentos': _cMedicamentos.text.trim(),
          'cirurgias_lesoes': _cCirurgias.text.trim(),
          'dores_cronicas': _cDores.text.trim(),
          'restricoes_alimentares': _cRestricoes.text.trim(),
          'nivel_estresse': _nivelEstresse,
          'observacoes': _cObs.text.trim(),
        };
      }

      await _db.from('anamnese').upsert({
        'aluno_id': widget.alunoId,
        'tipo': widget.tipo,
        'respostas': respostas,
        'preenchida_em': DateTime.now().toIso8601String(),
      }, onConflict: 'aluno_id');

      await _db.from('alunos')
          .update({'anamnese_preenchida': true})
          .eq('id', widget.alunoId);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erro ao salvar: $e'),
          backgroundColor: AppColors.error,
        ));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.tipo == 'parq' ? 'PAR-Q' : 'Anamnese',
                style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text('Questionário de saúde',
                  style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: widget.tipo == 'parq' ? _buildParq() : _buildPadrao(),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _salvando ? null : _salvar,
                    child: _salvando
                        ? const SizedBox(
                            height: 18, width: 18,
                            child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : Text('Enviar questionário',
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PAR-Q ──────────────────────────────────────────────────────────────────

  Widget _buildParq() {
    final algumSim = _parq.any((v) => v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Text(
            'Responda SIM ou NÃO para cada pergunta. Caso responda SIM a qualquer questão, consulte um médico antes de iniciar as atividades.',
            style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 12),
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < _perguntasParq.length; i++) ...[
          _buildQuestaoParq(i),
          const SizedBox(height: 10),
        ],
        if (algumSim) ...[
          const SizedBox(height: 4),
          Container(
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
                  'Você respondeu SIM a uma ou mais perguntas. Consulte seu médico antes de iniciar.',
                  style: GoogleFonts.montserrat(color: AppColors.error, fontSize: 12),
                ),
              ),
            ]),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildQuestaoParq(int i) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${i + 1}. ${_perguntasParq[i]}',
              style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            _simNao(true, _parq[i], () => setState(() => _parq[i] = true)),
            const SizedBox(width: 10),
            _simNao(false, !_parq[i], () => setState(() => _parq[i] = false)),
          ]),
        ],
      ),
    );
  }

  Widget _simNao(bool isSim, bool sel, VoidCallback onTap) {
    final cor = isSim ? AppColors.error : AppColors.active;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? cor.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: sel ? cor : AppColors.divider, width: sel ? 1.5 : 0.5),
          ),
          child: Text(
            isSim ? 'Sim' : 'Não',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              color: sel ? cor : AppColors.textSecondary,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  // ── PADRÃO ─────────────────────────────────────────────────────────────────

  Widget _buildPadrao() {
    const objetivos = [
      'Perda de peso', 'Ganho de massa', 'Condicionamento físico',
      'Saúde e bem-estar', 'Reabilitação', 'Outro',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secao('Objetivo principal'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: objetivos.map((o) {
            final sel = _objetivo == o;
            return GestureDetector(
              onTap: () => setState(() => _objetivo = o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? AppColors.primary : AppColors.divider),
                ),
                child: Text(o,
                    style: GoogleFonts.montserrat(
                      color: sel ? AppColors.primary : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    )),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        _secao('Atividade física atual'),
        _switchRow('Pratica atividade física atualmente?', _praticaAtividade,
            (v) => setState(() => _praticaAtividade = v)),
        if (_praticaAtividade) ...[
          const SizedBox(height: 10),
          _campo('Quais atividades?', _cAtividades),
          const SizedBox(height: 10),
          _campo('Frequência semanal (ex: 3x por semana)', _cFrequencia),
        ],
        const SizedBox(height: 20),

        _secao('Saúde'),
        _campo('Doenças diagnosticadas', _cDoencas, hint: 'Nenhuma'),
        const SizedBox(height: 10),
        _campo('Medicamentos em uso', _cMedicamentos, hint: 'Nenhum'),
        const SizedBox(height: 10),
        _campo('Cirurgias ou lesões anteriores', _cCirurgias, hint: 'Nenhuma'),
        const SizedBox(height: 10),
        _campo('Dores crônicas', _cDores, hint: 'Nenhuma'),
        const SizedBox(height: 10),
        _campo('Restrições alimentares ou alergias', _cRestricoes, hint: 'Nenhuma'),
        const SizedBox(height: 20),

        _secao('Nível de estresse  (1 = baixo  •  5 = muito alto)'),
        Row(
          children: List.generate(5, (i) {
            final v = i + 1;
            final sel = _nivelEstresse == v;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _nivelEstresse = v),
                child: Container(
                  margin: EdgeInsets.only(right: v < 5 ? 6 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.divider),
                  ),
                  child: Text('$v',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        color: sel ? AppColors.primary : AppColors.textSecondary,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      )),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 20),

        _secao('Observações adicionais'),
        _campo('Algo mais que seu personal deva saber', _cObs, maxLines: 4),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _secao(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t,
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _campo(String label, TextEditingController ctrl,
      {String? hint, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint ?? 'Digite aqui...',
            hintStyle: GoogleFonts.montserrat(color: AppColors.textHint, fontSize: 13),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider, width: 0.5)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.divider, width: 0.5)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primary, width: 1)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _switchRow(String label, bool value, void Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(children: [
        Expanded(
            child: Text(label,
                style: GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 13))),
        Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
      ]),
    );
  }
}
