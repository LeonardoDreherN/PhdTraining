import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/conversa.dart';
import '../../../core/services/agenda_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../core/widgets/widgets.dart';

const _diasCurtos = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _meses = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

extension StatusConsultaTom on StatusConsulta {
  PhdTone get tom => switch (this) {
        StatusConsulta.agendada => PhdTone.neutral,
        StatusConsulta.confirmada => PhdTone.success,
        StatusConsulta.remarcar => PhdTone.warning,
        StatusConsulta.cancelada => PhdTone.danger,
        StatusConsulta.realizada => PhdTone.accent,
      };
}

/// "qui, 29 out · 14:30"
String quandoConsulta(Consulta c) =>
    '${_diasCurtos[c.inicio.weekday - 1]}, ${c.inicio.day} ${_meses[c.inicio.month - 1]} · ${c.horaTexto}';

/// Agenda do profissional: duas semanas à frente, um dia por vez.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key});

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  static const _janela = 21;

  final _hoje = Datas.dia(DateTime.now());
  late DateTime _dia = _hoje;
  List<Consulta> _consultas = const [];
  bool _carregando = true;
  Object? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final c = await AgendaService.doProfissional(
        de: _hoje,
        ate: _hoje.add(const Duration(days: _janela)),
      );
      if (mounted) setState(() => _consultas = c);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Consulta> _doDia(DateTime d) => _consultas.where((c) => Datas.dia(c.inicio) == d).toList();

  Future<void> _agendar([Consulta? c]) async {
    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => FolhaConsulta(consulta: c, diaInicial: _dia),
    );
    if (salvou == true) await _carregar();
  }

  Future<void> _acao(Consulta c, String acao) async {
    try {
      switch (acao) {
        case 'editar':
          await _agendar(c);
          return;
        case 'realizada':
          await AgendaService.mudarStatus(c.id, StatusConsulta.realizada);
        case 'cancelar':
          await AgendaService.mudarStatus(c.id, StatusConsulta.cancelada);
        case 'excluir':
          await AgendaService.excluir(c.id);
        case 'lembrar':
          final primeiro = c.alunoNome.split(' ').first;
          final zap = linkWhatsApp(
            c.aluno?['whatsapp'] as String?,
            mensagem: 'Oi $primeiro! Lembrando da nossa ${c.tipo.rotulo.toLowerCase()} '
                '${quandoConsulta(c)}${c.local == null ? '' : ' em ${c.local}'}. '
                'Você confirma pelo app?',
          );
          if (zap != null) await launchUrl(zap, mode: LaunchMode.externalApplication);
          return;
      }
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui salvar: $e', style: AppText.body(13.5))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final doDia = _doDia(_dia);
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Agenda', style: AppText.title(16)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.onAccent,
        onPressed: _agendar,
        icon: const Icon(Icons.add_rounded),
        label: Text('Agendar', style: AppText.bodyStrong(14, color: AppColors.onAccent)),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              itemCount: _janela,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (_, i) => _botaoDia(_hoje.add(Duration(days: i))),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _carregando
                ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _erro != null
                    ? PhdEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Não consegui carregar',
                        message: '$_erro',
                        actionLabel: 'Tentar de novo',
                        onAction: _carregar,
                      )
                    : RefreshIndicator(
                        color: AppColors.accent,
                        onRefresh: _carregar,
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, 96),
                          children: [
                            Text(
                              _dia == _hoje
                                  ? 'Hoje'
                                  : '${_diasCurtos[_dia.weekday - 1]}, ${_dia.day} de ${_meses[_dia.month - 1]}',
                              style: AppText.title(18),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (doDia.isEmpty)
                              PhdCard(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Column(
                                  children: [
                                    Icon(Icons.event_available_rounded, size: 32, color: AppColors.textMuted),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text('Dia livre', style: AppText.bodyStrong(14)),
                                    Text('Toque em "Agendar" para marcar uma consulta.',
                                        textAlign: TextAlign.center, style: AppText.caption(12.5)),
                                  ],
                                ),
                              ),
                            for (final c in doDia)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                                child: _cartao(c),
                              ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _botaoDia(DateTime d) {
    final selecionado = d == _dia;
    final n = _doDia(d).where((c) => c.ativa).length;
    return GestureDetector(
      onTap: () => setState(() => _dia = d),
      child: AnimatedContainer(
        duration: AppDuration.fast,
        width: 52,
        decoration: BoxDecoration(
          color: selecionado ? AppColors.accent : AppColors.surface,
          borderRadius: AppRadius.rLg,
          border: Border.all(color: selecionado ? AppColors.accent : AppColors.line),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_diasCurtos[d.weekday - 1],
                style: AppText.caption(10.5, color: selecionado ? AppColors.onAccent : AppColors.textMuted)),
            Text('${d.day}',
                style: AppText.number(18, color: selecionado ? AppColors.onAccent : AppColors.textPrimary)),
            const SizedBox(height: 3),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: n == 0
                    ? Colors.transparent
                    : selecionado
                        ? AppColors.onAccent
                        : AppColors.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cartao(Consulta c) {
    final apagada = c.status == StatusConsulta.cancelada;
    return PhdCard(
      onTap: () => _agendar(c),
      padding: const EdgeInsets.all(AppSpacing.md),
      accentBar: c.status == StatusConsulta.remarcar ? AppColors.warning : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.horaTexto,
                    style: AppText.number(17,
                        color: apagada ? AppColors.textMuted : AppColors.textPrimary, weight: FontWeight.w800)),
                Text('${c.duracaoMin} min', style: AppText.caption(11, color: AppColors.textMuted)),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PhdAvatar(name: c.alunoNome, imageUrl: c.aluno?['foto_url'] as String?, size: 26),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        c.alunoNome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.bodyStrong(14, color: apagada ? AppColors.textMuted : AppColors.textPrimary)
                            .copyWith(decoration: apagada ? TextDecoration.lineThrough : null),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  [c.tipo.rotulo, if (c.local != null) c.local!, if (c.link != null) 'online'].join(' · '),
                  style: AppText.caption(12),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    PhdStatusChip(label: c.status.rotulo, tone: c.status.tom),
                    if (c.nota != null) PhdStatusChip(label: '★ ${c.nota}', tone: PhdTone.accent),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.surfaceHigh,
            tooltip: 'Opções da consulta',
            icon: Icon(Icons.more_vert_rounded, size: 19, color: AppColors.textMuted),
            onSelected: (v) => _acao(c, v),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'editar', child: Text('Remarcar ou editar', style: AppText.body(14))),
              if (c.ativa && c.status != StatusConsulta.realizada)
                PopupMenuItem(value: 'realizada', child: Text('Marcar como realizada', style: AppText.body(14))),
              if (c.ativa && !c.passou)
                PopupMenuItem(value: 'lembrar', child: Text('Lembrar no WhatsApp', style: AppText.body(14))),
              if (c.ativa)
                PopupMenuItem(value: 'cancelar', child: Text('Cancelar', style: AppText.body(14))),
              PopupMenuItem(
                value: 'excluir',
                child: Text('Excluir', style: AppText.body(14, color: AppColors.dangerText)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Agendar / editar
// ══════════════════════════════════════════════════════════════

class FolhaConsulta extends StatefulWidget {
  const FolhaConsulta({super.key, this.consulta, required this.diaInicial, this.alunoId});

  final Consulta? consulta;
  final DateTime diaInicial;

  /// Já vem escolhido quando a folha abre a partir de um aluno.
  final String? alunoId;

  @override
  State<FolhaConsulta> createState() => _FolhaConsultaState();
}

class _FolhaConsultaState extends State<FolhaConsulta> {
  List<Map<String, dynamic>> _alunos = const [];
  late String? _alunoId = widget.consulta?.alunoId ?? widget.alunoId;
  late DateTime _data = Datas.dia(widget.consulta?.inicio ?? widget.diaInicial);
  late TimeOfDay _hora = widget.consulta == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(widget.consulta!.inicio);
  late int _duracao = widget.consulta?.duracaoMin ?? 60;
  late TipoConsulta _tipo = widget.consulta?.tipo ?? TipoConsulta.retorno;
  late final _local = TextEditingController(text: widget.consulta?.local);
  late final _link = TextEditingController(text: widget.consulta?.link);
  late final _obs = TextEditingController(text: widget.consulta?.observacoes);
  bool _salvando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    Supabase.instance.client
        .from('alunos')
        .select('id, nome')
        .eq('personal_id', Supabase.instance.client.auth.currentUser!.id)
        .eq('ativo', true)
        .order('nome', ascending: true)
        .then((l) {
      if (mounted) setState(() => _alunos = List<Map<String, dynamic>>.from(l));
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _local.dispose();
    _link.dispose();
    _obs.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_alunoId == null) {
      setState(() => _erro = 'Escolha o aluno.');
      return;
    }
    final inicio = DateTime(_data.year, _data.month, _data.day, _hora.hour, _hora.minute);
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await AgendaService.salvar(
        id: widget.consulta?.id,
        alunoId: _alunoId!,
        inicio: inicio,
        duracaoMin: _duracao,
        tipo: _tipo,
        local: _local.text,
        link: _link.text,
        observacoes: _obs.text,
      );
      if (mounted) Navigator.pop(context, true);
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
            Text(widget.consulta == null ? 'Agendar consulta' : 'Editar consulta', style: AppText.title(19)),
            if (widget.consulta != null) ...[
              const SizedBox(height: 4),
              Text('Mudar data ou hora volta a pedir a confirmação do aluno.', style: AppText.caption(12.5)),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text('Aluno', style: AppText.caption(12.5)),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              initialValue: _alunos.any((a) => a['id'] == _alunoId) ? _alunoId : null,
              isExpanded: true,
              dropdownColor: AppColors.surfaceHigh,
              hint: Text(_alunos.isEmpty ? 'Carregando…' : 'Escolha', style: AppText.body(14.5)),
              items: [
                for (final a in _alunos)
                  DropdownMenuItem(value: a['id'] as String, child: Text(a['nome'] as String? ?? '', style: AppText.body(14.5))),
              ],
              onChanged: (v) => setState(() => _alunoId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _campoToque(
                    Icons.event_rounded,
                    '${_diasCurtos[_data.weekday - 1]}, ${_data.day} ${_meses[_data.month - 1]}',
                    () async {
                      final d = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now().subtract(const Duration(days: 30)),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: _data,
                      );
                      if (d != null) setState(() => _data = d);
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _campoToque(Icons.schedule_rounded, _hora.format(context), () async {
                    final h = await showTimePicker(context: context, initialTime: _hora);
                    if (h != null) setState(() => _hora = h);
                  }),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Duração', style: AppText.caption(12.5)),
            const SizedBox(height: 7),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                for (final m in const [30, 45, 60, 90])
                  PhdFilterChip(label: '$m min', selected: _duracao == m, onTap: () => setState(() => _duracao = m)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Tipo', style: AppText.caption(12.5)),
            const SizedBox(height: 7),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final t in TipoConsulta.values)
                  PhdFilterChip(label: t.rotulo, selected: _tipo == t, onTap: () => setState(() => _tipo = t)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_tipo == TipoConsulta.online)
              PhdField(controller: _link, label: 'Link da chamada', hint: 'https://meet.google.com/…', keyboardType: TextInputType.url)
            else
              PhdField(controller: _local, label: 'Local', hint: 'Academia Prado, sala 2', textCapitalization: TextCapitalization.sentences),
            const SizedBox(height: AppSpacing.md),
            PhdField(
              controller: _obs,
              label: 'Observações (o aluno vê)',
              hint: 'Venha de jejum de 4 horas para a bioimpedância',
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (_erro != null) ...[
              const SizedBox(height: AppSpacing.md),
              PhdAviso(texto: _erro!),
            ],
            const SizedBox(height: AppSpacing.lg),
            PhdButton(
              label: widget.consulta == null ? 'Agendar' : 'Salvar',
              icon: Icons.check_rounded,
              loading: _salvando,
              onPressed: _salvar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoToque(IconData icone, String texto, VoidCallback onTap) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: AppRadius.rMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 14),
          child: Row(
            children: [
              Icon(icone, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(texto, style: AppText.bodyStrong(14))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resumo de hoje para a home do profissional. Some quando a agenda
/// ainda não existe no servidor.
class CartaoAgendaHoje extends StatefulWidget {
  const CartaoAgendaHoje({super.key});

  @override
  State<CartaoAgendaHoje> createState() => _CartaoAgendaHojeState();
}

class _CartaoAgendaHojeState extends State<CartaoAgendaHoje> {
  List<Consulta>? _hoje;
  int _pendentes = 0;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final hoje = Datas.dia(DateTime.now());
      final semana = await AgendaService.doProfissional(de: hoje, ate: hoje.add(const Duration(days: 7)));
      if (!mounted) return;
      setState(() {
        _hoje = semana.where((c) => Datas.dia(c.inicio) == hoje && c.ativa).toList();
        _pendentes = semana.where((c) => c.status == StatusConsulta.remarcar).length;
      });
    } catch (_) {
      // Sem tabela de consultas: a home segue sem o cartão.
    }
  }

  @override
  Widget build(BuildContext context) {
    final hoje = _hoje;
    if (hoje == null) return const SizedBox.shrink();
    final proxima = hoje.where((c) => !c.passou).firstOrNull;

    return PhdCard(
      onTap: () async {
        await Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const AgendaScreen()));
        if (mounted) _carregar();
      },
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.tint(AppColors.accent), borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.calendar_month_rounded, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hoje.isEmpty
                      ? 'Nenhuma consulta hoje'
                      : '${hoje.length} ${hoje.length == 1 ? 'consulta' : 'consultas'} hoje',
                  style: AppText.bodyStrong(14),
                ),
                Text(
                  proxima != null
                      ? 'Próxima: ${proxima.horaTexto} · ${proxima.alunoNome.split(' ').first}'
                      : _pendentes > 0
                          ? '$_pendentes ${_pendentes == 1 ? 'aluno pediu' : 'alunos pediram'} para remarcar'
                          : 'Toque para ver a agenda',
                  style: AppText.caption(12, color: _pendentes > 0 && proxima == null ? AppColors.warningText : null),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
