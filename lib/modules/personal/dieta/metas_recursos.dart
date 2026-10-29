import 'package:flutter/material.dart';
import '../../../core/models/recursos_aluno.dart';
import '../../../core/services/metas_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';

/// As metas de um aluno. O aluno e o profissional marcam como cumprida;
/// só o [profissional] cria, edita e apaga.
///
/// Carrega sozinho para servir às duas telas — a nutrição do aluno, no
/// painel do profissional, e a home do aluno.
class MetasDoAluno extends StatefulWidget {
  const MetasDoAluno({
    super.key,
    required this.alunoId,
    this.profissional = false,
    this.somenteAbertas = false,
  });

  final String alunoId;
  final bool profissional;

  /// Na home do aluno: mostra as abertas e as cumpridas nos últimos dias,
  /// não o histórico inteiro.
  final bool somenteAbertas;

  @override
  State<MetasDoAluno> createState() => _MetasDoAlunoState();
}

class _MetasDoAlunoState extends State<MetasDoAluno> {
  List<MetaAluno> _metas = const [];
  bool _carregou = false;
  bool _semTabela = false;
  final _gravando = <String>{};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final m = await MetasService.listar(widget.alunoId);
      if (mounted) setState(() => _metas = m);
    } catch (_) {
      if (mounted) setState(() => _semTabela = true);
    } finally {
      if (mounted) setState(() => _carregou = true);
    }
  }

  Future<void> _alternar(MetaAluno m) async {
    setState(() => _gravando.add(m.id));
    try {
      await MetasService.concluir(m.id, !m.concluida);
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui marcar: $e', style: AppText.body(13.5))),
        );
      }
    } finally {
      if (mounted) setState(() => _gravando.remove(m.id));
    }
  }

  Future<void> _editar([MetaAluno? m]) async {
    final salvou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      builder: (_) => _FolhaMeta(alunoId: widget.alunoId, meta: m),
    );
    if (salvou == true) await _carregar();
  }

  Future<void> _excluir(MetaAluno m) async {
    try {
      await MetasService.excluir(m.id);
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui apagar: $e', style: AppText.body(13.5))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_carregou) return const SizedBox(height: 40);
    if (_semTabela) {
      return widget.profissional
          ? PhdCard(child: Text('Metas ainda não disponíveis neste servidor.', style: AppText.caption(13)))
          : const SizedBox.shrink();
    }

    final limite = DateTime.now().subtract(const Duration(days: 7));
    final metas = widget.somenteAbertas
        ? _metas.where((m) => !m.concluida || m.concluidaEm!.isAfter(limite)).toList()
        : _metas;

    // Na home do aluno, sem meta nenhuma o cartão não aparece.
    if (metas.isEmpty && !widget.profissional) return const SizedBox.shrink();

    final cumpridas = metas.where((m) => m.concluida).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (metas.isNotEmpty)
          PhdCard(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.profissional) ...[
                  Row(
                    children: [
                      Expanded(child: Text('SUAS METAS', style: AppText.label())),
                      Text('$cumpridas de ${metas.length}', style: AppText.caption(12)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  PhdSegments(total: metas.length, filled: cumpridas, color: AppColors.success),
                  const SizedBox(height: AppSpacing.sm),
                ],
                for (final m in metas) _linha(m),
              ],
            ),
          ),
        if (widget.profissional) ...[
          const SizedBox(height: AppSpacing.sm),
          PhdAddCard(label: 'Nova meta', icon: Icons.flag_outlined, height: 44, onTap: _editar),
        ],
      ],
    );
  }

  Widget _linha(MetaAluno m) {
    final ocupada = _gravando.contains(m.id);
    final vencida = !m.concluida && m.prazo != null && m.prazo!.isBefore(Datas.dia(DateTime.now()));

    return InkWell(
      borderRadius: AppRadius.rMd,
      onTap: ocupada ? null : () => _alternar(m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: AppDuration.fast,
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: m.concluida ? AppColors.success : Colors.transparent,
                shape: BoxShape.circle,
                border: m.concluida ? null : Border.all(color: AppColors.lineStrong, width: 1.5),
              ),
              child: m.concluida ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.titulo,
                    style: AppText.bodyStrong(14, color: m.concluida ? AppColors.textMuted : AppColors.textPrimary)
                        .copyWith(decoration: m.concluida ? TextDecoration.lineThrough : null),
                  ),
                  if (m.descricao != null)
                    Text(m.descricao!, style: AppText.caption(12)),
                  if (m.prazo != null || m.concluida)
                    Text(
                      m.concluida
                          ? 'Cumprida em ${Datas.curta(m.concluidaEm!)}'
                          : 'Até ${Datas.curta(m.prazo!)}',
                      style: AppText.caption(11.5,
                          color: vencida ? AppColors.warningText : AppColors.textMuted),
                    ),
                ],
              ),
            ),
            if (widget.profissional)
              PopupMenuButton<String>(
                color: AppColors.surfaceHigh,
                tooltip: 'Opções da meta',
                icon: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.textMuted),
                onSelected: (v) => v == 'editar' ? _editar(m) : _excluir(m),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'editar', child: Text('Editar', style: AppText.body(14))),
                  PopupMenuItem(
                    value: 'apagar',
                    child: Text('Apagar', style: AppText.body(14, color: AppColors.dangerText)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _FolhaMeta extends StatefulWidget {
  const _FolhaMeta({required this.alunoId, this.meta});

  final String alunoId;
  final MetaAluno? meta;

  @override
  State<_FolhaMeta> createState() => _FolhaMetaState();
}

class _FolhaMetaState extends State<_FolhaMeta> {
  late final _titulo = TextEditingController(text: widget.meta?.titulo);
  late final _descricao = TextEditingController(text: widget.meta?.descricao);
  late DateTime? _prazo = widget.meta?.prazo;
  bool _salvando = false;
  String? _erro;

  static const _sugestoes = [
    'Beber 2 L de água por dia',
    'Uma fruta no lanche da tarde',
    'Jantar até as 21h',
    'Dormir 7 horas por noite',
    'Registrar todas as refeições',
  ];

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_titulo.text.trim().isEmpty) {
      setState(() => _erro = 'Escreva a meta.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await MetasService.salvar(
        id: widget.meta?.id,
        alunoId: widget.alunoId,
        titulo: _titulo.text.trim(),
        descricao: _descricao.text,
        prazo: _prazo,
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
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.meta == null ? 'Nova meta' : 'Editar meta', style: AppText.title(19)),
            const SizedBox(height: AppSpacing.lg),
            if (widget.meta == null) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final s in _sugestoes)
                    ActionChip(
                      label: Text(s, style: AppText.caption(12, color: AppColors.textPrimary)),
                      backgroundColor: AppColors.surfaceHigh,
                      side: BorderSide.none,
                      onPressed: () => setState(() => _titulo.text = s),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            PhdField(
              controller: _titulo,
              label: 'Meta',
              hint: 'Beber 2 L de água por dia',
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            PhdField(
              controller: _descricao,
              label: 'Detalhe (opcional)',
              hint: 'Leve a garrafinha para o trabalho',
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _prazo == null ? 'Sem prazo' : 'Até ${Datas.curta(_prazo!)}',
                    style: AppText.body(14),
                  ),
                ),
                if (_prazo != null)
                  TextButton(
                    onPressed: () => setState(() => _prazo = null),
                    child: Text('Tirar prazo', style: AppText.bodyStrong(13, color: AppColors.textSecondary)),
                  ),
                TextButton(
                  onPressed: () async {
                    final hoje = DateTime.now();
                    final d = await showDatePicker(
                      context: context,
                      firstDate: hoje,
                      lastDate: hoje.add(const Duration(days: 365)),
                      initialDate: _prazo ?? hoje.add(const Duration(days: 30)),
                    );
                    if (d != null) setState(() => _prazo = d);
                  },
                  child: Text('Definir prazo', style: AppText.bodyStrong(13, color: AppColors.accent)),
                ),
              ],
            ),
            if (_erro != null) ...[
              const SizedBox(height: AppSpacing.md),
              PhdAviso(texto: _erro!),
            ],
            const SizedBox(height: AppSpacing.lg),
            PhdButton(label: 'Salvar meta', icon: Icons.check_rounded, loading: _salvando, onPressed: _salvar),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  O que o aluno vê
// ══════════════════════════════════════════════════════════════

/// Liga e desliga, por aluno, partes do app dele.
class RecursosDoAluno extends StatefulWidget {
  const RecursosDoAluno({super.key, required this.alunoId});

  final String alunoId;

  @override
  State<RecursosDoAluno> createState() => _RecursosDoAlunoState();
}

class _RecursosDoAlunoState extends State<RecursosDoAluno> {
  RecursosAluno? _r;

  @override
  void initState() {
    super.initState();
    MetasService.recursos(widget.alunoId).then((r) {
      if (mounted) setState(() => _r = r);
    });
  }

  Future<void> _mudar(RecursosAluno novo) async {
    final antes = _r;
    setState(() => _r = novo);
    try {
      await MetasService.salvarRecursos(widget.alunoId, novo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _r = antes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e', style: AppText.body(13.5))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _r;
    if (r == null) return const SizedBox(height: 40);

    return PhdCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        children: [
          _linha(
            'Calorias e macros',
            'Desligue para quem não deve contar calorias. O aluno continua vendo o que '
                'comer e as quantidades.',
            r.nutricional,
            (v) => _mudar(r.copiar(nutricional: v)),
          ),
          Divider(height: 1, color: AppColors.line),
          _linha('Diário alimentar', 'Foto do prato e "como foi" em cada refeição.', r.diario,
              (v) => _mudar(r.copiar(diario: v))),
          Divider(height: 1, color: AppColors.line),
          _linha('Registro de peso', 'O aluno anota o peso em casa.', r.peso,
              (v) => _mudar(r.copiar(peso: v))),
          Divider(height: 1, color: AppColors.line),
          _linha('Lista de compras', 'Gerada a partir do plano.', r.listaCompras,
              (v) => _mudar(r.copiar(listaCompras: v))),
          Divider(height: 1, color: AppColors.line),
          _linha('Mensagens pelo app', 'Desligado, o contato fica só pelo WhatsApp.', r.chat,
              (v) => _mudar(r.copiar(chat: v))),
        ],
      ),
    );
  }

  Widget _linha(String titulo, String apoio, bool valor, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppText.bodyStrong(14)),
                Text(apoio, style: AppText.caption(11.5)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(value: valor, onChanged: onChanged),
        ],
      ),
    );
  }
}
