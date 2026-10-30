import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/avaliacao.dart';
import '../../../core/models/diario.dart';
import '../../../core/models/recursos_aluno.dart';
import '../../../core/models/dieta.dart';
import '../../../core/services/avaliacao_service.dart';
import '../../../core/services/diario_service.dart';
import '../../../core/services/dieta_service.dart';
import '../../../core/services/lembretes_service.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/treino_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/utils/dieta_calculos.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../core/widgets/widgets.dart';
import '../anamnese/aluno_anamnese_screen.dart';
import '../avaliacoes/aluno_avaliacoes_screen.dart';
import '../dieta/cartao_agua.dart';
import '../dieta/folhas_registro.dart';
import '../../chat/chat_screen.dart';
import '../../personal/mensagens/caixa_screen.dart' show BotaoMensagens;
import 'cartao_consulta.dart';
import '../../personal/dieta/metas_recursos.dart';
import '../perfil/aluno_perfil_config_screen.dart';

/// A tela que o aluno abre na academia — e a que precisa dar vontade de
/// abrir nos outros dias também.
///
/// Ela responde uma pergunta antes de qualquer outra coisa: **o que eu treino
/// hoje?** Logo abaixo vem o que faz voltar amanhã: a semana se enchendo, a
/// sequência de semanas, a dieta do dia e o corpo mudando. Nenhum desses
/// blocos pode empurrar o treino de hoje para baixo da dobra.
class AlunoHomeScreen extends StatefulWidget {
  const AlunoHomeScreen({super.key});

  @override
  State<AlunoHomeScreen> createState() => _AlunoHomeScreenState();
}

/// Cores dos macros. Fora de `AppColors` porque só existem aqui e na dieta:
/// são categorias, não estados. Tons médios, que leem sobre preto e branco.
// Azul fixo, não a cor da marca: com a marca vermelha, proteína em
// vermelho ficaria colada na gordura (rosa).
const _corProteina = Color(0xFF3B82F6);
const _corCarbo = Color(0xFFF59E0B);
const _corGordura = Color(0xFFEC4899);
const _corDescanso = Color(0xFF818CF8);

const _nomesDia = [
  'Domingo',
  'Segunda',
  'Terça',
  'Quarta',
  'Quinta',
  'Sexta',
  'Sábado'
];
const _meses = [
  'janeiro',
  'fevereiro',
  'março',
  'abril',
  'maio',
  'junho',
  'julho',
  'agosto',
  'setembro',
  'outubro',
  'novembro',
  'dezembro',
];

class _AlunoHomeScreenState extends State<AlunoHomeScreen> {
  Map<String, dynamic>? _perfil;
  Map<String, dynamic>? _aluno;
  Map<String, dynamic>? _personal;
  List<Map<String, dynamic>> _fichas = [];
  List<Map<String, dynamic>> _historico = [];
  List<({DateTime quando, int minutos})> _execucoes = [];
  Map<int, Set<String>> _feitoPorDia = {};
  PlanoAlimentar? _plano;
  Set<String> _refeicoesFeitas = {};
  List<ResumoSessao> _avaliacoes = [];
  List<RegistroPeso> _pesos = [];

  /// O que o profissional liberou para este aluno (ver `RecursosAluno`).
  RecursosAluno get _recursos => RecursosAluno.doMapa(_aluno?['recursos']);

  /// Muda a cada carga: é a chave do cartão de água, que guarda o próprio
  /// estado. Sem ela, beber água na tela da dieta e voltar mostraria o
  /// número antigo.
  int _versao = 0;

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
      _carregando = _perfil == null;
      _erro = null;
    });
    try {
      // Tudo em paralelo. O que depende do cadastro do aluno (fichas, dieta,
      // avaliações, personal) sai em paralelo dentro de `_doAluno`, assim
      // que o id chega.
      final r = await Future.wait([
        ProfileService.getPerfil(),
        _doAluno(),
        TreinoService.concluidosDaSemana(),
        TreinoService.historico(limite: 5),
        TreinoService.execucoesRecentes(),
      ]);
      if (!mounted) return;

      final dados = r[1] as Map<String, dynamic>;
      setState(() {
        _perfil = r[0] as Map<String, dynamic>?;
        _aluno = dados['aluno'] as Map<String, dynamic>?;
        _fichas = dados['fichas'] as List<Map<String, dynamic>>;
        _personal = dados['personal'] as Map<String, dynamic>?;
        _plano = dados['plano'] as PlanoAlimentar?;
        _refeicoesFeitas = dados['feitas'] as Set<String>? ?? {};
        _avaliacoes = dados['avaliacoes'] as List<ResumoSessao>? ?? [];
        _pesos = dados['pesos'] as List<RegistroPeso>? ?? [];
        _versao++;
        _feitoPorDia = r[2] as Map<int, Set<String>>;
        _historico = r[3] as List<Map<String, dynamic>>;
        _execucoes = r[4] as List<({DateTime quando, int minutos})>;
      });

      NotificationService.agendarTreinos(_fichas);
      // Lembretes da dieta seguem o plano: reagendar aqui acompanha o
      // profissional mudando o horário de uma refeição.
      unawaited(LembretesService.aplicar(_plano));
      _checarAnamnese();
    } catch (e) {
      // Sem `catch`, qualquer falha de rede deixava a tela vazia, sem nada
      // dizendo que houve erro nem como tentar de novo.
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<Map<String, dynamic>> _doAluno() async {
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

    if (linha == null) {
      return {'aluno': null, 'fichas': <Map<String, dynamic>>[]};
    }
    final id = linha['id'] as String;

    final (fichas, plano, feitas, avaliacoes, personal, pesos) = await (
      FichaService.fichasDoAluno(id),
      _talvez(DietaService.planoAtivo(id)),
      _talvez(DietaService.refeicoesFeitas(alunoId: id, dia: DateTime.now())),
      _talvez(AvaliacaoService.listar(id)),
      _talvez(ProfileService.doPersonal(linha['personal_id'] as String)),
      _talvez(DiarioService.pesos(id)),
    ).wait;

    return {
      'aluno': linha,
      'fichas': fichas,
      'plano': plano,
      'feitas': feitas,
      'avaliacoes': avaliacoes,
      'personal': personal,
      'pesos': pesos,
    };
  }

  /// Dieta, avaliação e personal são complemento do treino: se um deles
  /// falhar, a home abre sem aquele cartão em vez de virar tela de erro.
  static Future<T?> _talvez<T>(Future<T> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }

  void _checarAnamnese() {
    final a = _aluno;
    if (a == null) return;
    final tipo = a['anamnese_tipo'] as String? ?? 'nenhuma';
    final preenchida = a['anamnese_preenchida'] as bool? ?? false;
    if (tipo == 'nenhuma' || preenchida) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AlunoAnamneseScreen(
          tipo: tipo,
          alunoId: a['id'] as String,
        ),
      ));
      // Recarrega ao fechar: `_aluno` em memória ainda diz que a anamnese
      // está pendente, e sem reler o banco a home ficaria com o estado
      // velho até o próximo abrir do app.
      if (mounted) await _carregar();
    });
  }

  // ── Contas da semana ────────────────────────────────────────

  bool _temTreinoNoDia(int dia) => _fichas.any((f) {
        final dias = f['dias_semana'];
        return dias == null || (dias as List).isEmpty || dias.contains(dia);
      });

  /// Fichas de um dia. Ficha sem dia marcado vale para todo dia — é o
  /// padrão de quem treina sem rotina fixa.
  List<Map<String, dynamic>> _fichasDoDia(int dia) => _fichas.where((f) {
        final dias = f['dias_semana'];
        if (dias == null || (dias as List).isEmpty) return true;
        return dias.contains(dia);
      }).toList();

  bool _feita(Map<String, dynamic> f) {
    final id = (f['fichas'] as Map?)?['id'] as String?;
    return id != null && (_feitoPorDia[_dia]?.contains(id) ?? false);
  }

  /// Quantos dias de treino a semana pede. Ficha sem dia fixo não diz
  /// quantos dias são — aí a meta é 3, o mínimo que dá resultado.
  int get _metaSemana {
    if (_fichas.isEmpty) return 0;
    final semDia = _fichas.any((f) {
      final d = f['dias_semana'];
      return d == null || (d as List).isEmpty;
    });
    if (semDia) return 3;
    return [for (var i = 0; i < 7; i++) i].where(_temTreinoNoDia).length;
  }

  int get _diasTreinadosNaSemana =>
      _feitoPorDia.values.where((s) => s.isNotEmpty).length;

  DateTime get _segunda {
    final hoje = Datas.dia(DateTime.now());
    return hoje.subtract(Duration(days: hoje.weekday - 1));
  }

  /// Semanas seguidas com pelo menos um treino. A semana corrente só conta
  /// se já teve treino — mas também não quebra a sequência enquanto não
  /// acabou: quarta-feira sem treino ainda não é semana perdida.
  int get _sequenciaSemanas {
    final semanas = {
      for (final e in _execucoes)
        Datas.dia(e.quando).subtract(Duration(days: e.quando.weekday - 1)),
    };
    var semana = _segunda;
    if (!semanas.contains(semana)) {
      semana = semana.subtract(const Duration(days: 7));
    }
    var n = 0;
    while (semanas.contains(semana)) {
      n++;
      semana = semana.subtract(const Duration(days: 7));
    }
    return n;
  }

  int get _treinosNoMes {
    final agora = DateTime.now();
    return _execucoes
        .where(
            (e) => e.quando.year == agora.year && e.quando.month == agora.month)
        .length;
  }

  int get _minutosNaSemana => _execucoes
      .where((e) => !e.quando.isBefore(_segunda))
      .fold(0, (s, e) => s + e.minutos);

  // ── Tela ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final nome = (_perfil?['nome'] as String?)?.trim();
    final primeiro =
        (nome == null || nome.isEmpty) ? null : nome.split(' ').first;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _carregando
            ? Center(child: CircularProgressIndicator(color: AppColors.accent))
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
                        const SizedBox(height: AppSpacing.xl),
                        if (_aluno == null)
                          _naoVinculado()
                        else ...[
                          _semana(),
                          const SizedBox(height: AppSpacing.md),
                          _treinoDoDia(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl, AppSpacing.md, AppSpacing.xl, 0,
                            ),
                            child: CartaoConsulta(
                              key: ValueKey('consulta$_versao'),
                              alunoId: _aluno!['id'] as String,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _numeros(),
                          if (_plano != null && !_plano!.vazio) ...[
                            const SizedBox(height: AppSpacing.md),
                            _dieta(_plano!),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          Padding(
                            padding: AppSpacing.screen,
                            child: CartaoAgua(
                              key: ValueKey(_versao),
                              alunoId: _aluno!['id'] as String,
                              dia: Datas.dia(DateTime.now()),
                              metaMl: DiarioService.metaAgua(
                                metaDoPlano: _plano?.aguaMl,
                                pesoKg: _seriePeso.lastOrNull?.peso,
                              ),
                              compacto: true,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.xl,
                              AppSpacing.md,
                              AppSpacing.xl,
                              0,
                            ),
                            child: MetasDoAluno(
                              key: ValueKey('metas$_versao'),
                              alunoId: _aluno!['id'] as String,
                              somenteAbertas: true,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _corpo(),
                          const SizedBox(height: AppSpacing.md),
                          _atalhos(),
                          if (_historico.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxl),
                            _historicoRecente(),
                          ],
                          if (_personal != null) ...[
                            const SizedBox(height: AppSpacing.xxl),
                            _cartaoPersonal(_personal!),
                          ],
                        ],
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _cabecalho(String? primeiroNome) {
    final agora = DateTime.now();
    final hora = agora.hour;
    final saudacao = hora < 12
        ? 'Bom dia'
        : hora < 18
            ? 'Boa tarde'
            : 'Boa noite';
    final data =
        '${_nomesDia[agora.weekday % 7]}, ${agora.day} de ${_meses[agora.month - 1]}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(data.toUpperCase(), style: AppText.label()),
                const SizedBox(height: 6),
                Text(
                  primeiroNome == null ? saudacao : '$saudacao, $primeiroNome',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(26),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (_aluno != null && _personal != null && _recursos.chat) ...[
            BotaoMensagens(aoAbrir: (_) => _abrirChat()),
            const SizedBox(width: AppSpacing.sm),
          ],
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AlunoPerfilConfigScreen()),
            ),
            child: PhdAvatar(
              name: primeiroNome ?? 'A',
              imageUrl: _perfil?['avatar_url'] as String?,
              size: 44,
            ),
          ),
        ],
      ),
    );
  }

  Widget _naoVinculado() {
    return Padding(
      padding: AppSpacing.screen,
      child: PhdCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.link_off_rounded,
                size: 24, color: AppColors.warningText),
            const SizedBox(height: AppSpacing.md),
            Text('Conta ainda não vinculada', style: AppText.title(17)),
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

  // ── Semana ──────────────────────────────────────────────────

  /// A semana começa na segunda, igual à contagem de `concluidosDaSemana`.
  /// Começar no domingo mostrava o domingo que ainda vai chegar como se
  /// fosse o primeiro dia — e o check dele aparecia no lugar errado.
  Widget _semana() {
    const ordem = [1, 2, 3, 4, 5, 6, 0];
    final meta = _metaSemana;
    final feitos = _diasTreinadosNaSemana;

    return Padding(
      padding: AppSpacing.screen,
      child: PhdCard(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: Text('SUA SEMANA', style: AppText.label())),
                  if (meta > 0)
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '$feitos',
                          style: AppText.number(15,
                              color: AppColors.accent, weight: FontWeight.w800),
                        ),
                        TextSpan(
                          text: ' / $meta treinos',
                          style: AppText.caption(12.5),
                        ),
                      ]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                for (final i in ordem) Expanded(child: _diaDaSemana(i)),
              ],
            ),
            if (meta > 0) ...[
              const SizedBox(height: AppSpacing.md),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: PhdProgressBar(value: feitos / meta, height: 5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _diaDaSemana(int i) {
    const letras = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    final data = _segunda.add(Duration(days: (i + 6) % 7));
    final selecionado = i == _dia;
    final ehHoje = i == _hoje;
    final treinou = (_feitoPorDia[i] ?? const {}).isNotEmpty;
    final temTreino = _temTreinoNoDia(i);

    final Color fundo;
    final Color texto;
    final Border? borda;
    if (treinou) {
      fundo = AppColors.accent;
      texto = AppColors.onAccent;
      borda = null;
    } else if (ehHoje) {
      fundo = Colors.transparent;
      texto = AppColors.textPrimary;
      borda = Border.all(color: AppColors.accent, width: 1.6);
    } else if (temTreino) {
      fundo = Colors.transparent;
      texto = AppColors.textPrimary;
      borda = Border.all(color: AppColors.lineStrong, width: 1.2);
    } else {
      fundo = Colors.transparent;
      texto = AppColors.textMuted;
      borda = null;
    }

    return Semantics(
      button: true,
      selected: selecionado,
      label: '${_nomesDia[i]}${treinou ? ', treino feito' : ''}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _dia = i),
        child: AnimatedContainer(
          duration: AppDuration.fast,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selecionado ? AppColors.surfaceHigh : Colors.transparent,
            borderRadius: AppRadius.rMd,
          ),
          child: Column(
            children: [
              Text(
                letras[i],
                style: AppText.bodyStrong(
                  11.5,
                  color: ehHoje ? AppColors.accent : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fundo,
                  shape: BoxShape.circle,
                  border: borda,
                ),
                child: treinou
                    ? Icon(Icons.check_rounded,
                        size: 18, color: AppColors.onAccent)
                    : Text('${data.day}',
                        style: AppText.number(13.5, color: texto)),
              ),
              const SizedBox(height: 5),
              // Ponto de "tem treino": some quando o dia já tem o check,
              // que diz mais.
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: temTreino && !treinou
                      ? AppColors.textMuted
                      : Colors.transparent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Treino do dia ───────────────────────────────────────────

  Widget _treinoDoDia() {
    final lista = _fichasDoDia(_dia);
    if (lista.isEmpty) return _descanso();

    // O que falta fazer vem primeiro: é ele que ganha o cartão grande.
    lista.sort((a, b) => (_feita(a) ? 1 : 0).compareTo(_feita(b) ? 1 : 0));

    return Column(
      children: [
        _destaque(lista.first),
        for (final f in lista.skip(1))
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              0,
            ),
            child: _cartaoCompacto(f),
          ),
      ],
    );
  }

  String get _rotuloDia => _dia == _hoje
      ? 'TREINO DE HOJE'
      : 'TREINO DE ${_nomesDia[_dia].toUpperCase()}';

  /// O cartão que vende o treino. Volt cheio enquanto há o que fazer;
  /// depois de feito, recolhe para a superfície escura com o check — a cor
  /// forte fica reservada para o que ainda pede ação.
  Widget _destaque(Map<String, dynamic> f) {
    final ficha = (f['fichas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final nome = ficha['nome'] as String? ?? 'Treino';
    final qtd = (f['qtd_exercicios'] as num?)?.toInt() ?? 0;
    final series = (f['qtd_series'] as num?)?.toInt() ?? 0;
    final minutos = (f['minutos_estimados'] as num?)?.toInt() ?? 0;
    final grupos = (f['grupos'] as List?)?.cast<String>() ?? const [];
    final feita = _feita(f);
    final vazia = qtd == 0;

    final fg = feita ? AppColors.textPrimary : AppColors.onAccent;
    final suave = fg.withValues(alpha: feita ? 0.6 : 0.62);

    return Padding(
      padding: AppSpacing.screen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: feita
                  ? [AppColors.surfaceHigh, AppColors.surface]
                  : [
                      AppColors.primaryLight,
                      AppColors.accent,
                      AppColors.primaryDark
                    ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -28,
                top: -22,
                child: Transform.rotate(
                  angle: -0.45,
                  child: Icon(
                    feita
                        ? Icons.verified_rounded
                        : Icons.fitness_center_rounded,
                    size: 170,
                    color: fg.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(_rotuloDia,
                                style: AppText.label(color: suave))),
                        if (feita)
                          const PhdStatusChip(
                              label: 'Concluído', tone: PhdTone.success),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      nome,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(28, color: fg),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (vazia)
                      Text(
                        'Seu personal ainda está montando este treino.',
                        style: AppText.body(13.5, color: suave),
                      )
                    else
                      Wrap(
                        spacing: AppSpacing.lg,
                        runSpacing: AppSpacing.xs,
                        children: [
                          _info(
                              Icons.format_list_bulleted_rounded,
                              '$qtd ${qtd == 1 ? 'exercício' : 'exercícios'}',
                              suave),
                          if (minutos > 0)
                            _info(
                                Icons.schedule_rounded, '~$minutos min', suave),
                          if (series > 0)
                            _info(
                                Icons.repeat_rounded, '$series séries', suave),
                        ],
                      ),
                    if (grupos.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final g in grupos.take(4))
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: fg.withValues(alpha: 0.09),
                                borderRadius: AppRadius.rPill,
                              ),
                              child: Text(g,
                                  style: AppText.bodyStrong(12, color: fg)),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    _botaoTreino(
                      feita: feita,
                      // Treino vazio não tem o que executar: deixar o botão
                      // ativo só levaria a uma tela em branco na academia.
                      onTap: vazia ? null : () => _escolherModo(ficha),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _info(IconData icone, String texto, Color cor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 15, color: cor),
        const SizedBox(width: 5),
        Text(texto, style: AppText.bodyStrong(13, color: cor)),
      ],
    );
  }

  /// Botão branco sobre o azul. O `PhdButton` primário é azul — sobre o
  /// cartão azul ele sumiria.
  Widget _botaoTreino({required bool feita, VoidCallback? onTap}) {
    final ativo = onTap != null;
    final bg = feita ? Colors.transparent : Colors.white;

    return SizedBox(
      height: 54,
      width: double.infinity,
      child: Material(
        color: ativo ? bg : AppColors.onAccent.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.rLg,
          side:
              feita ? BorderSide(color: AppColors.lineStrong) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: feita ? AppColors.surfaceHigh : AppColors.accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  feita ? Icons.replay_rounded : Icons.play_arrow_rounded,
                  size: 17,
                  color: feita ? AppColors.textPrimary : AppColors.onAccent,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                feita ? 'Treinar de novo' : 'Começar treino',
                style: AppText.bodyStrong(
                  15,
                  color: !ativo
                      ? AppColors.onAccent.withValues(alpha: 0.7)
                      : feita
                          ? AppColors.textPrimary
                          : AppColors.primaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cartaoCompacto(Map<String, dynamic> f) {
    final ficha = (f['fichas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final nome = ficha['nome'] as String? ?? 'Treino';
    final qtd = (f['qtd_exercicios'] as num?)?.toInt() ?? 0;
    final minutos = (f['minutos_estimados'] as num?)?.toInt() ?? 0;
    final feita = _feita(f);

    return PhdCard(
      onTap: qtd == 0 ? null : () => _escolherModo(ficha),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          _icone(
            feita ? Icons.check_rounded : Icons.fitness_center_rounded,
            feita ? AppColors.success : AppColors.accent,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong(14)),
                Text(
                  [
                    '$qtd ${qtd == 1 ? 'exercício' : 'exercícios'}',
                    if (minutos > 0) '~$minutos min',
                  ].join(' · '),
                  style: AppText.caption(12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  /// Dia sem treino. Não é tela vazia: diz por que descansar e mostra o
  /// próximo treino — quem abre o app no domingo sai sabendo o de segunda.
  Widget _descanso() {
    if (_fichas.isEmpty) {
      final zap = linkWhatsApp(_personal?['whatsapp'] as String?);
      return Padding(
        padding: AppSpacing.screen,
        child: PhdCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _icone(Icons.hourglass_top_rounded, AppColors.accent,
                  tamanho: 44),
              const SizedBox(height: AppSpacing.lg),
              Text('Seu treino está a caminho', style: AppText.title(19)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Assim que seu personal montar sua ficha, ela aparece aqui '
                'com tudo o que você precisa para treinar.',
                style: AppText.body(13.5, color: AppColors.textSecondary),
              ),
              if (zap != null) ...[
                const SizedBox(height: AppSpacing.lg),
                PhdButton(
                  label: 'Falar com meu personal',
                  icon: Icons.chat_rounded,
                  variant: PhdButtonVariant.ghost,
                  onPressed: () => _abrir(zap),
                ),
              ],
            ],
          ),
        ),
      );
    }

    const dicas = [
      'O músculo cresce na recuperação. Durma de 7 a 9 horas hoje.',
      'Hidratação também é treino: leve a garrafinha com você.',
      'Uma caminhada leve de 20 minutos acelera a recuperação.',
      '10 minutos de alongamento antes de dormir soltam o corpo.',
      'Capriche na proteína hoje: é ela que reconstrói o músculo.',
    ];
    final dica =
        dicas[DateTime.now().difference(DateTime(2026)).inDays % dicas.length];
    final proximo = _proximoTreino();

    return Padding(
      padding: AppSpacing.screen,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.surfaceHigh, AppColors.surface],
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _icone(Icons.bedtime_rounded, _corDescanso, tamanho: 44),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _dia == _hoje
                              ? 'HOJE'
                              : _nomesDia[_dia].toUpperCase(),
                          style: AppText.label(),
                        ),
                        const SizedBox(height: 2),
                        Text('Dia de descanso', style: AppText.title(20)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(dica,
                  style: AppText.body(14, color: AppColors.textSecondary)),
              if (proximo != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Material(
                  color: AppColors.bg.withValues(alpha: 0.45),
                  borderRadius: AppRadius.rLg,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => _dia = proximo.dia),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          _icone(
                              Icons.fitness_center_rounded, AppColors.accent),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'PRÓXIMO TREINO · ${_nomesDia[proximo.dia].toUpperCase()}',
                                    style:
                                        AppText.label(color: AppColors.accent)),
                                const SizedBox(height: 3),
                                Text(proximo.nome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.bodyStrong(14.5)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ({int dia, String nome})? _proximoTreino() {
    for (var i = 1; i <= 7; i++) {
      final d = (_dia + i) % 7;
      final lista = _fichasDoDia(d);
      if (lista.isEmpty) continue;
      final nome =
          (lista.first['fichas'] as Map?)?['nome'] as String? ?? 'Treino';
      return (dia: d, nome: nome);
    }
    return null;
  }

  // ── Números ─────────────────────────────────────────────────

  Widget _numeros() {
    final seq = _sequenciaSemanas;
    final min = _minutosNaSemana;

    return Padding(
      padding: AppSpacing.screen,
      child: Row(
        children: [
          Expanded(
            child: _numero(
              icone: Icons.local_fire_department_rounded,
              cor: AppColors.energy,
              valor: '$seq',
              legenda: seq == 1 ? 'semana seguida' : 'semanas seguidas',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _numero(
              icone: Icons.event_available_rounded,
              cor: AppColors.accent,
              valor: '$_treinosNoMes',
              legenda: 'treinos no mês',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _numero(
              icone: Icons.timer_outlined,
              cor: _corProteina,
              valor: _duracao(min).isEmpty ? '0' : _duracao(min),
              legenda: 'nesta semana',
            ),
          ),
        ],
      ),
    );
  }

  Widget _numero({
    required IconData icone,
    required Color cor,
    required String valor,
    required String legenda,
  }) {
    return PhdCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: cor),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child:
                Text(valor, style: AppText.number(24, weight: FontWeight.w800)),
          ),
          Text(legenda,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(11.5)),
        ],
      ),
    );
  }

  // ── Dieta ───────────────────────────────────────────────────

  Widget _dieta(PlanoAlimentar p) {
    final refeicoes = p.refeicoes.where((r) => !r.vazia).toList();
    var kcal = 0.0, pr = 0.0, c = 0.0, g = 0.0;
    for (final r in refeicoes) {
      if (!_refeicoesFeitas.contains(r.id)) continue;
      final t = r.total;
      kcal += t.kcal;
      pr += t.proteina;
      c += t.carboidrato;
      g += t.gordura;
    }
    final prescrito = p.totalPrescrito;
    final metaKcal = p.metaKcal ?? prescrito.kcal;
    final feitas =
        refeicoes.where((r) => _refeicoesFeitas.contains(r.id)).length;
    final proxima =
        refeicoes.where((r) => !_refeicoesFeitas.contains(r.id)).firstOrNull;

    return Padding(
      padding: AppSpacing.screen,
      child: PhdCard(
        onTap: _abrirDieta,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloCartao(
                'DIETA DE HOJE', '$feitas de ${refeicoes.length} refeições'),
            const SizedBox(height: AppSpacing.lg),
            // Sem números de caloria para quem o profissional decidiu que
            // não deve contar: o progresso vira refeições cumpridas.
            if (!_recursos.nutricional)
              PhdSegments(total: refeicoes.length, filled: feitas, height: 8)
            else
              Row(
                children: [
                  PhdRing(
                    valor: proporcao(kcal, metaKcal),
                    tamanho: 100,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${kcal.round()}',
                            style: AppText.number(21, weight: FontWeight.w800)),
                        Text('de ${metaKcal.round()} kcal',
                            style: AppText.caption(10.5,
                                color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xl),
                  Expanded(
                    child: Column(
                      children: [
                        _macro('Proteína', pr,
                            p.metaProteina ?? prescrito.proteina, _corProteina),
                        const SizedBox(height: AppSpacing.md),
                        _macro(
                            'Carboidrato',
                            c,
                            p.metaCarboidrato ?? prescrito.carboidrato,
                            _corCarbo),
                        const SizedBox(height: AppSpacing.md),
                        _macro('Gordura', g, p.metaGordura ?? prescrito.gordura,
                            _corGordura),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: AppRadius.rLg,
              ),
              child: Row(
                children: [
                  Icon(
                    proxima == null
                        ? Icons.celebration_rounded
                        : Icons.restaurant_rounded,
                    size: 18,
                    color: AppColors.accent,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: proxima == null
                        ? Text('Todas as refeições de hoje feitas. Mandou bem!',
                            style: AppText.bodyStrong(13))
                        : Text.rich(
                            TextSpan(children: [
                              TextSpan(
                                text: 'Próxima: ',
                                style: AppText.caption(13),
                              ),
                              TextSpan(
                                text: [
                                  proxima.nome,
                                  if (proxima.horarioTexto != null)
                                    proxima.horarioTexto!
                                ].join(' · '),
                                style: AppText.bodyStrong(13),
                              ),
                            ]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 20, color: AppColors.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _macro(String nome, double consumido, double meta, Color cor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(nome, style: AppText.caption(12))),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: '${consumido.round()}', style: AppText.number(12.5)),
              TextSpan(
                text: ' / ${meta.round()} g',
                style: AppText.caption(11.5, color: AppColors.textMuted),
              ),
            ])),
          ],
        ),
        const SizedBox(height: 5),
        PhdProgressBar(
            value: proporcao(consumido, meta), height: 6, color: cor),
      ],
    );
  }

  Future<void> _abrirDieta() async {
    final id = _aluno?['id']?.toString();
    if (id == null) return;
    await context.push('/aluno/dieta', extra: {'alunoId': id});
    if (mounted) _carregar();
  }

  // ── Corpo ───────────────────────────────────────────────────

  /// Peso ao longo do tempo: o das avaliações e o que o aluno anotou em
  /// casa, juntos e por data. No mesmo dia, a pesagem de casa vence — é a
  /// mais recente que o aluno conhece.
  List<({DateTime data, double peso})> get _seriePeso {
    final porDia = <DateTime, double>{
      for (final s in _avaliacoes)
        if (s.peso != null) Datas.dia(s.sessao.data): s.peso!,
    };
    for (final p in _pesos) {
      porDia[Datas.dia(p.data)] = p.pesoKg;
    }
    final lista = [for (final e in porDia.entries) (data: e.key, peso: e.value)]
      ..sort((a, b) => a.data.compareTo(b.data));
    return lista;
  }

  Future<void> _registrarPeso() async {
    final id = _aluno?['id'] as String?;
    if (id == null) return;
    final salvo = await registrarPeso(context,
        alunoId: id, ultimo: _seriePeso.lastOrNull?.peso);
    if (salvo != null && mounted) _carregar();
  }

  Widget _corpo() {
    final serie = _seriePeso;
    final atual = serie.lastOrNull;
    final anterior = serie.length >= 2 ? serie[serie.length - 2] : null;

    // Gordura só vem de avaliação, e compara com a avaliação anterior que
    // mediu gordura — uma sessão só de flexibilidade não conta.
    final ultAval = _avaliacoes.firstOrNull;
    final gordAnt = _avaliacoes
        .skip(1)
        .map((s) => s.percGordura)
        .whereType<double>()
        .firstOrNull;
    final proxima = ultAval?.sessao.proximaAvaliacao;

    return Padding(
      padding: AppSpacing.screen,
      child: PhdCard(
        onTap: _avaliacoes.isEmpty
            ? _registrarPeso
            : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const AlunoAvaliacoesScreen()),
                ),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tituloCartao(
              'SEU CORPO',
              atual == null
                  ? 'Sem registros ainda'
                  : 'Peso de ${Datas.longa(atual.data)}',
            ),
            const SizedBox(height: AppSpacing.lg),
            if (atual == null && ultAval?.percGordura == null)
              Text(
                'Registre seu peso uma vez por semana para ver a evolução aqui.',
                style: AppText.body(13.5, color: AppColors.textSecondary),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (atual != null)
                    Expanded(
                      child: _medida(
                        'Peso',
                        _n(atual.peso),
                        'kg',
                        anterior == null ? null : atual.peso - anterior.peso,
                        // Peso subir ou descer não é bom nem ruim sozinho:
                        // depende do objetivo. Fica neutro.
                        bomQuandoDesce: null,
                      ),
                    ),
                  if (ultAval?.percGordura != null)
                    Expanded(
                      child: _medida(
                        'Gordura',
                        _n(ultAval!.percGordura!),
                        '%',
                        gordAnt == null ? null : ultAval.percGordura! - gordAnt,
                        bomQuandoDesce: true,
                      ),
                    ),
                ],
              ),
            if (serie.length >= 2) ...[
              const SizedBox(height: AppSpacing.lg),
              PhdSparkline(valores: [for (final p in serie) p.peso]),
            ],
            if (proxima != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Icon(Icons.event_rounded,
                      size: 15, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(_textoProximaAvaliacao(proxima),
                      style: AppText.caption(12)),
                ],
              ),
            ],
            if (_recursos.peso) ...[
              const SizedBox(height: AppSpacing.md),
              PhdButton(
                label: 'Registrar peso',
                icon: Icons.monitor_weight_outlined,
                variant: PhdButtonVariant.ghost,
                size: PhdButtonSize.medium,
                onPressed: _registrarPeso,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _medida(
    String rotulo,
    String valor,
    String unidade,
    double? delta, {
    required bool? bomQuandoDesce,
  }) {
    Color cor = AppColors.textSecondary;
    if (delta != null && bomQuandoDesce != null && delta.abs() >= 0.05) {
      final melhorou = (delta < 0) == bomQuandoDesce;
      cor = melhorou ? AppColors.successText : AppColors.warningText;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rotulo.toUpperCase(), style: AppText.label()),
        const SizedBox(height: 5),
        Text.rich(TextSpan(children: [
          TextSpan(
              text: valor, style: AppText.number(26, weight: FontWeight.w800)),
          TextSpan(text: ' $unidade', style: AppText.caption(13)),
        ])),
        if (delta != null && delta.abs() >= 0.05) ...[
          const SizedBox(height: 3),
          Row(
            children: [
              Icon(
                delta < 0 ? Icons.south_east_rounded : Icons.north_east_rounded,
                size: 14,
                color: cor,
              ),
              const SizedBox(width: 3),
              Text('${_n(delta.abs())} $unidade',
                  style: AppText.bodyStrong(12, color: cor)),
            ],
          ),
        ],
      ],
    );
  }

  String _textoProximaAvaliacao(DateTime d) {
    final dias = Datas.dia(d).difference(Datas.dia(DateTime.now())).inDays;
    if (dias < 0) return 'Reavaliação pendente — combine com seu personal';
    if (dias == 0) return 'Reavaliação marcada para hoje';
    if (dias == 1) return 'Reavaliação amanhã';
    return 'Próxima avaliação em $dias dias';
  }

  /// `68,2` — uma casa, vírgula brasileira.
  String _n(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  // ── Atalhos ─────────────────────────────────────────────────

  Widget _atalhos() {
    return Padding(
      padding: AppSpacing.screen,
      child: Row(
        children: [
          Expanded(
            child: _atalho(
              icone: Icons.photo_camera_outlined,
              cor: _corDescanso,
              titulo: 'Fotos',
              legenda: 'Sua evolução',
              onTap: () => context.push('/aluno/progresso'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _atalho(
              icone: Icons.monitor_heart_outlined,
              cor: _corGordura,
              titulo: 'Avaliações',
              legenda: _avaliacoes.isEmpty
                  ? 'Nenhuma ainda'
                  : '${_avaliacoes.length} ${_avaliacoes.length == 1 ? 'registro' : 'registros'}',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AlunoAvaliacoesScreen()),
              ),
            ),
          ),
          // Sem plano não há cartão de dieta; o atalho segura o lugar para
          // o aluno saber que a função existe.
          if (_plano == null || _plano!.vazio) ...[
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _atalho(
                icone: Icons.restaurant_menu_rounded,
                cor: _corCarbo,
                titulo: 'Dieta',
                legenda: 'Sem plano ativo',
                onTap: _abrirDieta,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _atalho({
    required IconData icone,
    required Color cor,
    required String titulo,
    required String legenda,
    required VoidCallback onTap,
  }) {
    return PhdCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _icone(icone, cor),
          const SizedBox(height: AppSpacing.md),
          Text(titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyStrong(14)),
          Text(legenda,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(11.5)),
        ],
      ),
    );
  }

  // ── Histórico ───────────────────────────────────────────────

  Widget _historicoRecente() {
    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PhdSectionHeader(label: 'Últimos treinos'),
          const SizedBox(height: AppSpacing.md),
          PhdCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                for (final (i, h) in _historico.indexed) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.line),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Row(
                      children: [
                        _icone(Icons.check_rounded, AppColors.success,
                            tamanho: 34),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h['ficha_nome'] as String? ?? 'Treino',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.bodyStrong(13.5)),
                              Text(
                                [
                                  _quando(h['executado_em'] as String?),
                                  if ((h['total_exercicios'] as num?)
                                      case final n? when n > 0)
                                    '$n exercícios',
                                ].join(' · '),
                                style: AppText.caption(12),
                              ),
                            ],
                          ),
                        ),
                        Text(_duracao(h['duracao_minutos']),
                            style: AppText.number(13.5,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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

  // ── Personal ────────────────────────────────────────────────

  Widget _cartaoPersonal(Map<String, dynamic> p) {
    final nome = (p['nome'] as String?)?.trim();
    final cref = (p['cref'] as String?)?.trim();
    final zap = linkWhatsApp(p['whatsapp'] as String?);

    return Padding(
      padding: AppSpacing.screen,
      child: PhdCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            PhdAvatar(
              name: (nome == null || nome.isEmpty) ? 'P' : nome,
              imageUrl: p['avatar_url'] as String?,
              size: 46,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SEU PERSONAL', style: AppText.label()),
                  const SizedBox(height: 3),
                  Text(
                    (nome == null || nome.isEmpty) ? 'Personal' : nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong(14.5),
                  ),
                  if (cref != null && cref.isNotEmpty)
                    Text('CREF $cref', style: AppText.caption(11.5)),
                ],
              ),
            ),
            if (_recursos.chat) ...[
              Material(
                color: AppColors.tint(AppColors.accent),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _abrirChat,
                  child: SizedBox.square(
                    dimension: kMinTouch,
                    child: Icon(Icons.forum_rounded, size: 20, color: AppColors.accent),
                  ),
                ),
              ),
              if (zap != null) const SizedBox(width: AppSpacing.sm),
            ],
            if (zap != null)
              Material(
                color: AppColors.tint(AppColors.success),
                shape: const CircleBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _abrir(zap),
                  child: SizedBox.square(
                    dimension: kMinTouch,
                    child: Icon(Icons.chat_rounded,
                        size: 20, color: AppColors.successText),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirChat() async {
    final a = _aluno;
    final p = _personal;
    if (a == null || p == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          alunoId: a['id'] as String,
          titulo: (p['nome'] as String?)?.trim() ?? 'Seu personal',
          subtitulo: 'Seu personal',
          avatarUrl: p['avatar_url'] as String?,
        ),
      ),
    );
  }

  Future<void> _abrir(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui abrir o WhatsApp.')),
      );
    }
  }

  // ── Peças ───────────────────────────────────────────────────

  Widget _tituloCartao(String rotulo, String apoio) {
    return Row(
      children: [
        Text(rotulo, style: AppText.label()),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            apoio,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(width: 2),
        Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
      ],
    );
  }

  /// Ícone num quadrado com o fundo da própria cor — o mesmo vocabulário em
  /// todos os cartões da home.
  Widget _icone(IconData icone, Color cor, {double tamanho = 36}) {
    return Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(tamanho * 0.32),
      ),
      child: Icon(icone, size: tamanho * 0.52, color: cor),
    );
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
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
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
          Icon(Icons.chevron_right_rounded,
              size: 19, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
