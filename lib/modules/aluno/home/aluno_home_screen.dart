import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/treino_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../anamnese/aluno_anamnese_screen.dart';
import '../avaliacoes/aluno_avaliacoes_screen.dart';
import '../perfil/aluno_perfil_config_screen.dart';

/// A tela que o aluno abre na academia.
///
/// Ela responde uma pergunta antes de qualquer outra coisa: **o que eu treino
/// hoje?** Tudo o mais — histórico, avaliações, progresso — vem depois, e
/// nenhum deles pode empurrar o treino de hoje para baixo da dobra.
class AlunoHomeScreen extends StatefulWidget {
  const AlunoHomeScreen({super.key});

  @override
  State<AlunoHomeScreen> createState() => _AlunoHomeScreenState();
}

class _AlunoHomeScreenState extends State<AlunoHomeScreen> {
  Map<String, dynamic>? _perfil;
  Map<String, dynamic>? _aluno;
  List<Map<String, dynamic>> _fichas = [];
  List<Map<String, dynamic>> _historico = [];
  Map<int, Set<String>> _feitoPorDia = {};

  bool _carregando = true;
  String? _erro;
  int _dia = DateTime.now().weekday % 7;

  int get _hoje => DateTime.now().weekday % 7;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      // Quatro requisições em paralelo. A versão anterior fazia dez, sendo
      // sete só para saber quais dias da semana já tinham treino feito.
      final r = await Future.wait([
        ProfileService.getPerfil(),
        _alunoEFichas(),
        TreinoService.concluidosDaSemana(),
        TreinoService.historico(),
      ]);
      if (!mounted) return;

      final dados = r[1] as Map<String, dynamic>;
      setState(() {
        _perfil = r[0] as Map<String, dynamic>?;
        _aluno = dados['aluno'] as Map<String, dynamic>?;
        _fichas = dados['fichas'] as List<Map<String, dynamic>>;
        _feitoPorDia = r[2] as Map<int, Set<String>>;
        _historico = r[3] as List<Map<String, dynamic>>;
      });

      NotificationService.agendarTreinos(_fichas);
      _checarAnamnese();
    } catch (e) {
      // Antes não havia `catch`: qualquer falha de rede deixava a tela
      // vazia, sem nada dizendo que houve erro nem como tentar de novo.
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<Map<String, dynamic>> _alunoEFichas() async {
    final user = Supabase.instance.client.auth.currentUser!;

    var linha = await Supabase.instance.client
        .from('alunos')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    // Quem foi cadastrado antes do vínculo automático só tem o e-mail.
    if (linha == null && user.email != null) {
      linha = await Supabase.instance.client
          .from('alunos')
          .select()
          .eq('email', user.email!)
          .maybeSingle();
    }

    if (linha == null) return {'aluno': null, 'fichas': <Map<String, dynamic>>[]};
    final fichas = await FichaService.fichasDoAluno(linha['id'] as String);
    return {'aluno': linha, 'fichas': fichas};
  }

  void _checarAnamnese() {
    final a = _aluno;
    if (a == null) return;
    final tipo = a['anamnese_tipo'] as String? ?? 'nenhuma';
    final preenchida = a['anamnese_preenchida'] as bool? ?? false;
    if (tipo == 'nenhuma' || preenchida) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AlunoAnamneseScreen(
          tipo: tipo,
          alunoId: a['id'] as String,
        ),
      ));
    });
  }

  /// Fichas do dia escolhido. Ficha sem dia marcado vale para todo dia —
  /// é o padrão de quem treina sem rotina fixa.
  List<Map<String, dynamic>> get _doDia {
    return _fichas.where((f) {
      final dias = f['dias_semana'];
      if (dias == null || (dias as List).isEmpty) return true;
      return dias.contains(_dia);
    }).toList();
  }

  bool _feita(Map<String, dynamic> f) {
    final id = (f['fichas'] as Map?)?['id'] as String?;
    return id != null && (_feitoPorDia[_dia]?.contains(id) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final nome = (_perfil?['nome'] as String?)?.trim();
    final primeiro = (nome == null || nome.isEmpty) ? null : nome.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _carregando
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : _erro != null
                ? PhdEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Não consegui carregar',
                    message: _erro!,
                    actionLabel: 'Tentar de novo',
                    onAction: _carregar,
                  )
                : RefreshIndicator(
                    color: AppColors.accent,
                    backgroundColor: AppColors.surface,
                    onRefresh: _carregar,
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: AppSpacing.huge),
                      children: [
                        _cabecalho(primeiro),
                        const SizedBox(height: AppSpacing.lg),
                        _regua(),
                        const SizedBox(height: AppSpacing.xl),
                        _treinoDoDia(),
                        const SizedBox(height: AppSpacing.xl),
                        _atalhos(),
                        if (_historico.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xl),
                          _historicoRecente(),
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _cabecalho(String? primeiroNome) {
    final hora = DateTime.now().hour;
    final saudacao = hora < 12
        ? 'Bom dia'
        : hora < 18
            ? 'Boa tarde'
            : 'Boa noite';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(saudacao, style: AppText.caption(13)),
                const SizedBox(height: 2),
                Text(
                  primeiroNome ?? 'Bem-vindo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(24),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlunoPerfilConfigScreen()),
            ),
            child: PhdAvatar(
              name: primeiroNome ?? 'A',
              imageUrl: _perfil?['avatar_url'] as String?,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  /// Régua da semana. O ponto embaixo do dia diz se já treinou — é a
  /// informação que o aluno busca de relance, antes de qualquer texto.
  Widget _regua() {
    const letras = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final selecionado = i == _dia;
          final ehHoje = i == _hoje;
          final treinou = (_feitoPorDia[i] ?? const {}).isNotEmpty;
          final temTreino = _fichas.any((f) {
            final dias = f['dias_semana'];
            return dias == null || (dias as List).isEmpty || dias.contains(i);
          });

          return GestureDetector(
            onTap: () => setState(() => _dia = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 44,
              decoration: BoxDecoration(
                color: selecionado ? AppColors.accent : AppColors.surface,
                borderRadius: AppRadius.rMd,
                border: ehHoje && !selecionado
                    ? Border.all(color: AppColors.lineStrong)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    letras[i],
                    style: AppText.bodyStrong(
                      13.5,
                      color: selecionado
                          ? AppColors.onAccent
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: treinou
                          ? (selecionado ? AppColors.onAccent : AppColors.success)
                          : temTreino
                              ? (selecionado
                                  ? AppColors.onAccent.withValues(alpha: 0.35)
                                  : AppColors.textMuted)
                              : Colors.transparent,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _treinoDoDia() {
    final lista = _doDia;

    if (_aluno == null) {
      return Padding(
        padding: AppSpacing.screen,
        child: PhdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Conta ainda não vinculada', style: AppText.title(16)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Não encontrei seu cadastro de aluno. Peça ao seu personal '
                'para conferir o e-mail que ele cadastrou para você.',
                style: AppText.body(13.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (lista.isEmpty) {
      return Padding(
        padding: AppSpacing.screen,
        child: PhdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.self_improvement_rounded,
                      size: 18, color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    _dia == _hoje ? 'Descanso hoje' : 'Sem treino neste dia',
                    style: AppText.title(16),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _fichas.isEmpty
                    ? 'Seu personal ainda não atribuiu nenhum treino. '
                        'Fale com ele.'
                    : 'Descanso faz parte do treino. Toque em outro dia da '
                        'semana para ver o que vem.',
                style: AppText.body(13.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: PhdSectionHeader(
            label: _dia == _hoje ? 'Treino de hoje' : 'Treino do dia',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final f in lista)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.sm,
            ),
            child: _cartaoTreino(f),
          ),
      ],
    );
  }

  Widget _cartaoTreino(Map<String, dynamic> f) {
    final ficha = (f['fichas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final nome = ficha['nome'] as String? ?? 'Treino';
    final qtd = (f['qtd_exercicios'] as num?)?.toInt() ?? 0;
    final feita = _feita(f);
    final vazia = qtd == 0;

    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.title(17),
                ),
              ),
              if (feita)
                const PhdStatusChip(label: 'Feito', tone: PhdTone.success),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            vazia
                ? 'Seu personal ainda não montou este treino'
                : '$qtd ${qtd == 1 ? 'exercício' : 'exercícios'}',
            style: AppText.caption(12.5),
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdButton(
            // Treino vazio não tem o que executar: deixar o botão ativo só
            // levaria a uma tela em branco no meio da academia.
            label: feita ? 'Treinar de novo' : 'Começar treino',
            icon: Icons.play_arrow_rounded,
            variant: feita ? PhdButtonVariant.secondary : PhdButtonVariant.primary,
            onPressed: vazia ? null : () => _escolherModo(ficha),
          ),
        ],
      ),
    );
  }

  Widget _atalhos() {
    return Padding(
      padding: AppSpacing.screen,
      child: Row(
        children: [
          Expanded(
            child: _atalho(
              icone: Icons.trending_up_rounded,
              titulo: 'Progresso',
              onTap: () => context.push('/aluno/progresso'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _atalho(
              icone: Icons.assignment_outlined,
              titulo: 'Avaliações',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AlunoAvaliacoesScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _atalho({
    required IconData icone,
    required String titulo,
    required VoidCallback onTap,
  }) {
    return PhdCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg, vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Icon(icone, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong(13.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historicoRecente() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: PhdSectionHeader(label: 'Últimos treinos'),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final h in _historico.take(5))
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xs,
            ),
            child: PhdListRow(
              title: h['ficha_nome'] as String? ?? 'Treino',
              subtitle: _quando(h['executado_em'] as String?),
              trailingValue: _duracao(h['duracao_minutos']),
            ),
          ),
      ],
    );
  }

  /// "Hoje", "Ontem" ou "12/03" — data absoluta só quando já saiu da memória
  /// recente, que é quando ela passa a ajudar mais do que o nome do dia.
  String _quando(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal();
    if (d == null) return '';
    final hoje = DateTime.now();
    final dias = DateTime(hoje.year, hoje.month, hoje.day)
        .difference(DateTime(d.year, d.month, d.day))
        .inDays;
    if (dias == 0) return 'Hoje';
    if (dias == 1) return 'Ontem';
    if (dias < 7) return 'Há $dias dias';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  String _duracao(Object? minutos) {
    final m = (minutos as num?)?.toInt();
    if (m == null || m <= 0) return '';
    if (m < 60) return '${m}min';
    final h = m ~/ 60;
    final resto = m % 60;
    return resto == 0 ? '${h}h' : '${h}h$resto';
  }

  Future<void> _escolherModo(Map<String, dynamic> ficha) async {
    final modo = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (_) => const _FolhaModo(),
    );
    if (modo == null || !mounted) return;

    if (modo == 'lista') {
      await context.push('/aluno/treino-simples', extra: ficha);
    } else {
      await context.push('/aluno/treino', extra: {
        'ficha': ficha,
        'modoVideo': modo == 'video',
        'diaSelecionado': _dia,
      });
    }
    if (mounted) _carregar();
  }
}

/// Como o aluno quer executar: guiado série a série, com vídeo, ou só a
/// lista para quem já sabe o treino de cor.
class _FolhaModo extends StatelessWidget {
  const _FolhaModo();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 34,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lineStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Como quer treinar?', style: AppText.title(17)),
          const SizedBox(height: AppSpacing.lg),
          _opcao(
            context,
            valor: 'guiado',
            icone: Icons.timer_outlined,
            titulo: 'Guiado',
            descricao: 'Um exercício por vez, com cronômetro de descanso.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _opcao(
            context,
            valor: 'video',
            icone: Icons.play_circle_outline_rounded,
            titulo: 'Guiado com vídeo',
            descricao: 'Mostra a execução antes de cada exercício.',
          ),
          const SizedBox(height: AppSpacing.sm),
          _opcao(
            context,
            valor: 'lista',
            icone: Icons.list_alt_rounded,
            titulo: 'Só a lista',
            descricao: 'Para quem já sabe o treino e quer consultar rápido.',
          ),
        ],
      ),
    );
  }

  Widget _opcao(
    BuildContext context, {
    required String valor,
    required IconData icone,
    required String titulo,
    required String descricao,
  }) {
    return PhdCard(
      onTap: () => Navigator.pop(context, valor),
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Icon(icone, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(titulo, style: AppText.bodyStrong(14)),
                const SizedBox(height: 2),
                Text(descricao, style: AppText.caption(12)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 19, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
