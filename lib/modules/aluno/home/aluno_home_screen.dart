import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/treino_service.dart';
import '../../personal/home/widgets/phd_logo.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../anamnese/aluno_anamnese_screen.dart';
import '../avaliacoes/aluno_avaliacoes_screen.dart';
import '../perfil/aluno_perfil_config_screen.dart';

class AlunoHomeScreen extends StatefulWidget {
  const AlunoHomeScreen({super.key});

  @override
  State<AlunoHomeScreen> createState() => _AlunoHomeScreenState();
}

class _AlunoHomeScreenState extends State<AlunoHomeScreen> {
  List<Map<String, dynamic>> _fichas = [];
  List<Map<String, dynamic>> _historico = [];
  Map<String, dynamic>? _perfil;
  Map<String, dynamic>? _alunoData;
  Set<String> _concluidos = {};
  Map<int, Set<String>> _concluidosPorDia = {};
  bool _carregando = true;
  bool _historicoExpandido = false;
  int _diaSelecionado = DateTime.now().weekday % 7;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  List<Map<String, dynamic>> get _fichasDoDia {
    if (_fichas.isEmpty) return [];
    return _fichas.where((f) {
      final dias = f['dias_semana'];
      if (dias == null || (dias as List).isEmpty) return true;
      return dias.contains(_diaSelecionado);
    }).toList();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final todosConcs = await Future.wait(
        List.generate(7, (i) => TreinoService.getConcluidos(i)),
      );
      final user = Supabase.instance.client.auth.currentUser!;
      final results = await Future.wait([
        ProfileService.getPerfil(),
        _getAlunoEFichas(),
      ]);
      final hist = await Supabase.instance.client
          .from('treino_execucoes')
          .select('ficha_nome, executado_em, duracao_minutos, total_exercicios')
          .eq('aluno_user_id', user.id)
          .order('executado_em', ascending: false)
          .limit(8);
      final alunoFichas = results[1] as Map<String, dynamic>;
      setState(() {
        _perfil = results[0];
        _alunoData = alunoFichas['aluno'] as Map<String, dynamic>?;
        _fichas = alunoFichas['fichas'] as List<Map<String, dynamic>>;
        _concluidosPorDia = {for (var i = 0; i < 7; i++) i: todosConcs[i]};
        _concluidos = _concluidosPorDia[_diaSelecionado] ?? {};
        _historico = (hist as List).cast<Map<String, dynamic>>();
      });

      // Agenda notificações de treino para os próximos 14 dias
      NotificationService.agendarTreinos(_fichas);

      // Check for pending anamnese
      final aluno = _alunoData;
      if (aluno != null && mounted) {
        final tipo = aluno['anamnese_tipo'] as String? ?? 'nenhuma';
        final preenchida = aluno['anamnese_preenchida'] as bool? ?? false;
        if (tipo != 'nenhuma' && !preenchida) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AlunoAnamneseScreen(
                  tipo: tipo,
                  alunoId: aluno['id'] as String,
                ),
              ));
            }
          });
        }
      }
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<Map<String, dynamic>> _getAlunoEFichas() async {
    final user = Supabase.instance.client.auth.currentUser!;

    Map<String, dynamic>? alunoRow = await Supabase.instance.client
        .from('alunos')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    alunoRow ??= await Supabase.instance.client
        .from('alunos')
        .select()
        .eq('email', user.email!)
        .maybeSingle();

    if (alunoRow == null) return {'aluno': null, 'fichas': []};
    final fichas = await FichaService.fichasDoAluno(alunoRow['id'] as String);
    return {'aluno': alunoRow, 'fichas': fichas};
  }

  String _getSaudacao() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  void _mostrarModoInicio(Map<String, dynamic> ficha) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ModoInicioSheet(
        nomeFicha: ficha['nome'] ?? '',
        onIniciar: (modoVideo) async {
          Navigator.pop(context);
          await context.push('/aluno/treino', extra: {
            'ficha': ficha,
            'modoVideo': modoVideo,
            'diaSelecionado': _diaSelecionado,
          });
          if (mounted) _carregar();
        },
        onSimples: () {
          Navigator.pop(context);
          context.push('/aluno/treino-simples', extra: ficha);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nome = _perfil?['nome'] ?? 'Aluno';
    final primeiroNome = nome.toString().split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            _buildAvatar(nome),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${_getSaudacao()}, $primeiroNome',
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ),
            const PHDLogo(fontSize: 26),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline_rounded,
                color: AppColors.textSecondary, size: 22),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlunoPerfilConfigScreen()),
            ),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _carregar,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBanner(primeiroNome),
                    const SizedBox(height: 20),
                    _buildCalendarioSemanal(),
                    const SizedBox(height: 24),
                    const Text('Meus Treinos',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    _fichasDoDia.isEmpty ? _buildSemTreinos() : _buildFichas(),
                    const SizedBox(height: 16),
                    _buildAvaliacoesCard(),
                    const SizedBox(height: 10),
                    _buildProgressoCard(),
                    if (_historico.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildHistorico(),
                    ],
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar(String nome) {
    final url = _perfil?['avatar_url'] as String?;
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary.withValues(alpha: 0.15),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.hardEdge,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Center(
                child: Text(inicial,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
              errorWidget: (_, __, ___) => Center(
                child: Text(inicial,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
            )
          : Center(
              child: Text(inicial,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
            ),
    );
  }

  Widget _buildBanner(String nome) {
    final total = _fichasDoDia.length;
    final concluidosHoje = _fichasDoDia.where((f) {
      final fichaId = f['fichas']?['id']?.toString() ?? '';
      return _concluidos.contains(fichaId);
    }).length;

    String subtitulo;
    if (total == 0) {
      subtitulo = 'Sem treino hoje — descanse!';
    } else if (concluidosHoje == total) {
      subtitulo = 'Todos os treinos do dia concluídos!';
    } else if (concluidosHoje > 0) {
      subtitulo = '$concluidosHoje de $total treinos concluídos';
    } else {
      subtitulo = '$total ${total == 1 ? 'treino' : 'treinos'} hoje';
    }

    final allDone = concluidosHoje == total && total > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: allDone
              ? [AppColors.active, const Color(0xFF2E7D32)]
              : [const Color(0xFF1A1A1A), const Color(0xFF2A2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: allDone ? Colors.transparent : AppColors.divider,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            allDone ? 'Arrasou, $nome!' : 'Pronto para treinar, $nome?',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(subtitulo,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildCalendarioSemanal() {
    const labels = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    final hoje = DateTime.now().weekday % 7;

    final diasComTreino = <int>{};
    for (final f in _fichas) {
      final dias = f['dias_semana'];
      if (dias is List) {
        for (final d in dias) { diasComTreino.add(d as int); }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final isHoje = i == hoje;
          final isSelecionado = i == _diaSelecionado;
          final temTreino = diasComTreino.contains(i);

          // Verifica se todos os treinos deste dia foram concluídos
          final fichasDia = _fichas.where((f) {
            final dias = f['dias_semana'];
            if (dias == null || (dias as List).isEmpty) return true;
            return dias.contains(i);
          }).toList();
          final concsdia = _concluidosPorDia[i] ?? {};
          final diaConcluido = temTreino &&
              fichasDia.isNotEmpty &&
              fichasDia.every((f) => concsdia.contains(f['fichas']?['id']?.toString() ?? ''));

          return GestureDetector(
            onTap: () => setState(() {
              _diaSelecionado = i;
              _concluidos = _concluidosPorDia[i] ?? {};
            }),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelecionado
                        ? (diaConcluido ? AppColors.active : AppColors.primary)
                        : diaConcluido
                            ? AppColors.active.withValues(alpha: 0.2)
                            : temTreino
                                ? AppColors.primary.withValues(alpha: 0.15)
                                : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelecionado
                          ? (diaConcluido ? AppColors.active : AppColors.primary)
                          : diaConcluido
                              ? AppColors.active.withValues(alpha: 0.6)
                              : temTreino
                                  ? AppColors.primary.withValues(alpha: 0.4)
                                  : AppColors.divider,
                      width: isHoje && !isSelecionado ? 2 : 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        color: isSelecionado
                            ? Colors.black
                            : diaConcluido
                                ? AppColors.active
                                : temTreino
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                        fontWeight:
                            isSelecionado || temTreino ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                temTreino
                    ? Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isSelecionado
                              ? Colors.black
                              : diaConcluido
                                  ? AppColors.active
                                  : AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      )
                    : const SizedBox(height: 5),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFichas() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _fichasDoDia.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final af = _fichasDoDia[i];
        final ficha = af['fichas'] as Map<String, dynamic>;
        final fichaId = ficha['id']?.toString() ?? '';
        final concluido = _concluidos.contains(fichaId);

        return GestureDetector(
          onTap: () => _mostrarModoInicio(ficha),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: concluido ? AppColors.active.withValues(alpha: 0.07) : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: concluido ? AppColors.active.withValues(alpha: 0.45) : AppColors.divider,
                width: concluido ? 1.5 : 0.5,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: concluido
                        ? AppColors.active.withValues(alpha: 0.15)
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    concluido ? Icons.check_circle_rounded : Icons.fitness_center,
                    color: concluido ? AppColors.active : AppColors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ficha['nome'],
                        style: TextStyle(
                          color: concluido ? AppColors.active : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        concluido
                            ? 'Concluído hoje!'
                            : (ficha['descricao']?.toString().isNotEmpty == true
                                ? ficha['descricao']
                                : 'Toque para iniciar'),
                        style: TextStyle(
                          color: concluido
                              ? AppColors.active.withValues(alpha: 0.75)
                              : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                concluido
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.active, size: 28)
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Iniciar',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvaliacoesCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const AlunoAvaliacoesScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF4FC3F7).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.assignment_rounded,
                color: Color(0xFF4FC3F7), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Avaliação Física',
                  style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              Text('Composição corporal e gráficos',
                  style: GoogleFonts.montserrat(
                      color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textHint),
        ]),
      ),
    );
  }

  Widget _buildProgressoCard() {
    return GestureDetector(
      onTap: () => context.push('/aluno/progresso'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFF7986CB).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.auto_graph_rounded,
                  color: Color(0xFF7986CB), size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meu Progresso',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15)),
                  Text('Fotos mensais e evolução física',
                      style:
                          TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorico() {
    final ultimo = _historico.first;
    final ultimoLabel = _labelData(ultimo['executado_em'] as String?);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header colapsável
        GestureDetector(
          onTap: () => setState(() => _historicoExpandido = !_historicoExpandido),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.active.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: AppColors.active, size: 17),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Últimos Treinos',
                        style: GoogleFonts.montserrat(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(
                      '${_historico.length} sessões · último $ultimoLabel',
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              AnimatedRotation(
                turns: _historicoExpandido ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary, size: 20),
              ),
            ]),
          ),
        ),
        // Lista expandida
        if (_historicoExpandido) ...[
          const SizedBox(height: 6),
          ...(_historico.map((ex) => _buildHistoricoItem(ex))),
        ],
      ],
    );
  }

  Widget _buildHistoricoItem(Map<String, dynamic> ex) {
    final nome = ex['ficha_nome'] as String? ?? 'Treino';
    final duracao = (ex['duracao_minutos'] as num?)?.toInt() ?? 0;
    final totalEx = (ex['total_exercicios'] as num?)?.toInt() ?? 0;
    final dataLabel = _labelData(ex['executado_em'] as String?);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.active.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.check_circle_outline_rounded,
                color: AppColors.active, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    style: GoogleFonts.montserrat(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Row(children: [
                  _tagHistorico(Icons.schedule_outlined, dataLabel),
                  const SizedBox(width: 10),
                  if (duracao > 0)
                    _tagHistorico(Icons.timer_outlined, '${duracao}min'),
                  if (totalEx > 0) ...[
                    const SizedBox(width: 10),
                    _tagHistorico(Icons.fitness_center, '${totalEx}ex'),
                  ],
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagHistorico(IconData icon, String texto) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: AppColors.textHint),
      const SizedBox(width: 3),
      Text(texto,
          style: GoogleFonts.montserrat(
              color: AppColors.textHint, fontSize: 11)),
    ]);
  }

  String _labelData(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final hoje = DateTime.now();
    final diff = DateTime(hoje.year, hoje.month, hoje.day)
        .difference(DateTime(dt.year, dt.month, dt.day))
        .inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    if (diff < 7) return 'há $diff dias';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  Widget _buildSemTreinos() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.textHint, size: 14),
          const SizedBox(width: 8),
          Text('Nenhuma ficha para hoje',
              style: GoogleFonts.montserrat(
                  color: AppColors.textHint, fontSize: 13)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Bottom sheet — seleção de modo de início

class _ModoInicioSheet extends StatefulWidget {
  final String nomeFicha;
  final void Function(bool modoVideo) onIniciar;
  final VoidCallback onSimples;

  const _ModoInicioSheet({
    required this.nomeFicha,
    required this.onIniciar,
    required this.onSimples,
  });

  @override
  State<_ModoInicioSheet> createState() => _ModoInicioSheetState();
}

class _ModoInicioSheetState extends State<_ModoInicioSheet> {
  bool _comVideo = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.fitness_center_rounded, color: AppColors.primary, size: 32),
          const SizedBox(height: 12),
          Text(
            widget.nomeFicha,
            style: const TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          const Text('Como deseja visualizar o treino?',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),

          // Botão Iniciar Treino com toggle de vídeo
          InkWell(
            onTap: () => widget.onIniciar(_comVideo),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Iniciar Treino',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15)),
                            Text('Contagem regressiva, séries e carga',
                                style: TextStyle(
                                    color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: AppColors.primary, size: 20),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Toggle demonstração em vídeo
                  GestureDetector(
                    onTap: () => setState(() => _comVideo = !_comVideo),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _comVideo
                            ? const Color(0xFF7986CB).withValues(alpha: 0.12)
                            : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _comVideo
                              ? const Color(0xFF7986CB).withValues(alpha: 0.4)
                              : AppColors.divider,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.slow_motion_video_rounded,
                            color: _comVideo
                                ? const Color(0xFF7986CB)
                                : AppColors.textSecondary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Com demonstração em vídeo',
                              style: TextStyle(
                                color: _comVideo
                                    ? const Color(0xFF7986CB)
                                    : AppColors.textSecondary,
                                fontSize: 13,
                                fontWeight: _comVideo
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          Switch(
                            value: _comVideo,
                            onChanged: (v) => setState(() => _comVideo = v),
                            activeThumbColor: const Color(0xFF7986CB),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),
          _buildOpcao(
            onTap: widget.onSimples,
            icon: Icons.list_alt_rounded,
            titulo: 'Visualização Simplificada',
            subtitulo: 'Ver todos os exercícios, séries e repetições',
            color: const Color(0xFF7986CB),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildOpcao({
    required VoidCallback onTap,
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                  Text(subtitulo,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
