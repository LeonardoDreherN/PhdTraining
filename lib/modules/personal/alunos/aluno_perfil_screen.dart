import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/aluno_detalhe_service.dart';
import '../../../core/services/aluno_service.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/utils/moeda.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../core/widgets/widgets.dart';
import '../agenda/agenda_screen.dart' show FolhaConsulta, StatusConsultaTom, quandoConsulta;
import '../mensagens/caixa_screen.dart' show abrirConversa;

const _diasLetra = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

/// O aluno, visto pelo personal: quem é, como está indo e o que fazer.
///
/// Uma página só, sem abas: as abas escondiam metade do aluno atrás de um
/// toque. A ordem é a da conversa com ele — rosto e atalhos de contato,
/// três números que dizem se está bem, a frequência, e depois cada área
/// (treino, nutrição, avaliação, consulta, mensalidade) com o resumo e o
/// caminho para mexer nela.
class AlunoPerfilScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  const AlunoPerfilScreen({super.key, required this.aluno});

  @override
  State<AlunoPerfilScreen> createState() => _AlunoPerfilScreenState();
}

class _AlunoPerfilScreenState extends State<AlunoPerfilScreen> {
  late Map<String, dynamic> _aluno = Map<String, dynamic>.from(widget.aluno);
  DetalheAluno _d = const DetalheAluno();
  bool _carregando = true;

  late final _notas = TextEditingController(text: _aluno['notas'] as String? ?? '');
  bool _salvandoNota = false;

  String get _id => _aluno['id'].toString();
  String get _nome => (_aluno['nome'] as String?)?.trim() ?? 'Aluno';
  String get _primeiroNome => _nome.split(' ').first;
  bool get _ativo => _aluno['ativo'] as bool? ?? true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final d = await AlunoDetalheService.carregar(_id);
    if (!mounted) return;
    setState(() {
      _d = d;
      _carregando = false;
    });
  }

  void _avisar(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg, style: AppText.body(13.5))));

  // ── Ações ───────────────────────────────────────────────────

  Future<void> _salvarNota() async {
    setState(() => _salvandoNota = true);
    try {
      await AlunoService.atualizar(_id, {'notas': _notas.text.trim()});
      _aluno['notas'] = _notas.text.trim();
      _avisar('Anotação salva.');
    } catch (e) {
      _avisar('Não consegui salvar: $e');
    } finally {
      if (mounted) setState(() => _salvandoNota = false);
    }
  }

  Future<void> _menu(String acao) async {
    switch (acao) {
      case 'editar':
        final novos = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          builder: (_) => _FolhaEditarAluno(aluno: _aluno),
        );
        if (novos != null && mounted) setState(() => _aluno = {..._aluno, ...novos});
      case 'status':
        try {
          await AlunoService.alterarStatus(_id, !_ativo);
          setState(() => _aluno['ativo'] = !_ativo);
          _avisar(_ativo ? 'Aluno reativado.' : 'Aluno inativado.');
        } catch (e) {
          _avisar('Não consegui alterar: $e');
        }
      case 'excluir':
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Excluir $_nome?', style: AppText.title(17)),
            content: Text(
              'Isso apaga também as avaliações, fotos de progresso e o histórico '
              'de treinos. Não dá para desfazer.\n\nSe a ideia é só parar de '
              'acompanhar, use "Inativar".',
              style: AppText.body(13.5, color: AppColors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancelar', style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text('Excluir', style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
              ),
            ],
          ),
        );
        if (ok != true) return;
        try {
          await AlunoService.deletar(_id);
          if (mounted) context.pop();
        } catch (e) {
          _avisar('Não consegui excluir: $e');
        }
    }
  }

  Future<void> _whatsapp() async {
    final uri = linkWhatsApp(_aluno['whatsapp'] as String?, mensagem: 'Oi $_primeiroNome, tudo bem?');
    if (uri == null) return _avisar('Este aluno não tem WhatsApp cadastrado.');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _mensagem() async {
    await abrirConversa(context, _aluno);
    _carregar();
  }

  Future<void> _agendar() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => FolhaConsulta(alunoId: _id, diaInicial: Datas.dia(DateTime.now())),
    );
    if (ok == true) _carregar();
  }

  Future<void> _atribuirFicha() async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _FolhaAtribuirFicha(
        alunoId: _id,
        jaTem: {for (final f in _d.fichas) (f['fichas'] as Map?)?['id'] as String?}.whereType<String>().toSet(),
      ),
    );
    if (ok == true) _carregar();
  }

  Future<void> _tirarFicha(Map<String, dynamic> f) async {
    final ficha = (f['fichas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tirar "${ficha['nome']}"?', style: AppText.title(17)),
        content: Text(
          'A ficha some do app de $_primeiroNome. Os treinos que ele já fez com ela continuam no histórico.',
          style: AppText.body(13.5, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Tirar', style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FichaService.desatribuirAluno(alunoId: _id, fichaId: ficha['id'] as String);
      _carregar();
    } catch (e) {
      _avisar('Não consegui tirar a ficha: $e');
    }
  }

  Future<void> _abrir(String rota) async {
    await context.push(rota, extra: _aluno);
    _carregar();
  }

  // ── Tela ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        actions: [
          PopupMenuButton<String>(
            color: AppColors.surfaceHigh,
            surfaceTintColor: Colors.transparent,
            tooltip: 'Opções do aluno',
            shape: RoundedRectangleBorder(borderRadius: AppRadius.rMd),
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textPrimary),
            onSelected: _menu,
            itemBuilder: (_) => [
              PopupMenuItem(value: 'editar', child: Text('Editar dados', style: AppText.body(14))),
              PopupMenuItem(
                value: 'status',
                child: Text(_ativo ? 'Inativar aluno' : 'Reativar aluno', style: AppText.body(14)),
              ),
              PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir aluno', style: AppText.body(14, color: AppColors.dangerText)),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        backgroundColor: AppColors.surface,
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge * 2),
          children: [
            _hero(),
            const SizedBox(height: AppSpacing.xl),
            _acoes(),
            const SizedBox(height: AppSpacing.xl),
            if (_carregando)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.huge),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _numeros(),
              const SizedBox(height: AppSpacing.xxl),
              _secao('Frequência · 5 semanas', _frequencia()),
              _secao('Treinos', _treinos(), acao: 'Atribuir', aoTocar: _atribuirFicha),
              _secao('Nutrição', _nutricao()),
              _secao('Avaliação física', _avaliacao()),
              _secao('Consulta', _consulta()),
              if (_d.cobrancas.isNotEmpty) _secao('Mensalidade', _mensalidade()),
              _secao('Fotos e arquivos', _fotosArquivos()),
              _secao('Dados', _dados(), acao: 'Editar', aoTocar: () => _menu('editar')),
              _secao('Anotações', _anotacoes()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _secao(String titulo, Widget corpo, {String? acao, VoidCallback? aoTocar}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PhdSectionHeader(label: titulo, trailing: acao, onTrailingTap: aoTocar),
          const SizedBox(height: AppSpacing.md),
          corpo,
        ],
      ),
    );
  }

  Widget _hero() {
    final nasc = Datas.ler(_aluno['data_nascimento']);
    final idade = Datas.idade(nasc);
    final recente = _d.ultimoTreino != null && DateTime.now().difference(_d.ultimoTreino!).inHours < 48;
    final linha = [
      if ((_aluno['grupo'] as String?)?.isNotEmpty ?? false) _aluno['grupo'] as String,
      if (idade != null) '$idade anos',
      if ((_aluno['genero'] as String?)?.isNotEmpty ?? false) _aluno['genero'] as String,
    ].join(' · ');

    return Column(
      children: [
        // A foto vem de `alunos.foto_url` — antes o perfil desenhava sempre
        // a inicial, mesmo com a foto ali do lado na lista.
        PhdAvatar(
          name: _nome,
          imageUrl: _aluno['foto_url'] as String?,
          size: 96,
          ringColor: recente ? AppColors.accent : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(_nome, textAlign: TextAlign.center, style: AppText.display(24)),
        if (linha.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(linha, textAlign: TextAlign.center, style: AppText.caption(13)),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            PhdStatusChip(label: _ativo ? 'Ativo' : 'Inativo', tone: _ativo ? PhdTone.success : PhdTone.neutral),
            if (_aluno['user_id'] == null) const PhdStatusChip(label: 'Ainda não entrou no app', tone: PhdTone.warning),
            if (!_carregando && _d.fichas.isEmpty && _ativo)
              const PhdStatusChip(label: 'Sem ficha', tone: PhdTone.danger),
          ],
        ),
      ],
    );
  }

  Widget _acoes() {
    final itens = [
      (Icons.chat_rounded, 'WhatsApp', _whatsapp, AppColors.success, 0),
      (Icons.forum_rounded, 'Mensagem', _mensagem, AppColors.accent, _d.naoLidas),
      (Icons.calendar_month_rounded, 'Agendar', _agendar, AppColors.accent, 0),
      (Icons.fitness_center_rounded, 'Ficha', _atribuirFicha, AppColors.accent, 0),
    ];
    return Row(
      children: [
        for (final (icone, rotulo, acao, cor, selo) in itens)
          Expanded(
            child: Semantics(
              button: true,
              label: rotulo,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: acao,
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Icon(icone, color: cor, size: 24),
                        ),
                        if (selo > 0)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.accent, borderRadius: AppRadius.rPill),
                              child: Text('$selo', style: AppText.bodyStrong(10.5, color: AppColors.onAccent)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(rotulo, style: AppText.bodyStrong(11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _numeros() {
    final adesao = _d.adesao;
    final peso = _d.pesoAtual;
    final ultimo = _d.ultimoTreino;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PhdCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (adesao == null)
                    Text('—', style: AppText.number(22, weight: FontWeight.w800))
                  else
                    PhdRing(
                      valor: adesao,
                      tamanho: 44,
                      espessura: 5,
                      cor: adesao >= 0.6 ? AppColors.success : adesao >= 0.3 ? AppColors.warning : AppColors.danger,
                      child: Text('${(adesao * 100).round()}%', style: AppText.number(11, weight: FontWeight.w800)),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Adesão', style: AppText.bodyStrong(12.5)),
                  Text('30 dias', style: AppText.caption(11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _numero(
              ultimo == null ? '—' : _haQuanto(ultimo),
              'Último treino',
              '${_d.treinos.where((t) => DateTime.now().difference(t).inDays < 30).length} em 30 dias',
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _numero(
              peso == null ? '—' : '${peso.peso.toStringAsFixed(1).replaceAll('.', ',')} kg',
              'Peso',
              peso == null ? 'sem registro' : 'em ${Datas.curta(peso.data).substring(0, 5)}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _numero(String valor, String rotulo, String apoio) => PhdCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(valor, style: AppText.number(20, weight: FontWeight.w800)),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(rotulo, style: AppText.bodyStrong(12.5)),
            Text(apoio, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(11)),
          ],
        ),
      );

  static String _haQuanto(DateTime d) {
    final dias = Datas.dia(DateTime.now()).difference(Datas.dia(d)).inDays;
    if (dias == 0) return 'Hoje';
    if (dias == 1) return 'Ontem';
    return 'Há $dias d';
  }

  /// Cinco semanas, segunda a domingo. Dia com treino ganha o check; dia
  /// passado sem treino fica apagado; hoje tem o contorno.
  Widget _frequencia() {
    final hoje = Datas.dia(DateTime.now());
    final segunda = hoje.subtract(Duration(days: hoje.weekday - 1));
    final inicio = segunda.subtract(const Duration(days: 28));
    final feitos = {for (final t in _d.treinos) Datas.dia(t)};
    final total30 = _d.treinos.where((t) => hoje.difference(Datas.dia(t)).inDays < 30).length;

    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              for (final l in const ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'])
                Expanded(child: Center(child: Text(l, style: AppText.caption(11, color: AppColors.textMuted)))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var semana = 0; semana < 5; semana++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  for (var d = 0; d < 7; d++)
                    Expanded(
                      child: Center(
                        child: _celula(inicio.add(Duration(days: semana * 7 + d)), hoje, feitos),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('$total30', style: AppText.number(16, weight: FontWeight.w800)),
              const SizedBox(width: 6),
              Text(total30 == 1 ? 'treino nos últimos 30 dias' : 'treinos nos últimos 30 dias',
                  style: AppText.caption(12.5)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _celula(DateTime dia, DateTime hoje, Set<DateTime> feitos) {
    final fez = feitos.contains(dia);
    final futuro = dia.isAfter(hoje);
    final ehHoje = dia == hoje;
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fez
            ? AppColors.accent
            : futuro
                ? Colors.transparent
                : AppColors.surfaceHigh,
        border: ehHoje && !fez ? Border.all(color: AppColors.accent, width: 1.5) : null,
      ),
      child: fez
          ? Icon(Icons.check_rounded, size: 16, color: AppColors.onAccent)
          : Text('${dia.day}',
              style: AppText.caption(10.5, color: futuro ? AppColors.lineStrong : AppColors.textMuted)),
    );
  }

  Widget _treinos() {
    if (_d.fichas.isEmpty) {
      return PhdAddCard(label: 'Atribuir uma ficha', icon: Icons.fitness_center_rounded, onTap: _atribuirFicha);
    }
    return Column(
      children: [
        for (final f in _d.fichas)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _cartaoFicha(f),
          ),
      ],
    );
  }

  Widget _cartaoFicha(Map<String, dynamic> f) {
    final ficha = (f['fichas'] as Map?)?.cast<String, dynamic>() ?? const {};
    final qtd = (f['qtd_exercicios'] as num?)?.toInt() ?? 0;
    final min = (f['minutos_estimados'] as num?)?.toInt() ?? 0;
    final dias = ((f['dias_semana'] as List?) ?? const []).cast<int>().toSet();

    return PhdCard(
      onTap: () => _abrirFicha(ficha),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.tint(AppColors.accent), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.fitness_center_rounded, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ficha['nome'] as String? ?? 'Ficha',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(14)),
                Text(
                  [
                    '$qtd ${qtd == 1 ? 'exercício' : 'exercícios'}',
                    if (min > 0) '~$min min',
                  ].join(' · '),
                  style: AppText.caption(12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    for (final i in const [1, 2, 3, 4, 5, 6, 0])
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(right: 3),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: dias.contains(i) ? AppColors.accent : AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(_diasLetra[i],
                            style: AppText.bodyStrong(10,
                                color: dias.contains(i) ? AppColors.onAccent : AppColors.textMuted)),
                      ),
                    if (dias.isEmpty)
                      Text('  sem dia fixo', style: AppText.caption(11, color: AppColors.textMuted)),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.surfaceHigh,
            tooltip: 'Opções da ficha',
            icon: Icon(Icons.more_vert_rounded, size: 19, color: AppColors.textMuted),
            onSelected: (v) => v == 'abrir' ? _abrirFicha(ficha) : _tirarFicha(f),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'abrir', child: Text('Abrir ficha', style: AppText.body(14))),
              PopupMenuItem(
                value: 'tirar',
                child: Text('Tirar do aluno', style: AppText.body(14, color: AppColors.dangerText)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFicha(Map<String, dynamic> ficha) async {
    if (ficha['id'] == null) return;
    await context.push('/fichas/detalhe', extra: ficha);
    _carregar();
  }

  Widget _linhaResumo({
    required IconData icone,
    required String titulo,
    required String apoio,
    Widget? direita,
    required VoidCallback onTap,
  }) {
    return PhdCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.tint(AppColors.accent), borderRadius: BorderRadius.circular(14)),
            child: Icon(icone, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(14)),
                Text(apoio, maxLines: 2, style: AppText.caption(12)),
              ],
            ),
          ),
          if (direita != null) ...[const SizedBox(width: AppSpacing.sm), direita],
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _nutricao() {
    final p = _d.plano;
    if (p == null) {
      return _linhaResumo(
        icone: Icons.restaurant_menu_rounded,
        titulo: 'Sem plano alimentar',
        apoio: 'Toque para montar o plano, as metas e acompanhar o diário.',
        onTap: () => _abrir('/alunos/dieta'),
      );
    }
    final kcal = p.metaKcal ?? p.totalPrescrito.kcal;
    return _linhaResumo(
      icone: Icons.restaurant_menu_rounded,
      titulo: p.nome,
      apoio: [
        '${kcal.round()} kcal',
        '${p.refeicoes.length} refeições',
        if (p.metaProteina != null) 'P ${p.metaProteina!.round()} g',
      ].join(' · '),
      direita: PhdStatusChip(
        label: p.assinado ? 'assinado' : 'não assinado',
        tone: p.assinado ? PhdTone.success : PhdTone.warning,
      ),
      onTap: () => _abrir('/alunos/dieta'),
    );
  }

  Widget _avaliacao() {
    final ult = _d.avaliacoes.firstOrNull;
    if (ult == null) {
      return _linhaResumo(
        icone: Icons.monitor_heart_outlined,
        titulo: 'Nenhuma avaliação',
        apoio: 'Composição corporal, testes, postural e anamnese.',
        onTap: () => _abrir('/alunos/avaliacao'),
      );
    }
    return _linhaResumo(
      icone: Icons.monitor_heart_outlined,
      titulo: 'Última em ${Datas.longa(ult.sessao.data)}',
      apoio: [
        if (ult.peso != null) '${ult.peso!.toStringAsFixed(1).replaceAll('.', ',')} kg',
        if (ult.percGordura != null) '${ult.percGordura!.toStringAsFixed(1).replaceAll('.', ',')}% gordura',
        '${_d.avaliacoes.length} ${_d.avaliacoes.length == 1 ? 'avaliação' : 'avaliações'}',
      ].join(' · '),
      onTap: () => _abrir('/alunos/avaliacao'),
    );
  }

  Widget _consulta() {
    final c = _d.proximaConsulta;
    if (c == null) {
      return PhdAddCard(label: 'Agendar consulta', icon: Icons.calendar_month_rounded, onTap: _agendar);
    }
    return _linhaResumo(
      icone: Icons.event_rounded,
      titulo: c.tipo.rotulo,
      apoio: [quandoConsulta(c), if (c.local != null) c.local!].join(' · '),
      direita: PhdStatusChip(label: c.status.rotulo, tone: c.status.tom),
      onTap: _agendar,
    );
  }

  Widget _mensalidade() {
    final c = _d.cobrancas.first;
    final status = c['status'] as String? ?? 'pendente';
    final venc = Datas.ler(c['vencimento']);
    final vencida = status == 'atrasado' ||
        (status == 'pendente' && venc != null && venc.isBefore(Datas.dia(DateTime.now())));
    final (rotulo, tom) = switch (status) {
      'pago' => ('Paga', PhdTone.success),
      _ when vencida => ('Atrasada', PhdTone.danger),
      'pendente' => ('Em aberto', PhdTone.warning),
      _ => (status, PhdTone.neutral),
    };
    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.tint(tom.solid), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.payments_rounded, color: tom.onDark, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(Moeda.formatar((c['valor_centavos'] as num?)?.toInt() ?? 0), style: AppText.number(16)),
                Text(venc == null ? 'Sem vencimento' : 'Vence em ${Datas.curta(venc)}', style: AppText.caption(12)),
              ],
            ),
          ),
          PhdStatusChip(label: rotulo, tone: tom),
        ],
      ),
    );
  }

  Widget _fotosArquivos() {
    return Row(
      children: [
        Expanded(
          child: _linhaResumoCompacta(
            Icons.photo_library_outlined,
            'Fotos',
            _d.fotos.isEmpty ? 'Nenhuma ainda' : '${_d.fotos.length} de progresso',
            () {
              if (_d.fotos.isEmpty) return _avisar('$_primeiroNome ainda não enviou fotos de progresso.');
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => _ProgressoSheet(fotos: _d.fotos),
              );
            },
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _linhaResumoCompacta(
            Icons.folder_outlined,
            'Arquivos',
            _d.arquivos == 0 ? 'Exames, laudos…' : '${_d.arquivos} ${_d.arquivos == 1 ? 'arquivo' : 'arquivos'}',
            () async {
              await context.push('/alunos/arquivos', extra: {'alunoId': _id, 'alunoNome': _nome});
              _carregar();
            },
          ),
        ),
      ],
    );
  }

  Widget _linhaResumoCompacta(IconData icone, String titulo, String apoio, VoidCallback onTap) => PhdCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: AppColors.accent, size: 22),
            const SizedBox(height: AppSpacing.sm),
            Text(titulo, style: AppText.bodyStrong(14)),
            Text(apoio, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(12)),
          ],
        ),
      );

  Widget _dados() {
    final nasc = Datas.ler(_aluno['data_nascimento']);
    final linhas = [
      ('E-mail', _aluno['email'] as String?),
      ('WhatsApp', _aluno['whatsapp'] as String?),
      ('Nascimento', nasc == null ? null : '${Datas.curta(nasc)} · ${Datas.idade(nasc)} anos'),
      ('Gênero', _aluno['genero'] as String?),
      ('Modalidade', _aluno['grupo'] as String?),
      ('Acesso ao app', _aluno['user_id'] == null ? 'Ainda não entrou' : 'Ativo'),
    ];
    return PhdCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          for (final (i, (rotulo, valor)) in linhas.indexed) ...[
            if (i > 0) Divider(height: 1, color: AppColors.line),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  Text(rotulo, style: AppText.caption(13)),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      (valor?.trim().isEmpty ?? true) ? '—' : valor!,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong(13.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _anotacoes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _notas,
          minLines: 3,
          maxLines: 8,
          textCapitalization: TextCapitalization.sentences,
          style: AppText.body(14),
          decoration: const InputDecoration(
            hintText: 'Objetivos, lesões, restrições, preferências…',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: PhdButton(
            label: 'Salvar anotação',
            size: PhdButtonSize.small,
            variant: PhdButtonVariant.ghost,
            expand: false,
            loading: _salvandoNota,
            onPressed: _salvarNota,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Editar dados
// ══════════════════════════════════════════════════════════════

/// Antes, "Editar dados do aluno" abria o formulário de CADASTRO — criava
/// outro aluno em vez de corrigir este. Aqui edita a linha existente.
/// O e-mail fica de fora: é o login do aluno, e trocar por aqui deixaria
/// o acesso dele apontando para o e-mail antigo.
class _FolhaEditarAluno extends StatefulWidget {
  const _FolhaEditarAluno({required this.aluno});

  final Map<String, dynamic> aluno;

  @override
  State<_FolhaEditarAluno> createState() => _FolhaEditarAlunoState();
}

class _FolhaEditarAlunoState extends State<_FolhaEditarAluno> {
  late final _nome = TextEditingController(text: widget.aluno['nome'] as String?);
  late final _whats = TextEditingController(text: widget.aluno['whatsapp'] as String?);
  late final _nasc = TextEditingController(
    text: Datas.ler(widget.aluno['data_nascimento']) == null
        ? ''
        : Datas.curta(Datas.ler(widget.aluno['data_nascimento'])!),
  );
  late String? _genero = widget.aluno['genero'] as String?;
  late String? _grupo = widget.aluno['grupo'] as String?;
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _nome.dispose();
    _whats.dispose();
    _nasc.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) return setState(() => _erro = 'O nome não pode ficar vazio.');
    String? nascimento;
    final t = _nasc.text.trim();
    if (t.isNotEmpty) {
      final p = t.split('/');
      final d = p.length == 3 ? DateTime.tryParse('${p[2]}-${p[1].padLeft(2, '0')}-${p[0].padLeft(2, '0')}') : null;
      if (d == null || d.isAfter(DateTime.now())) {
        return setState(() => _erro = 'Data de nascimento no formato dd/mm/aaaa.');
      }
      nascimento = Datas.iso(d);
    }
    final dados = {
      'nome': nome,
      'whatsapp': _whats.text.trim().isEmpty ? null : _whats.text.trim(),
      'data_nascimento': nascimento,
      'genero': _genero,
      'grupo': _grupo,
    };
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await AlunoService.atualizar(widget.aluno['id'].toString(), dados);
      if (mounted) Navigator.pop(context, dados);
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não consegui salvar: $e';
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Editar dados', style: AppText.title(19)),
            const SizedBox(height: AppSpacing.lg),
            PhdField(controller: _nome, label: 'Nome', textCapitalization: TextCapitalization.words),
            const SizedBox(height: AppSpacing.md),
            PhdField(controller: _whats, label: 'WhatsApp', hint: '(11) 98765-4321', keyboardType: TextInputType.phone),
            const SizedBox(height: AppSpacing.md),
            PhdField(controller: _nasc, label: 'Nascimento', hint: 'dd/mm/aaaa', keyboardType: TextInputType.datetime),
            const SizedBox(height: AppSpacing.md),
            Text('Gênero', style: AppText.caption(12.5)),
            const SizedBox(height: 7),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final g in const ['Masculino', 'Feminino', 'Outro'])
                  PhdFilterChip(label: g, selected: _genero == g, onTap: () => setState(() => _genero = g)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Modalidade', style: AppText.caption(12.5)),
            const SizedBox(height: 7),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final g in const ['Presencial', 'Online'])
                  PhdFilterChip(label: g, selected: _grupo == g, onTap: () => setState(() => _grupo = g)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('O e-mail é o login do aluno e não muda por aqui.',
                style: AppText.caption(12, color: AppColors.textMuted)),
            if (_erro != null) ...[
              const SizedBox(height: AppSpacing.md),
              PhdAviso(texto: _erro!),
            ],
            const SizedBox(height: AppSpacing.lg),
            PhdButton(label: 'Salvar', icon: Icons.check_rounded, loading: _salvando, onPressed: _salvar),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Atribuir ficha
// ══════════════════════════════════════════════════════════════

class _FolhaAtribuirFicha extends StatefulWidget {
  const _FolhaAtribuirFicha({required this.alunoId, required this.jaTem});

  final String alunoId;
  final Set<String> jaTem;

  @override
  State<_FolhaAtribuirFicha> createState() => _FolhaAtribuirFichaState();
}

class _FolhaAtribuirFichaState extends State<_FolhaAtribuirFicha> {
  List<Map<String, dynamic>>? _fichas;
  String? _escolhida;
  final _dias = <int>{};
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    FichaService.listar().then((f) {
      if (mounted) setState(() => _fichas = f);
    }).catchError((Object e) {
      if (mounted) setState(() => _erro = 'Não consegui carregar as fichas: $e');
    });
  }

  Future<void> _salvar() async {
    if (_escolhida == null) return setState(() => _erro = 'Escolha a ficha.');
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await FichaService.atribuirAluno(
        alunoId: widget.alunoId,
        fichaId: _escolhida!,
        diasSemana: _dias.toList()..sort(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _erro = 'Não consegui atribuir: $e';
          _salvando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fichas = _fichas;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
        children: [
          Text('Atribuir ficha', style: AppText.title(19)),
          const SizedBox(height: 4),
          Text('Escolha o treino e os dias da semana em que o aluno faz.', style: AppText.caption(13)),
          const SizedBox(height: AppSpacing.lg),
          if (fichas == null && _erro == null)
            const Center(child: CircularProgressIndicator())
          else if (fichas != null && fichas.isEmpty)
            Text('Você ainda não tem fichas. Crie uma na aba Treinos.', style: AppText.body(14))
          else if (fichas != null)
            for (final f in fichas)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PhdCard(
                  color: _escolhida == f['id'] ? AppColors.tint(AppColors.accent) : AppColors.surfaceHigh,
                  onTap: () => setState(() => _escolhida = f['id'] as String),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Icon(
                        _escolhida == f['id'] ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: _escolhida == f['id'] ? AppColors.accent : AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: Text(f['nome'] as String? ?? 'Ficha', style: AppText.bodyStrong(14))),
                      if (widget.jaTem.contains(f['id']))
                        const PhdStatusChip(label: 'já atribuída', tone: PhdTone.neutral),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: AppSpacing.md),
          Text('DIAS DA SEMANA', style: AppText.label()),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (final i in const [1, 2, 3, 4, 5, 6, 0])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: GestureDetector(
                      onTap: () => setState(() => _dias.contains(i) ? _dias.remove(i) : _dias.add(i)),
                      child: AnimatedContainer(
                        duration: AppDuration.fast,
                        height: kMinTouch,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _dias.contains(i) ? AppColors.accent : AppColors.surfaceHigh,
                          borderRadius: AppRadius.rMd,
                        ),
                        child: Text(_diasLetra[i],
                            style: AppText.bodyStrong(14,
                                color: _dias.contains(i) ? AppColors.onAccent : AppColors.textSecondary)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Sem dia marcado, a ficha aparece todos os dias para o aluno.',
              style: AppText.caption(12, color: AppColors.textMuted)),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.md),
            PhdAviso(texto: _erro!),
          ],
          const SizedBox(height: AppSpacing.lg),
          PhdButton(label: 'Atribuir', icon: Icons.check_rounded, loading: _salvando, onPressed: _salvar),
        ],
      ),
    );
  }
}

// Sheet de progresso do aluno (read-only)
class _ProgressoSheet extends StatelessWidget {
  final List<Map<String, dynamic>> fotos;
  const _ProgressoSheet({required this.fotos});

  static const _meses = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Progresso do aluno',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: fotos.length,
                itemBuilder: (_, i) {
                  final foto = fotos[i];
                  final dt = DateTime.parse(foto['registrado_em']).toLocal();
                  final data = '${dt.day} ${_meses[dt.month - 1]} ${dt.year}';
                  return GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.black,
                        insetPadding: EdgeInsets.zero,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: SizedBox.expand(
                            child: InteractiveViewer(
                              child: Image.network(foto['foto_url'],
                                  fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(foto['foto_url'], fit: BoxFit.cover),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.8),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Text(data,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
