import 'package:flutter/material.dart';

import '../../../core/models/periodizacao.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/services/periodizacao_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';

const _diasLetra = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];

String _semException(Object e) => '$e'.replaceFirst('Exception: ', '');

/// O que vale e o que vem: a etapa atual e a próxima, para o perfil do
/// aluno. Toca e abre a periodização inteira.
class ResumoPeriodizacao extends StatelessWidget {
  const ResumoPeriodizacao({super.key, required this.etapas, required this.onAbrir});

  final List<EtapaPeriodizacao> etapas;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    if (etapas.isEmpty) {
      return PhdAddCard(
        label: 'Planejar a periodização',
        icon: Icons.event_note_rounded,
        onTap: onAbrir,
      );
    }
    final idAtual = EtapaPeriodizacao.idDaAtual(etapas);
    final atual = etapas.where((e) => e.id == idAtual).firstOrNull;
    final proxima = etapas.where((e) => e.momento(idAtual) == MomentoEtapa.proxima).firstOrNull;
    return PhdCard(
      onTap: onAbrir,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (atual != null) _linha('AGORA', atual),
          if (atual != null && proxima != null) ...[
            const SizedBox(height: AppSpacing.md),
            Divider(height: 1, color: AppColors.line),
            const SizedBox(height: AppSpacing.md),
          ],
          if (proxima != null) _linha('A PARTIR DE ${Datas.curta(proxima.dataInicio)}', proxima),
          if (atual == null && proxima == null)
            Text('Só etapas passadas. Programe a próxima.', style: AppText.caption(13)),
          if (atual != null && proxima == null && _terminou(atual)) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('A etapa atual terminou e não há próxima programada.',
                style: AppText.caption(12, color: AppColors.warningText)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text('Ver periodização completa', style: AppText.bodyStrong(12.5, color: AppColors.accent)),
        ],
      ),
    );
  }

  static bool _terminou(EtapaPeriodizacao e) =>
      e.dataFim != null && e.dataFim!.isBefore(Datas.dia(DateTime.now()));

  Widget _linha(String rotulo, EtapaPeriodizacao e) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(rotulo, style: AppText.label()),
          const SizedBox(height: 2),
          Text(e.nome, style: AppText.bodyStrong(14.5)),
          Text(
            [
              e.periodoTexto,
              if (e.objetivo != null) e.objetivo!,
              '${e.fichas.where((f) => f.estado != 'encerrada').length} fichas',
            ].join(' · '),
            style: AppText.caption(12),
          ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════
//  Linha do tempo
// ════════════════════════════════════════════════════════════════

/// A periodização do aluno: etapas anteriores, a atual e as próximas, em
/// ordem. É o diário de planejamento do profissional — o aluno não vê.
class PeriodizacaoScreen extends StatefulWidget {
  const PeriodizacaoScreen({super.key, required this.alunoId, required this.alunoNome});

  final String alunoId;
  final String alunoNome;

  @override
  State<PeriodizacaoScreen> createState() => _PeriodizacaoScreenState();
}

class _PeriodizacaoScreenState extends State<PeriodizacaoScreen> {
  List<EtapaPeriodizacao> _etapas = const [];
  bool _carregando = true;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _erro = null);
    try {
      final e = await PeriodizacaoService.listar(widget.alunoId);
      if (mounted) setState(() => _etapas = e);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Nova etapa começa onde a última termina: é a sequência natural de
  /// quem programa mês a mês.
  EtapaPeriodizacao _nova() {
    final hoje = Datas.dia(DateTime.now());
    var inicio = hoje;
    if (_etapas.isNotEmpty) {
      final ultima = _etapas.last;
      final fim = ultima.dataFim ?? DateTime(ultima.dataInicio.year, ultima.dataInicio.month + 1, ultima.dataInicio.day - 1);
      inicio = fim.add(const Duration(days: 1));
      if (inicio.isBefore(hoje)) inicio = hoje;
    }
    return EtapaPeriodizacao(
      alunoId: widget.alunoId,
      nome: '',
      dataInicio: inicio,
      dataFim: DateTime(inicio.year, inicio.month + 1, inicio.day - 1),
    );
  }

  Future<void> _abrir(EtapaPeriodizacao e) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => EtapaScreen(etapa: e, alunoNome: widget.alunoNome)),
    );
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final idAtual = EtapaPeriodizacao.idDaAtual(_etapas);
    final proximas = _etapas.where((e) => e.momento(idAtual) == MomentoEtapa.proxima).toList();
    final atual = _etapas.where((e) => e.id == idAtual).toList();
    final anteriores = _etapas.where((e) => e.momento(idAtual) == MomentoEtapa.anterior).toList().reversed.toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Periodização', style: AppText.title(17)),
            Text(widget.alunoNome, style: AppText.caption(12)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        onPressed: () => _abrir(_nova()),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nova etapa'),
      ),
      body: _carregando
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _erro != null
              ? PhdEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não consegui carregar',
                  message: 'Se o banco ainda não tem a migration 0024, rode-a no Supabase.\n\n$_erro',
                  actionLabel: 'Tentar de novo',
                  onAction: _carregar,
                )
              : _etapas.isEmpty
                  ? PhdEmptyState(
                      icon: Icons.event_note_rounded,
                      title: 'Nenhuma etapa ainda',
                      message: 'Cada etapa tem o período, o objetivo, volume e intensidade, e as fichas '
                          'que entram em vigor sozinhas quando ela começa. Programe os próximos meses '
                          'de uma vez.',
                      actionLabel: 'Criar a primeira etapa',
                      onAction: () => _abrir(_nova()),
                    )
                  : RefreshIndicator(
                      onRefresh: _carregar,
                      color: AppColors.accent,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, 100),
                        children: [
                          if (atual.isNotEmpty) ...[
                            const PhdSectionHeader(label: 'Agora'),
                            const SizedBox(height: AppSpacing.md),
                            _cartao(atual.first, MomentoEtapa.atual),
                            if (proximas.isEmpty && ResumoPeriodizacao._terminou(atual.first)) ...[
                              const SizedBox(height: AppSpacing.sm),
                              PhdAviso(
                                texto: 'Esta etapa terminou em ${Datas.curta(atual.first.dataFim!)} e não há '
                                    'próxima. As fichas dela continuam valendo até você programar outra.',
                                icone: Icons.info_outline_rounded,
                                cor: AppColors.warning,
                                corTexto: AppColors.warningText,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xxl),
                          ],
                          if (proximas.isNotEmpty) ...[
                            PhdSectionHeader(label: 'Próximas', trailing: '${proximas.length}', trailingColor: AppColors.textMuted),
                            const SizedBox(height: AppSpacing.md),
                            for (final e in proximas) ...[
                              _cartao(e, MomentoEtapa.proxima),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                            const SizedBox(height: AppSpacing.xxl),
                          ],
                          if (anteriores.isNotEmpty) ...[
                            PhdSectionHeader(label: 'Anteriores', trailing: '${anteriores.length}', trailingColor: AppColors.textMuted),
                            const SizedBox(height: AppSpacing.md),
                            for (final e in anteriores) ...[
                              _cartao(e, MomentoEtapa.anterior),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                          ],
                        ],
                      ),
                    ),
    );
  }

  Widget _cartao(EtapaPeriodizacao e, MomentoEtapa m) {
    final (rotulo, tom) = switch (m) {
      MomentoEtapa.atual => ('em vigor', PhdTone.success),
      MomentoEtapa.proxima => ('programada', PhdTone.accent),
      MomentoEtapa.anterior => ('concluída', PhdTone.neutral),
    };
    return PhdCard(
      accentBar: m == MomentoEtapa.atual ? AppColors.success : null,
      onTap: () => _abrir(e),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(e.nome, style: AppText.bodyStrong(15))),
              PhdStatusChip(label: rotulo, tone: tom),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [e.periodoTexto, if (e.objetivo != null) e.objetivo!].join(' · '),
            style: AppText.caption(12.5, color: AppColors.textSecondary),
          ),
          if (e.volume != null || e.intensidade != null) ...[
            const SizedBox(height: AppSpacing.sm),
            if (e.volume != null) Text('Volume: ${e.volume}', style: AppText.caption(12.5)),
            if (e.intensidade != null) Text('Intensidade: ${e.intensidade}', style: AppText.caption(12.5)),
          ],
          if (e.palavrasChave.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [for (final p in e.palavrasChave) PhdStatusChip(label: p)],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(
            e.fichas.isEmpty
                ? 'Sem fichas'
                : e.fichas.map((f) => f.nome).join(', '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppText.caption(12, color: e.fichas.isEmpty ? AppColors.warningText : AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  Etapa
// ════════════════════════════════════════════════════════════════

/// Cria ou edita uma etapa: o planejamento do mês e as fichas dela.
class EtapaScreen extends StatefulWidget {
  const EtapaScreen({super.key, required this.etapa, required this.alunoNome});

  final EtapaPeriodizacao etapa;
  final String alunoNome;

  @override
  State<EtapaScreen> createState() => _EtapaScreenState();
}

class _EtapaScreenState extends State<EtapaScreen> {
  late EtapaPeriodizacao _e = widget.etapa;
  late final _nome = TextEditingController(text: _e.nome);
  late final _objetivo = TextEditingController(text: _e.objetivo);
  late final _volume = TextEditingController(text: _e.volume);
  late final _intensidade = TextEditingController(text: _e.intensidade);
  late final _observacoes = TextEditingController(text: _e.observacoes);
  final _novaPalavra = TextEditingController();
  late List<String> _palavras = [..._e.palavrasChave];
  late DateTime _inicio = _e.dataInicio;
  late DateTime? _fim = _e.dataFim;
  late bool _substitui = _e.substituiAnteriores;
  bool _salvando = false;
  bool _mudou = false;

  @override
  void dispose() {
    for (final c in [_nome, _objetivo, _volume, _intensidade, _observacoes, _novaPalavra]) {
      c.dispose();
    }
    super.dispose();
  }

  void _marcar() {
    if (!_mudou) setState(() => _mudou = true);
  }

  void _avisar(String t) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        content: Text(t, style: AppText.body(13.5)),
      ));

  Future<void> _data({required bool inicio}) async {
    final atual = inicio ? _inicio : (_fim ?? _inicio);
    final d = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
      helpText: inicio ? 'Início da etapa' : 'Fim da etapa',
    );
    if (d == null) return;
    setState(() {
      if (inicio) {
        _inicio = d;
        if (_fim != null && _fim!.isBefore(d)) _fim = DateTime(d.year, d.month + 1, d.day - 1);
      } else {
        _fim = d.isBefore(_inicio) ? _inicio : d;
      }
      _mudou = true;
    });
  }

  void _addPalavra() {
    final p = _novaPalavra.text.trim();
    if (p.isEmpty || _palavras.contains(p)) return;
    setState(() {
      _palavras = [..._palavras, p];
      _novaPalavra.clear();
      _mudou = true;
    });
  }

  Future<bool> _salvar() async {
    if (_nome.text.trim().isEmpty) {
      _avisar('Dê um nome à etapa, ex.: "Dezembro — progressão de carga".');
      return false;
    }
    if (_novaPalavra.text.trim().isNotEmpty) _addPalavra();
    final etapa = EtapaPeriodizacao(
      id: _e.id,
      alunoId: _e.alunoId,
      nome: _nome.text,
      dataInicio: _inicio,
      dataFim: _fim,
      objetivo: _objetivo.text,
      volume: _volume.text,
      intensidade: _intensidade.text,
      palavrasChave: _palavras,
      observacoes: _observacoes.text,
      substituiAnteriores: _substitui,
      fichas: _e.fichas,
    );
    setState(() => _salvando = true);
    try {
      final id = await PeriodizacaoService.salvar(etapa);
      await _recarregar(id);
      if (!mounted) return true;
      setState(() => _mudou = false);
      _avisar('Etapa salva.');
      return true;
    } catch (e) {
      _avisar('Não consegui salvar: ${_semException(e)}');
      return false;
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _recarregar(String id) async {
    final todas = await PeriodizacaoService.listar(_e.alunoId);
    final atual = todas.where((x) => x.id == id).firstOrNull;
    if (atual != null && mounted) setState(() => _e = atual);
  }

  Future<void> _addFicha() async {
    if (_e.id == null || _mudou) {
      if (!await _salvar()) return;
    }
    if (!mounted) return;
    final escolha = await showModalBottomSheet<({String fichaId, List<int> dias})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _FolhaEscolherFicha(jaNaEtapa: {for (final f in _e.fichas) f.fichaId}),
    );
    if (escolha == null) return;
    try {
      await PeriodizacaoService.adicionarFicha(etapa: _e, fichaId: escolha.fichaId, diasSemana: escolha.dias);
      await _recarregar(_e.id!);
    } catch (e) {
      _avisar(_semException(e));
    }
  }

  Future<void> _tirarFicha(FichaDaEtapa f) async {
    try {
      await PeriodizacaoService.removerFicha(_e, f);
      await _recarregar(_e.id!);
    } catch (e) {
      _avisar('Não consegui tirar: ${_semException(e)}');
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Excluir "${_e.nome}"?', style: AppText.title(17)),
        content: Text(
          'As fichas que ainda não começaram saem do aluno. As que já valeram ficam no histórico.',
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
      await PeriodizacaoService.excluir(_e);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _avisar('Não consegui excluir: ${_semException(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final comecou = !_inicio.isAfter(Datas.dia(DateTime.now()));
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_e.id == null ? 'Nova etapa' : 'Etapa', style: AppText.title(17)),
            Text(widget.alunoNome, style: AppText.caption(12)),
          ],
        ),
        actions: [
          if (_e.id != null)
            IconButton(
              tooltip: 'Excluir etapa',
              icon: Icon(Icons.delete_outline_rounded, color: AppColors.textMuted),
              onPressed: _excluir,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
        children: [
          PhdField(
            label: 'Nome da etapa',
            controller: _nome,
            hint: 'Dezembro — progressão de carga',
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _marcar(),
          ),
          const SizedBox(height: AppSpacing.xl),
          const PhdSectionHeader(label: 'Período'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _botaoData('Início', _inicio, () => _data(inicio: true))),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _botaoData('Fim', _fim, () => _data(inicio: false))),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            comecou
                ? 'Já começou: as fichas desta etapa estão valendo para o aluno.'
                : 'As fichas desta etapa entram no app do aluno sozinhas em ${Datas.curta(_inicio)}. '
                    'Mude a data para antecipar ou adiar.',
            style: AppText.caption(12, color: AppColors.textMuted),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _substitui,
            activeThumbColor: AppColors.accent,
            onChanged: (v) => setState(() {
              _substitui = v;
              _mudou = true;
            }),
            title: Text('Substitui os treinos anteriores', style: AppText.body(14)),
            subtitle: Text(
              'Quando começar, as fichas que estavam valendo vão para o histórico. Desligue se o aluno '
              'mantém uma ficha paralela (ex.: mobilidade).',
              style: AppText.caption(11.5, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const PhdSectionHeader(label: 'Planejamento'),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final o in EtapaPeriodizacao.objetivos)
                PhdFilterChip(
                  label: o,
                  selected: _objetivo.text.trim() == o,
                  onTap: () => setState(() {
                    _objetivo.text = _objetivo.text.trim() == o ? '' : o;
                    _mudou = true;
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PhdField(
            label: 'Objetivo do mês',
            controller: _objetivo,
            hint: 'Ou escreva outro',
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() => _mudou = true),
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdField(
            label: 'Volume esperado',
            controller: _volume,
            hint: 'Ex.: 14–16 séries semanais por grupo grande',
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _marcar(),
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdField(
            label: 'Intensidade esperada',
            controller: _intensidade,
            hint: 'Ex.: RIR 2–1, última série até a falha, drop-set no isolador',
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _marcar(),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Palavras-chave', style: AppText.caption(12.5)),
          const SizedBox(height: AppSpacing.sm),
          if (_palavras.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in _palavras)
                  InputChip(
                    label: Text(p, style: AppText.body(13)),
                    backgroundColor: AppColors.surfaceHigh,
                    side: BorderSide(color: AppColors.line),
                    onDeleted: () => setState(() {
                      _palavras = [..._palavras]..remove(p);
                      _mudou = true;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: PhdField(
                  label: 'Nova palavra-chave',
                  controller: _novaPalavra,
                  hint: 'progressão, controle excêntrico, densidade…',
                  onSubmitted: _addPalavra,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PhdButton(
                label: 'Adicionar',
                expand: false,
                size: PhdButtonSize.medium,
                variant: PhdButtonVariant.secondary,
                onPressed: _addPalavra,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdField(
            label: 'Observações e estratégias',
            controller: _observacoes,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => _marcar(),
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdButton(
            label: _e.id == null ? 'Salvar etapa' : 'Salvar alterações',
            icon: Icons.check_rounded,
            loading: _salvando,
            onPressed: _salvando || (_e.id != null && !_mudou) ? null : _salvar,
          ),
          const SizedBox(height: AppSpacing.xxl),
          PhdSectionHeader(
            label: 'Fichas da etapa',
            trailing: _e.fichas.isEmpty ? null : '${_e.fichas.length}',
            trailingColor: AppColors.textMuted,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Ficam programadas e aparecem para o aluno quando a etapa começar.',
            style: AppText.caption(12, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final f in _e.fichas) ...[
            _linhaFicha(f),
            const SizedBox(height: AppSpacing.sm),
          ],
          PhdAddCard(
            label: _e.id == null ? 'Salvar e adicionar ficha' : 'Adicionar ficha',
            icon: Icons.fitness_center_rounded,
            height: 46,
            onTap: _addFicha,
          ),
        ],
      ),
    );
  }

  Widget _botaoData(String rotulo, DateTime? d, VoidCallback onTap) => PhdCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rotulo, style: AppText.caption(11.5, color: AppColors.textMuted)),
                  Text(d == null ? 'sem data' : Datas.curta(d), style: AppText.bodyStrong(14)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _linhaFicha(FichaDaEtapa f) {
    final (rotulo, tom) = switch (f.estado) {
      'vigente' => ('valendo', PhdTone.success),
      'programada' => ('programada', PhdTone.accent),
      _ => ('encerrada', PhdTone.neutral),
    };
    return PhdCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(Icons.fitness_center_rounded, size: 18, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.nome, style: AppText.bodyStrong(13.5)),
                Text(
                  f.diasSemana.isEmpty ? 'sem dia fixo' : f.diasSemana.map((d) => _diasLetra[d]).join(' '),
                  style: AppText.caption(11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          PhdStatusChip(label: rotulo, tone: tom),
          if (f.estado != 'encerrada')
            IconButton(
              tooltip: 'Tirar ${f.nome} da etapa',
              icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
              onPressed: () => _tirarFicha(f),
            ),
        ],
      ),
    );
  }
}

/// Escolhe a ficha e os dias da semana.
class _FolhaEscolherFicha extends StatefulWidget {
  const _FolhaEscolherFicha({required this.jaNaEtapa});
  final Set<String> jaNaEtapa;

  @override
  State<_FolhaEscolherFicha> createState() => _FolhaEscolherFichaState();
}

class _FolhaEscolherFichaState extends State<_FolhaEscolherFicha> {
  List<Map<String, dynamic>>? _fichas;
  String? _escolhida;
  final _dias = <int>{};
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

  @override
  Widget build(BuildContext context) {
    final fichas = _fichas;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          Text('Ficha da etapa', style: AppText.title(19)),
          const SizedBox(height: 4),
          Text('Escolha o treino e os dias em que o aluno faz.', style: AppText.caption(13)),
          const SizedBox(height: AppSpacing.lg),
          if (fichas == null && _erro == null)
            const Center(child: CircularProgressIndicator())
          else if (fichas != null && fichas.isEmpty)
            Text('Você ainda não tem fichas. Crie uma na aba Treinos.', style: AppText.body(14))
          else if (fichas != null)
            for (final f in fichas.where((f) => !widget.jaNaEtapa.contains(f['id'])))
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
                      child: Container(
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
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.md),
            PhdAviso(texto: _erro!),
          ],
          const SizedBox(height: AppSpacing.lg),
          PhdButton(
            label: 'Adicionar à etapa',
            icon: Icons.check_rounded,
            onPressed: _escolhida == null
                ? null
                : () => Navigator.pop(context, (fichaId: _escolhida!, dias: _dias.toList()..sort())),
          ),
        ],
      ),
    );
  }
}
