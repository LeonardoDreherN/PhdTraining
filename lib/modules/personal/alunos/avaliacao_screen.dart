import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'avaliacao_anamnese_view_screen.dart';

// SQL needed in Supabase:
// CREATE TABLE avaliacao_geral (
//   id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
//   aluno_id uuid REFERENCES alunos(id) ON DELETE CASCADE,
//   data_nascimento date,
//   fcrep integer DEFAULT 0,
//   vo2max real DEFAULT 0.0,
//   created_at timestamptz DEFAULT now(),
//   updated_at timestamptz DEFAULT now(),
//   UNIQUE(aluno_id)
// );
// ALTER TABLE avaliacao_geral ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "access_avaliacao_geral" ON avaliacao_geral
//   FOR ALL USING (auth.role() = 'authenticated');

class AvaliacaoScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  const AvaliacaoScreen({super.key, required this.aluno});

  @override
  State<AvaliacaoScreen> createState() => _AvaliacaoScreenState();
}

class _AvaliacaoScreenState extends State<AvaliacaoScreen> {
  final _db = Supabase.instance.client;

  bool _carregando = true;
  DateTime? _dataNascimento;
  int _fcrep = 0;
  double _vo2max = 0;

  @override
  void initState() {
    super.initState();
    // Auto-fill from aluno registration (primary source)
    final nasc = widget.aluno['data_nascimento'] as String?;
    if (nasc != null) _dataNascimento = DateTime.tryParse(nasc);
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final data = await _db
          .from('avaliacao_geral')
          .select()
          .eq('aluno_id', widget.aluno['id'] as String)
          .maybeSingle();

      if (data != null) {
        setState(() {
          // Only use avaliacao_geral birth date if not already set from registration
          if (_dataNascimento == null && data['data_nascimento'] != null) {
            _dataNascimento = DateTime.tryParse(data['data_nascimento'] as String);
          }
          _fcrep = (data['fcrep'] as num?)?.toInt() ?? 0;
          _vo2max = (data['vo2max'] as num?)?.toDouble() ?? 0;
        });
      }
    } catch (_) {}
    setState(() => _carregando = false);
  }

  Future<void> _salvar() async {
    final payload = {
      'aluno_id': widget.aluno['id'] as String,
      'fcrep': _fcrep,
      'vo2max': _vo2max,
      if (_dataNascimento != null)
        'data_nascimento':
            '${_dataNascimento!.year}-${_dataNascimento!.month.toString().padLeft(2, '0')}-${_dataNascimento!.day.toString().padLeft(2, '0')}',
    };
    await _db.from('avaliacao_geral').upsert(payload, onConflict: 'aluno_id');
  }

  int get _idade {
    if (_dataNascimento == null) return 0;
    final hoje = DateTime.now();
    int anos = hoje.year - _dataNascimento!.year;
    if (hoje.month < _dataNascimento!.month ||
        (hoje.month == _dataNascimento!.month &&
            hoje.day < _dataNascimento!.day)) {
      anos--;
    }
    return anos;
  }

  int get _fcmax => _idade > 0 ? 220 - _idade : 0;

  // Karvonen formula: FCReserva = FCmax - FCrep; Zona = FCrep + % * FCReserva
  int _zona(double pct) {
    if (_fcmax == 0) return 0;
    final reserva = _fcmax - _fcrep;
    return (_fcrep + pct * reserva).round();
  }

  Future<void> _editarDataNascimento() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dataNascimento ?? DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
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
    if (picked != null) {
      setState(() => _dataNascimento = picked);
      await _salvar();
    }
  }

  Future<void> _editarFcrep() async {
    final ctrl = TextEditingController(text: _fcrep > 0 ? '$_fcrep' : '');
    final valor = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('FC de Repouso',
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: GoogleFonts.montserrat(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'bpm',
            hintStyle: GoogleFonts.montserrat(color: AppColors.textHint),
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
              final v = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, v);
            },
            child: Text('Salvar',
                style: GoogleFonts.montserrat(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (valor != null && valor > 0) {
      setState(() => _fcrep = valor);
      await _salvar();
    }
  }

  Future<void> _editarVo2max() async {
    final ctrl =
        TextEditingController(text: _vo2max > 0 ? _vo2max.toStringAsFixed(1) : '');
    final valor = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('VO₂máx',
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          style: GoogleFonts.montserrat(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'ml/kg/min',
            hintStyle: GoogleFonts.montserrat(color: AppColors.textHint),
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
            child: Text('Salvar',
                style: GoogleFonts.montserrat(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (valor != null && valor > 0) {
      setState(() => _vo2max = valor);
      await _salvar();
    }
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
              'Avaliação Física',
              style: GoogleFonts.montserrat(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCategorias(),
                  const SizedBox(height: 24),
                  _buildDetalhes(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildCategorias() {
    final cats = [
      const _CatItem(
        label: 'Morfológica',
        icon: Icons.accessibility_new_rounded,
        sub: 'Composição corporal',
        route: '/alunos/avaliacao/morfologica',
      ),
      const _CatItem(
        label: 'Neuromotores',
        icon: Icons.electric_bolt_rounded,
        sub: 'Força e flexibilidade',
        route: '/alunos/avaliacao/neuromotores',
      ),
      const _CatItem(
        label: 'Postural',
        icon: Icons.person_outline_rounded,
        sub: 'Análise postural',
        route: '/alunos/avaliacao/postural',
      ),
      const _CatItem(
        label: 'Anamnese',
        icon: Icons.assignment_outlined,
        sub: 'Histórico de saúde',
        route: '/alunos/avaliacao/anamnese',
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.2,
      children: cats.map((c) => _buildCatCard(c)).toList(),
    );
  }

  Widget _buildCatCard(_CatItem cat) {
    final ativo = cat.route == '/alunos/avaliacao/morfologica' ||
        cat.route == '/alunos/avaliacao/neuromotores' ||
        cat.route == '/alunos/avaliacao/anamnese';
    return GestureDetector(
      onTap: () {
        if (cat.route == '/alunos/avaliacao/anamnese') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  AvaliacaoAnamneseViewScreen(aluno: widget.aluno),
            ),
          );
        } else if (ativo) {
          context.push(cat.route, extra: widget.aluno);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${cat.label} — em breve',
                  style: GoogleFonts.montserrat(color: Colors.black)),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cat.icon, color: AppColors.primary, size: 20),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cat.label,
                  style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  cat.sub,
                  style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalhes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detalhes',
          style: GoogleFonts.montserrat(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Column(
            children: [
              _buildDetalheIdade(),
              _divider(),
              _buildDetalheVo2max(),
              _divider(),
              _buildDetalheFcrep(),
              _divider(),
              _buildDetalheFcmax(),
            ],
          ),
        ),
        if (_fcmax > 0) ...[
          const SizedBox(height: 16),
          _buildZonas(),
        ],
      ],
    );
  }

  Widget _divider() =>
      const Divider(height: 1, thickness: 0.5, color: AppColors.divider);

  Widget _buildDetalheIdade() {
    final temNoCadastro = (widget.aluno['data_nascimento'] as String?) != null;
    final idadeStr = _dataNascimento == null ? '—' : '$_idade anos';
    return _buildDetalheRow(
      label: 'Idade',
      valor: idadeStr,
      trailing: temNoCadastro
          ? Text(
              'do cadastro',
              style: GoogleFonts.montserrat(
                color: AppColors.textHint,
                fontSize: 11,
              ),
            )
          : TextButton(
              onPressed: _editarDataNascimento,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _dataNascimento == null ? 'Definir' : 'Alterar',
                style: GoogleFonts.montserrat(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
    );
  }

  Widget _buildDetalheVo2max() {
    final valorStr = _vo2max > 0 ? '${_vo2max.toStringAsFixed(1)} ml/kg/min' : '0 ml/kg/min';
    return _buildDetalheRow(
      label: 'VO₂máx',
      valor: valorStr,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: _editarVo2max,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Atualizar',
              style: GoogleFonts.montserrat(
                color: AppColors.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetalheFcrep() {
    final valorStr = _fcrep > 0 ? '$_fcrep bpm' : '0 bpm';
    return _buildDetalheRow(
      label: 'FCrep',
      valor: valorStr,
      trailing: TextButton(
        onPressed: _editarFcrep,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Alterar',
          style: GoogleFonts.montserrat(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDetalheFcmax() {
    final formula = _idade > 0 ? '220 - $_idade = $_fcmax bpm' : '—';
    return _buildDetalheRow(
      label: 'FCmáx',
      valor: formula,
    );
  }

  Widget _buildDetalheRow({
    required String label,
    required String valor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.montserrat(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              valor,
              style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildZonas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Zonas de Treino',
          style: GoogleFonts.montserrat(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildZonaCard(
                label: 'Zona 1',
                desc: '60 – 75% FCmáx',
                bpmRange: '${_zona(0.60)} – ${_zona(0.75)} bpm',
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildZonaCard(
                label: 'Zona 2',
                desc: '75 – 85% FCmáx',
                bpmRange: '${_zona(0.75)} – ${_zona(0.85)} bpm',
                color: const Color(0xFFFFC107),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildZonaCard(
                label: 'Zona 3',
                desc: '85 – 90% FCmáx',
                bpmRange: '${_zona(0.85)} – ${_zona(0.90)} bpm',
                color: const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildZonaCard(
                label: 'Zona 4',
                desc: '> 90% FCmáx',
                bpmRange: '> ${_zona(0.90)} bpm',
                color: const Color(0xFFF44336),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildZonaCard({
    required String label,
    required String desc,
    required String bpmRange,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: GoogleFonts.montserrat(
              color: AppColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            bpmRange,
            style: GoogleFonts.montserrat(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CatItem {
  final String label;
  final IconData icon;
  final String sub;
  final String route;
  const _CatItem(
      {required this.label,
      required this.icon,
      required this.sub,
      required this.route});
}
