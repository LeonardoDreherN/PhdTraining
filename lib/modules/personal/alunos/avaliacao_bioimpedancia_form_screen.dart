import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

class AvaliacaoBioimpedanciaFormScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  final Map<String, dynamic>? avaliacao;

  const AvaliacaoBioimpedanciaFormScreen({
    super.key,
    required this.aluno,
    this.avaliacao,
  });

  @override
  State<AvaliacaoBioimpedanciaFormScreen> createState() =>
      _AvaliacaoBioimpedanciaFormScreenState();
}

class _AvaliacaoBioimpedanciaFormScreenState
    extends State<AvaliacaoBioimpedanciaFormScreen> {
  final _db = Supabase.instance.client;
  bool _salvando = false;

  // Informações base
  DateTime _dataAvaliacao = DateTime.now();
  String genero = 'Masculino';
  int? idade;
  double? estatura;
  double? peso;

  // Perimetria (cm)
  double? pescoco;
  double? ombro;
  double? torax;
  double? bracoEsq;
  double? bracoDir;
  double? cintura;
  double? abdomen;
  double? quadril;
  double? coxaEsq;
  double? coxaDir;
  double? pernaEsq;
  double? pernaDir;

  // Percentual (inserção manual do aparelho)
  double? percGordura;

  // Outros
  double? pesoIdeal;
  double? percProposta = 14;
  final _objetivoCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  DateTime? proximaAvaliacao;

  @override
  void initState() {
    super.initState();
    genero = widget.aluno['genero'] as String? ?? 'Masculino';
    proximaAvaliacao = DateTime.now().add(const Duration(days: 90));

    final av = widget.avaliacao;
    if (av != null) {
      genero = av['genero'] as String? ?? genero;
      peso = (av['peso'] as num?)?.toDouble();
      estatura = (av['estatura'] as num?)?.toDouble();
      idade = (av['idade'] as num?)?.toInt();
    }
    // Auto-fill age from registration birth date if not set
    if (idade == null) {
      final nasc = widget.aluno['data_nascimento'] as String?;
      if (nasc != null) {
        final dn = DateTime.tryParse(nasc);
        if (dn != null) {
          final hoje = DateTime.now();
          int anos = hoje.year - dn.year;
          if (hoje.month < dn.month || (hoje.month == dn.month && hoje.day < dn.day)) anos--;
          idade = anos;
        }
      }
    }
    if (av != null) {
      if (av['data_avaliacao'] != null) {
        _dataAvaliacao = DateTime.tryParse(av['data_avaliacao'] as String) ?? DateTime.now();
      }
      pescoco = (av['pesco_co'] as num?)?.toDouble();
      ombro = (av['ombro'] as num?)?.toDouble();
      torax = (av['torax'] as num?)?.toDouble();
      bracoEsq = (av['braco_esq'] as num?)?.toDouble();
      bracoDir = (av['braco_dir'] as num?)?.toDouble();
      cintura = (av['cintura'] as num?)?.toDouble();
      abdomen = (av['abdomen'] as num?)?.toDouble();
      quadril = (av['quadril'] as num?)?.toDouble();
      coxaEsq = (av['coxa_esq'] as num?)?.toDouble();
      coxaDir = (av['coxa_dir'] as num?)?.toDouble();
      pernaEsq = (av['perna_esq'] as num?)?.toDouble();
      pernaDir = (av['perna_dir'] as num?)?.toDouble();
      percGordura = (av['perc_gordura'] as num?)?.toDouble();
      pesoIdeal = (av['peso_ideal'] as num?)?.toDouble();
      percProposta = (av['perc_proposta'] as num?)?.toDouble() ?? 14;
      _objetivoCtrl.text = av['objetivo'] as String? ?? '';
      _observacoesCtrl.text = av['observacoes'] as String? ?? '';
      if (av['proxima_avaliacao'] != null) {
        proximaAvaliacao = DateTime.tryParse(av['proxima_avaliacao'] as String);
      }
    }
  }

  @override
  void dispose() {
    _objetivoCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  // ─── Calculados ─────────────────────────────────────────────────────────────

  double? get _massaGorda {
    if (peso == null || percGordura == null) return null;
    return peso! * percGordura! / 100;
  }

  double? get _massaMagra {
    if (peso == null || _massaGorda == null) return null;
    return peso! - _massaGorda!;
  }

  bool get _podeSalvar => percGordura != null && peso != null && idade != null;

  // ─── Salvar ─────────────────────────────────────────────────────────────────

  Future<void> _salvar() async {
    if (!_podeSalvar) return;
    setState(() => _salvando = true);
    try {
      String dtStr(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final payload = <String, dynamic>{
        'aluno_id': widget.aluno['id'] as String,
        'genero': genero,
        'data_avaliacao': dtStr(_dataAvaliacao),
        'peso': peso,
        'estatura': estatura,
        'idade': idade,
        if (pescoco != null) 'pesco_co': pescoco,
        if (ombro != null) 'ombro': ombro,
        if (torax != null) 'torax': torax,
        if (bracoEsq != null) 'braco_esq': bracoEsq,
        if (bracoDir != null) 'braco_dir': bracoDir,
        if (cintura != null) 'cintura': cintura,
        if (abdomen != null) 'abdomen': abdomen,
        if (quadril != null) 'quadril': quadril,
        if (coxaEsq != null) 'coxa_esq': coxaEsq,
        if (coxaDir != null) 'coxa_dir': coxaDir,
        if (pernaEsq != null) 'perna_esq': pernaEsq,
        if (pernaDir != null) 'perna_dir': pernaDir,
        'perc_gordura': percGordura,
        'massa_gorda': _massaGorda,
        'massa_magra': _massaMagra,
        if (pesoIdeal != null) 'peso_ideal': pesoIdeal,
        if (percProposta != null) 'perc_proposta': percProposta,
        'objetivo': _objetivoCtrl.text.trim(),
        'observacoes': _observacoesCtrl.text.trim(),
        if (proximaAvaliacao != null) 'proxima_avaliacao': dtStr(proximaAvaliacao!),
      };

      if (widget.avaliacao != null) {
        await _db
            .from('avaliacao_morfologica_bioimpedancia')
            .update(payload)
            .eq('id', widget.avaliacao!['id'] as String);
      } else {
        await _db.from('avaliacao_morfologica_bioimpedancia').insert(payload);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e',
                style: GoogleFonts.montserrat(color: Colors.black)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _salvando = false);
  }

  // ─── Dialog helper ──────────────────────────────────────────────────────────

  Future<void> _editDouble(
      String label, String unidade, double? atual, void Function(double) set) async {
    final ctrl = TextEditingController(
        text: atual != null ? atual.toStringAsFixed(1) : '');
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(label,
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: GoogleFonts.montserrat(color: AppColors.textPrimary),
          decoration: InputDecoration(
            suffixText: unidade,
            suffixStyle: GoogleFonts.montserrat(color: AppColors.textSecondary),
            enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.divider)),
            focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: GoogleFonts.montserrat(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx, val);
            },
            child: Text('OK',
                style: GoogleFonts.montserrat(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (v != null && v > 0) setState(() => set(v));
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nova Avaliação',
          style: GoogleFonts.montserrat(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (_salvando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _podeSalvar ? _salvar : null,
              child: Text(
                'Salvar',
                style: GoogleFonts.montserrat(
                  color: _podeSalvar ? AppColors.primary : AppColors.textHint,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(),
            const SizedBox(height: 16),
            _buildInfoSection(),
            const SizedBox(height: 16),
            _buildPerimetria(),
            const SizedBox(height: 16),
            _buildPercentual(),
            if (_massaGorda != null) ...[
              const SizedBox(height: 16),
              _buildResultado(),
            ],
            const SizedBox(height: 16),
            _buildOutros(),
            const SizedBox(height: 32),
            _buildBotaoSalvar(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            'Inserção Manual ou Bioimpedância',
            style: GoogleFonts.montserrat(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Informe o % de gordura lido no aparelho ou calculado externamente',
            style: GoogleFonts.montserrat(
              color: AppColors.textHint,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return _buildSecao('Informações', [
      _buildLinhaReadOnly('Gênero', genero, hint: 'Altere no cadastro do aluno'),
      _buildLinhaEdit('Idade', idade != null ? '$idade anos' : '—',
          () => _editDouble('Idade', 'anos', idade?.toDouble(), (v) => idade = v.toInt())),
      _buildLinhaDate('Data da Avaliação', _dataAvaliacao,
          (d) => setState(() => _dataAvaliacao = d)),
      _buildLinhaEdit('Estatura', estatura != null ? '${estatura!.toStringAsFixed(1)} cm' : '—',
          () => _editDouble('Estatura', 'cm', estatura, (v) => estatura = v)),
      _buildLinhaEdit('Peso', peso != null ? '${peso!.toStringAsFixed(1)} kg' : '—',
          () => _editDouble('Peso', 'kg', peso, (v) => peso = v)),
    ]);
  }

  Widget _buildPerimetria() {
    final campos = [
      ('Pescoço', 'cm', pescoco, (double v) { pescoco = v; }),
      ('Ombro', 'cm', ombro, (double v) { ombro = v; }),
      ('Tórax', 'cm', torax, (double v) { torax = v; }),
      ('Braço Esquerdo', 'cm', bracoEsq, (double v) { bracoEsq = v; }),
      ('Braço Direito', 'cm', bracoDir, (double v) { bracoDir = v; }),
      ('Cintura', 'cm', cintura, (double v) { cintura = v; }),
      ('Abdômen', 'cm', abdomen, (double v) { abdomen = v; }),
      ('Quadril', 'cm', quadril, (double v) { quadril = v; }),
      ('Coxa Esquerda', 'cm', coxaEsq, (double v) { coxaEsq = v; }),
      ('Coxa Direita', 'cm', coxaDir, (double v) { coxaDir = v; }),
      ('Perna Esquerda', 'cm', pernaEsq, (double v) { pernaEsq = v; }),
      ('Perna Direita', 'cm', pernaDir, (double v) { pernaDir = v; }),
    ];

    return _buildSecao(
      'Perimetria',
      campos.map<Widget>((e) => _buildLinhaEdit(
        e.$1,
        e.$3 != null ? '${e.$3!.toStringAsFixed(1)} ${e.$2}' : '—',
        () => _editDouble(e.$1, e.$2, e.$3, e.$4),
      )).toList(),
    );
  }

  Widget _buildPercentual() {
    return _buildSecao('Percentual', [
      _buildLinhaEdit(
        '% de Gordura',
        percGordura != null ? '${percGordura!.toStringAsFixed(1)}%' : '—',
        () => _editDouble('% de Gordura', '%', percGordura, (v) => percGordura = v),
      ),
    ]);
  }

  Widget _buildResultado() {
    final mg = _massaGorda;
    final mm = _massaMagra;
    final perc = percGordura;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text('Resultado',
              style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
        if (perc != null)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Column(
              children: [
                Text(
                  '${perc.toStringAsFixed(1)}%',
                  style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text('gordura corporal',
                    style: GoogleFonts.montserrat(
                        color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: _corGordura(perc).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _classGordura(perc),
                    style: GoogleFonts.montserrat(
                        color: _corGordura(perc),
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Column(
            children: _intercalar([
              if (mg != null) _buildResultRow('Massa Gorda', '${mg.toStringAsFixed(1)} kg'),
              if (mm != null) _buildResultRow('Massa Magra', '${mm.toStringAsFixed(1)} kg'),
            ], const Divider(height: 1, thickness: 0.5, color: AppColors.divider)),
          ),
        ),
      ],
    );
  }

  Widget _buildOutros() {
    return _buildSecao('Outros', [
      _buildLinhaEdit(
        'Peso Ideal',
        pesoIdeal != null ? '${pesoIdeal!.toStringAsFixed(1)} kg' : '—',
        () => _editDouble('Peso Ideal', 'kg', pesoIdeal, (v) => pesoIdeal = v),
      ),
      _buildLinhaEdit(
        '% Gordura Proposta',
        percProposta != null ? '${percProposta!.toStringAsFixed(1)}%' : '—',
        () => _editDouble('% Gordura Proposta', '%', percProposta, (v) => percProposta = v),
      ),
      _buildLinhaDate('Próxima Avaliação', proximaAvaliacao,
          (d) => setState(() => proximaAvaliacao = d),
          placeholder: 'Definir data'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Objetivo do Aluno',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _objetivoCtrl,
              maxLines: 3,
              style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ex: Perda de gordura e ganho de massa muscular',
                hintStyle: GoogleFonts.montserrat(color: AppColors.textHint, fontSize: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Observações',
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
              controller: _observacoesCtrl,
              maxLines: 3,
              style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Observações gerais...',
                hintStyle: GoogleFonts.montserrat(color: AppColors.textHint, fontSize: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildBotaoSalvar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _podeSalvar ? _salvar : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          disabledBackgroundColor: AppColors.divider,
          disabledForegroundColor: AppColors.textHint,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text('Salvar',
            style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 15)),
      ),
    );
  }

  // ─── Widgets helpers ─────────────────────────────────────────────────────────

  Widget _buildSecao(String titulo, List<Widget> filhos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(titulo,
              style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Column(
            children: _intercalar(
              filhos,
              const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinhaEdit(String label, String valor, VoidCallback onTap) {
    final vazio = valor == '—';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label,
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(valor,
                style: GoogleFonts.montserrat(
                    color: vazio ? AppColors.textHint : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined, color: AppColors.textHint, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildLinhaReadOnly(String label, String valor, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: GoogleFonts.montserrat(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(valor,
                  style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text('* $hint',
                style: GoogleFonts.montserrat(
                    color: const Color(0xFFEF9A9A), fontSize: 10)),
          ],
        ],
      ),
    );
  }

  Widget _buildLinhaDate(String label, DateTime? data, void Function(DateTime) onPick,
      {String placeholder = '—'}) {
    final texto = data != null
        ? '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}'
        : placeholder;
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: data ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary, surface: AppColors.surface),
            ),
            child: child!,
          ),
        );
        if (d != null) onPick(d);
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label,
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(texto,
                style: GoogleFonts.montserrat(
                    color: data != null ? AppColors.textPrimary : AppColors.textHint,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today_rounded,
                color: AppColors.textHint, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.montserrat(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(valor,
              style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  List<Widget> _intercalar(List<Widget> items, Widget sep) {
    final result = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      result.add(items[i]);
      if (i < items.length - 1) result.add(sep);
    }
    return result;
  }

  String _classGordura(double perc) {
    if (perc < 6) return 'Essencial';
    if (perc < 14) return 'Atleta';
    if (perc < 18) return 'Boa forma';
    if (perc < 25) return 'Aceitável';
    return 'Obesidade';
  }

  Color _corGordura(double perc) {
    if (perc < 6) return const Color(0xFF64B5F6);
    if (perc < 14) return const Color(0xFF4CAF50);
    if (perc < 18) return const Color(0xFF8BC34A);
    if (perc < 25) return const Color(0xFFFFC107);
    return const Color(0xFFF44336);
  }
}
