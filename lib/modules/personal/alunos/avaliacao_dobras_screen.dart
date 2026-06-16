import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import 'avaliacao_dobras_form_screen.dart';
import 'avaliacao_dobras_graficos_screen.dart';

// SQL needed in Supabase:
// CREATE TABLE avaliacao_morfologica_dobras (
//   id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
//   aluno_id uuid REFERENCES alunos(id) ON DELETE CASCADE,
//   protocolo text NOT NULL,
//   data_avaliacao date DEFAULT CURRENT_DATE,
//   peso real,
//   idade integer,
//   tricipital real,
//   subescapular real,
//   peitoral real,
//   abdominal real,
//   supraoiliaca real,
//   coxa real,
//   perna real,
//   axilar_media real,
//   soma_dobras real,
//   perc_gordura real,
//   massa_gorda real,
//   massa_magra real,
//   excluida boolean DEFAULT false,
//   created_at timestamptz DEFAULT now()
// );
// ALTER TABLE avaliacao_morfologica_dobras ENABLE ROW LEVEL SECURITY;
// CREATE POLICY "access_avaliacao_morfologica_dobras" ON avaliacao_morfologica_dobras
//   FOR ALL USING (auth.role() = 'authenticated');

class AvaliacaoDobraScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  const AvaliacaoDobraScreen({super.key, required this.aluno});

  @override
  State<AvaliacaoDobraScreen> createState() => _AvaliacaoDobraScreenState();
}

class _AvaliacaoDobraScreenState extends State<AvaliacaoDobraScreen> {
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
          .from('avaliacao_morfologica_dobras')
          .select()
          .eq('aluno_id', widget.aluno['id'] as String)
          .eq('excluida', false)
          .order('data_avaliacao', ascending: false);
      setState(() => _avaliacoes = List<Map<String, dynamic>>.from(data));
    } catch (_) {}
    setState(() => _carregando = false);
  }

  void _novaAvaliacao() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _ProtocoloSheet(
        onSelecionado: (protocolo) {
          Navigator.pop(ctx);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AvaliacaoDobraFormScreen(
                aluno: widget.aluno,
                protocolo: protocolo,
              ),
            ),
          ).then((_) => _carregar());
        },
      ),
    );
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
              'Dobras Cutâneas',
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
                onPressed: _novaAvaliacao,
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
              color: AppColors.textHint,
              fontSize: 12,
            ),
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
    final data = av['data_avaliacao'] as String? ?? '';
    final protocolo = DobraProtocolos.nomeForId(av['protocolo'] as String? ?? '');
    final perc = (av['perc_gordura'] as num?)?.toDouble();
    final peso = (av['peso'] as num?)?.toDouble();

    DateTime? dataObj;
    if (data.isNotEmpty) dataObj = DateTime.tryParse(data);
    final dataStr = dataObj != null
        ? '${dataObj.day.toString().padLeft(2, '0')}/${dataObj.month.toString().padLeft(2, '0')}/${dataObj.year}'
        : data;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AvaliacaoDobraFormScreen(
              aluno: widget.aluno,
              protocolo: av['protocolo'] as String,
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
                    protocolo,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dataStr,
                    style: GoogleFonts.montserrat(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (peso != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${peso.toStringAsFixed(1)} kg',
                      style: GoogleFonts.montserrat(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
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
                  Text(
                    'gordura',
                    style: GoogleFonts.montserrat(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom sheet de seleção de protocolo ───────────────────────────────────

class _ProtocoloSheet extends StatelessWidget {
  final void Function(String protocolo) onSelecionado;
  const _ProtocoloSheet({required this.onSelecionado});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'De Dobras',
                      style: GoogleFonts.montserrat(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Escolha o formulário',
                      style: GoogleFonts.montserrat(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: ListView(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: DobraProtocolos.todos
                  .map((p) => _buildItem(context, p))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, DobraProtocolo p) {
    return GestureDetector(
      onTap: () => onSelecionado(p.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                p.nome,
                style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Modelo de protocolos ────────────────────────────────────────────────────

class DobraProtocolo {
  final String id;
  final String nome;
  final List<String> campos;
  final String genero;
  final String formula;

  const DobraProtocolo({
    required this.id,
    required this.nome,
    required this.campos,
    required this.genero,
    required this.formula,
  });
}

class DobraProtocolos {
  static const todos = [
    DobraProtocolo(
      id: 'pollock7',
      nome: 'Pollock, 1984 – 7 Dobras',
      campos: ['peitoral', 'axilar_media', 'tricipital', 'subescapular', 'abdominal', 'supraoiliaca', 'coxa'],
      genero: 'ambos',
      formula: 'D = 1.112 − (0.00043499 × Σ7) + (0.00000055 × Σ7²) − (0.00028826 × idade) → Siri',
    ),
    DobraProtocolo(
      id: 'pollock3m',
      nome: 'Pollock, 1984 – 3 Dobras (Homens)',
      campos: ['peitoral', 'abdominal', 'coxa'],
      genero: 'masculino',
      formula: 'D = 1.10938 − (0.0008267 × Σ3) + (0.0000016 × Σ3²) − (0.0002574 × idade) → Siri',
    ),
    DobraProtocolo(
      id: 'pollock3f',
      nome: 'Pollock, 1984 – 3 Dobras (Mulheres)',
      campos: ['tricipital', 'supraoiliaca', 'coxa'],
      genero: 'feminino',
      formula: 'D = 1.0994921 − (0.0009929 × Σ3) + (0.0000023 × Σ3²) − (0.0001392 × idade) → Siri',
    ),
    DobraProtocolo(
      id: 'faulkner4',
      nome: 'Faulkner, 1968 – 4 Dobras',
      campos: ['tricipital', 'subescapular', 'supraoiliaca', 'abdominal'],
      genero: 'ambos',
      formula: '% G = (0.153 × Σ4) + 5.783',
    ),
    DobraProtocolo(
      id: 'guedes3m',
      nome: 'Guedes, 1994 – 3 Dobras (Homens)',
      campos: ['subescapular', 'abdominal', 'supraoiliaca'],
      genero: 'masculino',
      formula: 'D = 1.171468 − (0.0671966 × log Σ3) − (0.0008 × idade) → Siri',
    ),
    DobraProtocolo(
      id: 'guedes3f',
      nome: 'Guedes, 1994 – 3 Dobras (Mulheres)',
      campos: ['subescapular', 'supraoiliaca', 'coxa'],
      genero: 'feminino',
      formula: 'D = 1.166594 − (0.0706741 × log Σ3) − (0.00033 × idade) → Siri',
    ),
    DobraProtocolo(
      id: 'petroski4m',
      nome: 'Petroski, 1995 – 4 Dobras (Homens)',
      campos: ['tricipital', 'subescapular', 'supraoiliaca', 'perna'],
      genero: 'masculino',
      formula: 'D = 1.10726863 − (0.00081201 × Σ4) + (0.00000212 × Σ4²) − (0.00041761 × idade) → Siri',
    ),
    DobraProtocolo(
      id: 'petroski4f',
      nome: 'Petroski, 1995 – 4 Dobras (Mulheres)',
      campos: ['tricipital', 'supraoiliaca', 'abdominal', 'perna'],
      genero: 'feminino',
      formula: 'D = 1.19547966 − (0.07513507 × log Σ4) − (0.00032010 × idade) → Siri',
    ),
  ];

  static String nomeForId(String id) {
    try {
      return todos.firstWhere((p) => p.id == id).nome;
    } catch (_) {
      return id;
    }
  }

  static DobraProtocolo? findById(String id) {
    try {
      return todos.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
