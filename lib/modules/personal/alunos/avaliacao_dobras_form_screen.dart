import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'avaliacao_dobras_screen.dart';

// SQL needed in Supabase (drop old and recreate, or ALTER to add new columns):
// CREATE TABLE avaliacao_morfologica_dobras (
//   id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
//   aluno_id uuid REFERENCES alunos(id) ON DELETE CASCADE,
//   protocolo text NOT NULL,
//   data_avaliacao date DEFAULT CURRENT_DATE,
//   genero text,
//   peso real, estatura real, idade integer,
//   -- Perimetria (cm)
//   pesco_co real, ombro real, torax real,
//   braco_esq real, braco_dir real,
//   cintura real, abdomen real, quadril real,
//   coxa_esq real, coxa_dir real,
//   perna_esq real, perna_dir real,
//   -- Dobras (mm)
//   tricipital real, subescapular real, peitoral real,
//   abdominal real, supraoiliaca real, coxa real,
//   perna real, axilar_media real,
//   -- Calculados
//   soma_dobras real, perc_gordura real,
//   massa_gorda real, massa_magra real,
//   -- Outros
//   peso_ideal real, perc_proposta real,
//   objetivo text, observacoes text,
//   proxima_avaliacao date,
//   excluida boolean DEFAULT false,
//   created_at timestamptz DEFAULT now()
// );
// ALTER TABLE avaliacao_morfologica_dobras ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "access_avaliacao_morfologica_dobras" ON avaliacao_morfologica_dobras
//   FOR ALL USING (auth.role() = 'authenticated');

class AvaliacaoDobraFormScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  final String protocolo;
  final Map<String, dynamic>? avaliacao;

  const AvaliacaoDobraFormScreen({
    super.key,
    required this.aluno,
    required this.protocolo,
    this.avaliacao,
  });

  @override
  State<AvaliacaoDobraFormScreen> createState() =>
      _AvaliacaoDobraFormScreenState();
}

class _AvaliacaoDobraFormScreenState extends State<AvaliacaoDobraFormScreen> {
  final _db = Supabase.instance.client;
  bool _salvando = false;
  late DobraProtocolo _proto;

  // Informações base
  DateTime _dataAvaliacao = DateTime.now();
  double? estatura;
  double? peso;
  int? idade;
  String genero = 'Masculino';

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

  // Dobras (mm)
  double? tricipital;
  double? subescapular;
  double? peitoral;
  double? abdominal;
  double? supraoiliaca;
  double? coxa;
  double? perna;
  double? axilarMedia;

  // Outros
  double? pesoIdeal;
  double? percProposta = 14;
  final _objetivoCtrl = TextEditingController();
  final _observacoesCtrl = TextEditingController();
  DateTime? proximaAvaliacao;

  @override
  void initState() {
    super.initState();
    _proto = DobraProtocolos.findById(widget.protocolo) ??
        DobraProtocolos.todos.first;
    genero = widget.aluno['genero'] as String? ?? 'Masculino';

    final av = widget.avaliacao;
    if (av != null) {
      _loadFromMap(av);
    } else {
      proximaAvaliacao = DateTime.now().add(const Duration(days: 90));
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
  }

  void _loadFromMap(Map<String, dynamic> av) {
    genero = av['genero'] as String? ?? genero;
    peso = (av['peso'] as num?)?.toDouble();
    estatura = (av['estatura'] as num?)?.toDouble();
    idade = (av['idade'] as num?)?.toInt();
    if (av['data_avaliacao'] != null) {
      _dataAvaliacao = DateTime.tryParse(av['data_avaliacao'] as String) ?? DateTime.now();
    }
    // Perimetria
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
    // Dobras
    tricipital = (av['tricipital'] as num?)?.toDouble();
    subescapular = (av['subescapular'] as num?)?.toDouble();
    peitoral = (av['peitoral'] as num?)?.toDouble();
    abdominal = (av['abdominal'] as num?)?.toDouble();
    supraoiliaca = (av['supraoiliaca'] as num?)?.toDouble();
    coxa = (av['coxa'] as num?)?.toDouble();
    perna = (av['perna'] as num?)?.toDouble();
    axilarMedia = (av['axilar_media'] as num?)?.toDouble();
    // Outros
    pesoIdeal = (av['peso_ideal'] as num?)?.toDouble();
    percProposta = (av['perc_proposta'] as num?)?.toDouble() ?? 14;
    _objetivoCtrl.text = av['objetivo'] as String? ?? '';
    _observacoesCtrl.text = av['observacoes'] as String? ?? '';
    if (av['proxima_avaliacao'] != null) {
      proximaAvaliacao = DateTime.tryParse(av['proxima_avaliacao'] as String);
    }
  }

  @override
  void dispose() {
    _objetivoCtrl.dispose();
    _observacoesCtrl.dispose();
    super.dispose();
  }

  // ─── Cálculos ───────────────────────────────────────────────────────────────

  double? _valorDobra(String campo) {
    switch (campo) {
      case 'tricipital': return tricipital;
      case 'subescapular': return subescapular;
      case 'peitoral': return peitoral;
      case 'abdominal': return abdominal;
      case 'supraoiliaca': return supraoiliaca;
      case 'coxa': return coxa;
      case 'perna': return perna;
      case 'axilar_media': return axilarMedia;
      default: return null;
    }
  }

  void _setDobra(String campo, double v) {
    setState(() {
      switch (campo) {
        case 'tricipital': tricipital = v; break;
        case 'subescapular': subescapular = v; break;
        case 'peitoral': peitoral = v; break;
        case 'abdominal': abdominal = v; break;
        case 'supraoiliaca': supraoiliaca = v; break;
        case 'coxa': coxa = v; break;
        case 'perna': perna = v; break;
        case 'axilar_media': axilarMedia = v; break;
      }
    });
  }

  double? get _somaDobras {
    final vals = _proto.campos.map(_valorDobra).whereType<double>().toList();
    if (vals.length < _proto.campos.length) return null;
    return vals.reduce((a, b) => a + b);
  }

  double? get _percGordura {
    final soma = _somaDobras;
    if (soma == null) return null;
    final id = idade ?? 25;
    switch (_proto.id) {
      case 'pollock7':
        final d = 1.112 - (0.00043499 * soma) + (0.00000055 * soma * soma) - (0.00028826 * id);
        return ((4.95 / d) - 4.5) * 100;
      case 'pollock3m':
        final d = 1.10938 - (0.0008267 * soma) + (0.0000016 * soma * soma) - (0.0002574 * id);
        return ((4.95 / d) - 4.5) * 100;
      case 'pollock3f':
        final d = 1.0994921 - (0.0009929 * soma) + (0.0000023 * soma * soma) - (0.0001392 * id);
        return ((4.95 / d) - 4.5) * 100;
      case 'faulkner4':
        return (soma * 0.153) + 5.783;
      case 'guedes3m':
        if (soma <= 0) return null;
        final d = 1.1714680 - (0.0671966 * log(soma)) - (0.0008 * id);
        return ((4.95 / d) - 4.5) * 100;
      case 'guedes3f':
        if (soma <= 0) return null;
        final d = 1.1665940 - (0.0706741 * log(soma)) - (0.00033 * id);
        return ((4.95 / d) - 4.5) * 100;
      case 'petroski4m':
        if (soma <= 0) return null;
        final d = 1.10726863 - (0.00081201 * soma) + (0.00000212 * soma * soma) - (0.00041761 * id);
        return ((4.95 / d) - 4.5) * 100;
      case 'petroski4f':
        if (soma <= 0) return null;
        final d = 1.19547966 - (0.07513507 * log(soma)) + (0.00000018 * soma * soma) - (0.00032010 * id);
        return ((4.95 / d) - 4.5) * 100;
      default:
        return null;
    }
  }

  double? get _massaGorda {
    if (peso == null || _percGordura == null) return null;
    return peso! * _percGordura! / 100;
  }

  double? get _massaMagra {
    if (peso == null || _massaGorda == null) return null;
    return peso! - _massaGorda!;
  }

  // ─── Salvar ─────────────────────────────────────────────────────────────────

  bool get _podeSalvar => _somaDobras != null && peso != null && idade != null;

  Future<void> _salvar() async {
    if (!_podeSalvar) return;
    setState(() => _salvando = true);
    try {
      String dtStr(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      final payload = <String, dynamic>{
        'aluno_id': widget.aluno['id'] as String,
        'protocolo': _proto.id,
        'genero': genero,
        'data_avaliacao': dtStr(_dataAvaliacao),
        'peso': peso,
        'estatura': estatura,
        'idade': idade,
        // Perimetria
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
        // Dobras
        if (tricipital != null) 'tricipital': tricipital,
        if (subescapular != null) 'subescapular': subescapular,
        if (peitoral != null) 'peitoral': peitoral,
        if (abdominal != null) 'abdominal': abdominal,
        if (supraoiliaca != null) 'supraoiliaca': supraoiliaca,
        if (coxa != null) 'coxa': coxa,
        if (perna != null) 'perna': perna,
        if (axilarMedia != null) 'axilar_media': axilarMedia,
        // Calculados
        'soma_dobras': _somaDobras,
        'perc_gordura': _percGordura,
        'massa_gorda': _massaGorda,
        'massa_magra': _massaMagra,
        // Outros
        if (pesoIdeal != null) 'peso_ideal': pesoIdeal,
        if (percProposta != null) 'perc_proposta': percProposta,
        'objetivo': _objetivoCtrl.text.trim(),
        'observacoes': _observacoesCtrl.text.trim(),
        if (proximaAvaliacao != null) 'proxima_avaliacao': dtStr(proximaAvaliacao!),
      };

      if (widget.avaliacao != null) {
        await _db.from('avaliacao_morfologica_dobras')
            .update(payload)
            .eq('id', widget.avaliacao!['id'] as String);
      } else {
        await _db.from('avaliacao_morfologica_dobras').insert(payload);
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

  // ─── Dialogs ────────────────────────────────────────────────────────────────

  Future<double?> _dialogDouble(String label, String unidade, double? atual) async {
    final ctrl = TextEditingController(
        text: atual != null ? atual.toStringAsFixed(1) : '');
    return showDialog<double>(
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
              final v = double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
              Navigator.pop(ctx, v);
            },
            child: Text('OK',
                style: GoogleFonts.montserrat(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _editDouble(
      String label, String unidade, double? atual, void Function(double) set) async {
    final v = await _dialogDouble(label, unidade, atual);
    if (v != null && v > 0) setState(() => set(v));
  }

  Future<void> _editDobra(String campo) async {
    final labels = {
      'tricipital': 'Tricipital',
      'subescapular': 'Subescapular',
      'peitoral': 'Peitoral',
      'abdominal': 'Abdominal',
      'supraoiliaca': 'Suprailíaca',
      'coxa': 'Coxa',
      'perna': 'Perna (panturrilha medial)',
      'axilar_media': 'Axilar Média',
    };
    final v = await _dialogDouble(labels[campo] ?? campo, 'mm', _valorDobra(campo));
    if (v != null && v > 0) _setDobra(campo, v);
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
            _buildAntropometria(),
            if (_somaDobras != null) ...[
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

  // ─── Seções ─────────────────────────────────────────────────────────────────

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
            _proto.nome,
            style: GoogleFonts.montserrat(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Protocolo:',
            style: GoogleFonts.montserrat(
                color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            _proto.formula,
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
      _buildLinhaReadOnly(
        'Gênero',
        genero,
        hint: 'Altere no cadastro do aluno',
      ),
      _buildLinhaEdit(
        'Idade',
        idade != null ? '$idade anos' : '—',
        () => _editDouble('Idade', 'anos', idade?.toDouble(),
            (v) => idade = v.toInt()),
      ),
      _buildLinhaDate('Data da Avaliação', _dataAvaliacao, (d) {
        setState(() => _dataAvaliacao = d);
      }),
      _buildLinhaEdit(
        'Estatura',
        estatura != null ? '${estatura!.toStringAsFixed(1)} cm' : '—',
        () => _editDouble('Estatura', 'cm', estatura, (v) => estatura = v),
      ),
      _buildLinhaEdit(
        'Peso',
        peso != null ? '${peso!.toStringAsFixed(1)} kg' : '—',
        () => _editDouble('Peso', 'kg', peso, (v) => peso = v),
      ),
    ]);
  }

  Widget _buildPerimetria() {
    final campos = [
      ('Pescoço', 'cm', pescoco, (v) => pescoco = v),
      ('Ombro', 'cm', ombro, (v) => ombro = v),
      ('Tórax', 'cm', torax, (v) => torax = v),
      ('Braço Esquerdo', 'cm', bracoEsq, (v) => bracoEsq = v),
      ('Braço Direito', 'cm', bracoDir, (v) => bracoDir = v),
      ('Cintura', 'cm', cintura, (v) => cintura = v),
      ('Abdômen', 'cm', abdomen, (v) => abdomen = v),
      ('Quadril', 'cm', quadril, (v) => quadril = v),
      ('Coxa Esquerda', 'cm', coxaEsq, (v) => coxaEsq = v),
      ('Coxa Direita', 'cm', coxaDir, (v) => coxaDir = v),
      ('Perna Esquerda', 'cm', pernaEsq, (v) => pernaEsq = v),
      ('Perna Direita', 'cm', pernaDir, (v) => pernaDir = v),
    ];

    return _buildSecao(
      'Perimetria',
      campos
          .map<Widget>((e) => _buildLinhaEdit(
                e.$1,
                e.$3 != null ? '${e.$3!.toStringAsFixed(1)} ${e.$2}' : '—',
                () => _editDouble(e.$1, e.$2, e.$3, e.$4),
              ))
          .toList(),
    );
  }

  Widget _buildAntropometria() {
    final labels = {
      'tricipital': 'Tricipital',
      'subescapular': 'Subescapular',
      'peitoral': 'Peitoral',
      'abdominal': 'Abdominal',
      'supraoiliaca': 'Suprailíaca',
      'coxa': 'Coxa',
      'perna': 'Perna (panturrilha medial)',
      'axilar_media': 'Axilar Média',
    };

    final camposDoProto = _proto.campos;
    final todasPreenchidas = camposDoProto.every((c) => _valorDobra(c) != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 4),
          child: Text(
            'Antropometria',
            style: GoogleFonts.montserrat(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (!todasPreenchidas)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Text(
              'Todos os campos são obrigatórios',
              style: GoogleFonts.montserrat(
                color: const Color(0xFFEF9A9A),
                fontSize: 11,
              ),
            ),
          )
        else
          const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Column(
            children: _intercalar(
              camposDoProto
                  .map<Widget>((c) => _buildLinhaEdit(
                        labels[c] ?? c,
                        _valorDobra(c) != null
                            ? '${_valorDobra(c)!.toStringAsFixed(1)} mm'
                            : '—',
                        () => _editDobra(c),
                      ))
                  .toList(),
              const Divider(height: 1, thickness: 0.5, color: AppColors.divider),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultado() {
    final perc = _percGordura;
    final soma = _somaDobras;
    final mg = _massaGorda;
    final mm = _massaMagra;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Resultado',
            style: GoogleFonts.montserrat(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
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
                Text(
                  'gordura corporal',
                  style: GoogleFonts.montserrat(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
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
                      fontWeight: FontWeight.w600,
                    ),
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
              if (soma != null) _buildResultRow('Soma das Dobras', '${soma.toStringAsFixed(1)} mm'),
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
      _buildLinhaDate(
        'Próxima Avaliação',
        proximaAvaliacao,
        (d) => setState(() => proximaAvaliacao = d),
        placeholder: 'Definir data',
      ),
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
              style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ex: Perda de gordura e ganho de massa muscular',
                hintStyle: GoogleFonts.montserrat(
                    color: AppColors.textHint, fontSize: 12),
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
              style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Observações gerais...',
                hintStyle: GoogleFonts.montserrat(
                    color: AppColors.textHint, fontSize: 12),
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
        child: Text(
          'Salvar',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  // ─── Widgets helper ─────────────────────────────────────────────────────────

  Widget _buildSecao(String titulo, List<Widget> filhos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            titulo,
            style: GoogleFonts.montserrat(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
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

  Widget _buildLinhaDate(
    String label,
    DateTime? data,
    void Function(DateTime) onPick, {
    String placeholder = '—',
  }) {
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
                primary: AppColors.primary,
                surface: AppColors.surface,
              ),
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
