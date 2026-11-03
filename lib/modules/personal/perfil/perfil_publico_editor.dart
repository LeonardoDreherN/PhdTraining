import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/cupom.dart';
import '../../../core/services/cupom_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../aluno/perfil/perfil_profissional_screen.dart';

/// O que o aluno vê ao tocar no profissional: bio, formações e cupons.
class PerfilPublicoEditor extends StatefulWidget {
  const PerfilPublicoEditor({super.key, required this.perfil});

  /// A linha de `profiles` do próprio profissional.
  final Map<String, dynamic>? perfil;

  @override
  State<PerfilPublicoEditor> createState() => _PerfilPublicoEditorState();
}

class _PerfilPublicoEditorState extends State<PerfilPublicoEditor> {
  late final _bio = TextEditingController(text: widget.perfil?['bio'] as String? ?? '');
  final _novaFormacao = TextEditingController();
  late List<String> _formacoes = lerFormacoes(widget.perfil?['formacoes']);
  bool _bioMudou = false;
  bool _salvando = false;

  List<Cupom> _cupons = const [];
  bool _semTabela = false;

  String get _meuId => Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _carregarCupons();
  }

  @override
  void dispose() {
    _bio.dispose();
    _novaFormacao.dispose();
    super.dispose();
  }

  Future<void> _carregarCupons() async {
    try {
      final c = await CupomService.meus();
      if (mounted) setState(() => _cupons = c);
    } catch (_) {
      // Sem a migration 0022: a seção avisa em vez de quebrar o perfil.
      if (mounted) setState(() => _semTabela = true);
    }
  }

  void _avisar(String texto, {bool erro = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: erro ? AppColors.surfaceHigh : AppColors.accent,
      content: Text(texto, style: AppText.body(13.5, color: erro ? AppColors.textPrimary : AppColors.onAccent)),
    ));
  }

  void _addFormacao() {
    final f = _novaFormacao.text.trim();
    if (f.isEmpty) return;
    setState(() {
      _formacoes = [..._formacoes, f];
      _novaFormacao.clear();
      _bioMudou = true;
    });
  }

  Future<void> _salvarBio() async {
    // Uma formação digitada e não adicionada também vale: é o que a pessoa
    // espera ao tocar em salvar.
    if (_novaFormacao.text.trim().isNotEmpty) _addFormacao();
    setState(() => _salvando = true);
    try {
      await CupomService.salvarBio(bio: _bio.text, formacoes: _formacoes);
      if (!mounted) return;
      setState(() => _bioMudou = false);
      _avisar('Perfil salvo');
    } catch (e) {
      if (mounted) _avisar('Não consegui salvar: $e', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _editarCupom([Cupom? c]) async {
    final mudou = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CupomSheet(cupom: c, ordem: _cupons.length),
    );
    if (mudou == true) _carregarCupons();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhdField(
          label: 'Bio',
          controller: _bio,
          hint: 'Quem você é, como trabalha, para quem é o seu acompanhamento.',
          maxLines: 5,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (!_bioMudou) setState(() => _bioMudou = true);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Formações', style: AppText.caption(12.5)),
        const SizedBox(height: AppSpacing.sm),
        for (final (i, f) in _formacoes.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Row(
              children: [
                Icon(Icons.school_outlined, size: 17, color: AppColors.textMuted),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(f, style: AppText.body(13.5))),
                IconButton(
                  tooltip: 'Tirar $f',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
                  onPressed: () => setState(() {
                    _formacoes = [..._formacoes]..removeAt(i);
                    _bioMudou = true;
                  }),
                ),
              ],
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: PhdField(
                label: 'Nova formação',
                controller: _novaFormacao,
                hint: 'Ex.: Pós em Nutrição Esportiva — UFSC',
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: _addFormacao,
                onChanged: (_) {
                  if (!_bioMudou) setState(() => _bioMudou = true);
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PhdButton(
              label: 'Adicionar',
              expand: false,
              size: PhdButtonSize.medium,
              variant: PhdButtonVariant.secondary,
              onPressed: _addFormacao,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        PhdButton(
          label: 'Salvar bio e formações',
          loading: _salvando,
          onPressed: _bioMudou && !_salvando ? _salvarBio : null,
        ),
        const SizedBox(height: AppSpacing.xxl),
        PhdSectionHeader(
          label: 'Cupons de desconto',
          trailing: _cupons.isEmpty ? null : '${_cupons.length}',
          trailingColor: AppColors.textMuted,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Seus alunos veem os cupons ativos no seu perfil. Pode ser de uma loja parceira '
          'ou de outro profissional do PHD que você indica.',
          style: AppText.caption(12, color: AppColors.textMuted),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_semTabela)
          PhdCard(
            child: Text('Os cupons ainda não estão disponíveis neste servidor (migration 0022).',
                style: AppText.caption(13)),
          )
        else ...[
          for (final c in _cupons) ...[
            _linhaCupom(c),
            const SizedBox(height: AppSpacing.sm),
          ],
          PhdAddCard(label: 'Novo cupom', height: 46, onTap: () => _editarCupom()),
        ],
        const SizedBox(height: AppSpacing.lg),
        PhdButton(
          label: 'Ver como o aluno vê',
          icon: Icons.visibility_outlined,
          variant: PhdButtonVariant.ghost,
          size: PhdButtonSize.medium,
          onPressed: () => Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => PerfilProfissionalScreen(profissionalId: _meuId)),
          ),
        ),
      ],
    );
  }

  Widget _linhaCupom(Cupom c) {
    final (rotulo, tom) = !c.ativo
        ? ('desligado', PhdTone.neutral)
        : c.vencido
            ? ('vencido', PhdTone.warning)
            : ('ativo', PhdTone.success);
    return PhdCard(
      onTap: () => _editarCupom(c),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Row(
        children: [
          Icon(Icons.local_offer_outlined, size: 19, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.titulo, style: AppText.bodyStrong(14)),
                Text(
                  [
                    if (c.codigo != null) c.codigo!,
                    if (c.indicadoNome != null) 'indica ${c.indicadoNome}',
                  ].join(' · ').ifEmpty('sem código'),
                  style: AppText.caption(11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          PhdStatusChip(label: rotulo, tone: tom),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String outro) => isEmpty ? outro : this;
}

/// Cria ou edita um cupom.
class _CupomSheet extends StatefulWidget {
  const _CupomSheet({this.cupom, required this.ordem});

  final Cupom? cupom;
  final int ordem;

  @override
  State<_CupomSheet> createState() => _CupomSheetState();
}

class _CupomSheetState extends State<_CupomSheet> {
  late final _titulo = TextEditingController(text: widget.cupom?.titulo);
  late final _descricao = TextEditingController(text: widget.cupom?.descricao);
  late final _codigo = TextEditingController(text: widget.cupom?.codigo);
  late final _link = TextEditingController(text: widget.cupom?.link);
  final _email = TextEditingController();

  late DateTime? _validoAte = widget.cupom?.validoAte;
  late bool _ativo = widget.cupom?.ativo ?? true;
  late String? _indicadoId = widget.cupom?.indicadoId;
  late String? _indicadoNome = widget.cupom?.indicadoNome;

  bool _buscando = false;
  String? _avisoBusca;
  bool _salvando = false;

  @override
  void dispose() {
    for (final c in [_titulo, _descricao, _codigo, _link, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _buscarIndicado() async {
    final email = _email.text.trim();
    if (email.isEmpty) return;
    setState(() {
      _buscando = true;
      _avisoBusca = null;
    });
    try {
      final p = await CupomService.profissionalPorEmail(email);
      if (!mounted) return;
      setState(() {
        if (p == null) {
          _avisoBusca = 'Nenhum profissional do PHD com esse e-mail.';
        } else {
          _indicadoId = p.id;
          _indicadoNome = p.nomeExibicao;
          _email.clear();
        }
      });
    } catch (e) {
      if (mounted) setState(() => _avisoBusca = 'Não consegui buscar: $e');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _escolherValidade() async {
    final hoje = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _validoAte ?? hoje.add(const Duration(days: 30)),
      firstDate: DateTime(hoje.year, hoje.month, hoje.day),
      lastDate: hoje.add(const Duration(days: 3650)),
      helpText: 'Válido até',
    );
    if (d != null) setState(() => _validoAte = d);
  }

  Future<void> _salvar() async {
    if (_titulo.text.trim().isEmpty) return;
    setState(() => _salvando = true);
    try {
      await CupomService.salvar(Cupom(
        id: widget.cupom?.id,
        titulo: _titulo.text,
        descricao: _descricao.text,
        codigo: _codigo.text,
        link: _link.text,
        indicadoId: _indicadoId,
        validoAte: _validoAte,
        ativo: _ativo,
        ordem: widget.cupom?.ordem ?? widget.ordem,
      ));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _salvando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui salvar: $e')));
      }
    }
  }

  Future<void> _excluir() async {
    final id = widget.cupom?.id;
    if (id == null) return;
    try {
      await CupomService.excluir(id);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui excluir: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _validoAte;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(widget.cupom == null ? 'Novo cupom' : 'Editar cupom', style: AppText.title(18)),
              const SizedBox(height: AppSpacing.lg),
              PhdField(
                label: 'Título',
                controller: _titulo,
                hint: '10% na Loja Suplementos X',
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              PhdField(
                label: 'Descrição',
                controller: _descricao,
                hint: 'Vale para a primeira compra, no site ou na loja.',
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: PhdField(label: 'Código', controller: _codigo, hint: 'PHD10')),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PhdField(
                      label: 'Link',
                      controller: _link,
                      hint: 'loja.com.br',
                      keyboardType: TextInputType.url,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Indicar outro profissional do PHD', style: AppText.caption(12.5)),
              const SizedBox(height: AppSpacing.sm),
              if (_indicadoId != null)
                PhdCard(
                  color: AppColors.surfaceHigh,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 18, color: AppColors.accent),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(_indicadoNome ?? 'Profissional indicado', style: AppText.bodyStrong(13.5))),
                      TextButton(
                        onPressed: () => setState(() {
                          _indicadoId = null;
                          _indicadoNome = null;
                        }),
                        child: Text('Tirar', style: AppText.bodyStrong(12.5, color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                )
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: PhdField(
                        label: 'E-mail dele no PHD',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: _buscarIndicado,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    PhdButton(
                      label: 'Buscar',
                      expand: false,
                      size: PhdButtonSize.medium,
                      variant: PhdButtonVariant.secondary,
                      loading: _buscando,
                      onPressed: _buscando ? null : _buscarIndicado,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _avisoBusca ??
                      'O aluno abre o perfil dele pelo cupom e fala direto com ele. Opcional.',
                  style: AppText.caption(11.5,
                      color: _avisoBusca == null ? AppColors.textMuted : AppColors.warningText),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      v == null
                          ? 'Sem data de validade'
                          : 'Válido até ${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}',
                      style: AppText.body(13.5),
                    ),
                  ),
                  if (v != null)
                    TextButton(
                      onPressed: () => setState(() => _validoAte = null),
                      child: Text('Tirar', style: AppText.bodyStrong(12.5, color: AppColors.textSecondary)),
                    ),
                  TextButton(
                    onPressed: _escolherValidade,
                    child: Text(v == null ? 'Definir' : 'Mudar',
                        style: AppText.bodyStrong(12.5, color: AppColors.accent)),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _ativo,
                onChanged: (x) => setState(() => _ativo = x),
                activeThumbColor: AppColors.accent,
                title: Text('Aparece para os alunos', style: AppText.body(13.5)),
              ),
              const SizedBox(height: AppSpacing.md),
              PhdButton(
                label: 'Salvar cupom',
                loading: _salvando,
                onPressed: _titulo.text.trim().isEmpty || _salvando ? null : _salvar,
              ),
              if (widget.cupom != null) ...[
                const SizedBox(height: AppSpacing.sm),
                PhdButton(
                  label: 'Excluir cupom',
                  variant: PhdButtonVariant.ghost,
                  size: PhdButtonSize.medium,
                  onPressed: _excluir,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
