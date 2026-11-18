import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/ficha_exercicio.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// O treino inteiro antes de começar.
///
/// Substitui a pergunta "como quer treinar?" com três respostas. O aluno
/// abre, percorre tudo, entende o que vai fazer — e só então começa. Era
/// a reclamação principal: o cronômetro disparava enquanto ele ainda
/// estava lendo o primeiro exercício.
///
/// Nada aqui registra execução nem conta tempo. É consulta.
class PreviewTreinoScreen extends StatefulWidget {
  const PreviewTreinoScreen({
    super.key,
    required this.ficha,
    required this.dia,
  });

  final Map<String, dynamic> ficha;
  final int dia;

  @override
  State<PreviewTreinoScreen> createState() => _PreviewTreinoScreenState();
}

class _PreviewTreinoScreenState extends State<PreviewTreinoScreen> {
  List<FichaExercicio> _itens = const [];
  bool _carregando = true;
  String? _erro;

  /// Qual exercício está com o vídeo aberto. Um por vez: abrir todos
  /// carregaria um player por exercício e travaria o celular na academia.
  String? _videoAberto;

  String get _nomeFicha => widget.ficha['nome'] as String? ?? 'Treino';

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
      final lista =
          await FichaService.listarExercicios(widget.ficha['id'] as String);
      if (mounted) setState(() => _itens = lista);
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Agrupa os exercícios que se executam juntos. Mantém a ordem da
  /// ficha: o bloco aparece onde o primeiro exercício dele está.
  List<List<FichaExercicio>> get _blocos {
    final blocos = <List<FichaExercicio>>[];
    final porGrupo = <String, List<FichaExercicio>>{};

    for (final e in _itens) {
      if (!e.emGrupo) {
        blocos.add([e]);
        continue;
      }
      final existente = porGrupo[e.grupoId!];
      if (existente == null) {
        final novo = [e];
        porGrupo[e.grupoId!] = novo;
        blocos.add(novo);
      } else {
        existente.add(e);
      }
    }
    return blocos;
  }

  int get _totalSeries => _itens.fold(0, (s, e) => s + e.series);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_nomeFicha, style: AppText.title(16)),
            if (_itens.isNotEmpty)
              Text(
                '${_itens.length} ${_itens.length == 1 ? 'exercício' : 'exercícios'}'
                '  ·  $_totalSeries séries',
                style: AppText.caption(11.5, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
      body: _corpo(),
      bottomNavigationBar: _itens.isEmpty ? null : _rodape(),
    );
  }

  Widget _corpo() {
    if (_carregando) {
      return Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        message: _erro!,
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }
    if (_itens.isEmpty) {
      return const PhdEmptyState(
        icon: Icons.fitness_center_rounded,
        title: 'Treino sem exercícios',
        message: 'Seu personal ainda não montou este treino.',
      );
    }

    final blocos = _blocos;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md,
      ),
      itemCount: blocos.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: blocos[i].length == 1
            ? _cartao(blocos[i].first, numero: _numeroDe(blocos, i))
            : _bloco(blocos[i], numero: _numeroDe(blocos, i)),
      ),
    );
  }

  /// A numeração conta exercícios, não blocos: o aluno fala "estou no
  /// quinto", e o quinto tem de ser o quinto exercício.
  int _numeroDe(List<List<FichaExercicio>> blocos, int indice) {
    var n = 1;
    for (var i = 0; i < indice; i++) {
      n += blocos[i].length;
    }
    return n;
  }

  // ── Bloco combinado (bi-set, tri-set, circuito) ─────────────

  Widget _bloco(List<FichaExercicio> itens, {required int numero}) {
    final rotulo = itens.first.metodoRotulo ??
        (itens.length == 2 ? 'Bi-set' : 'Tri-set');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.rLg,
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm, AppSpacing.xs, AppSpacing.sm, AppSpacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text(rotulo.toUpperCase(),
                    style: AppText.label(color: AppColors.accent)),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'sem descanso entre eles',
                    style: AppText.caption(11, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < itens.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.arrow_downward_rounded,
                        size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Text('em seguida',
                        style:
                            AppText.caption(11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            _cartao(itens[i], numero: numero + i, dentroDeBloco: true),
          ],
        ],
      ),
    );
  }

  // ── Exercício ───────────────────────────────────────────────

  Widget _cartao(FichaExercicio e, {required int numero, bool dentroDeBloco = false}) {
    final aberto = _videoAberto == e.id;

    return PhdCard(
      color: dentroDeBloco ? AppColors.surface : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // A foto é a capa do vídeo: parada até o aluno tocar. Abrir
              // um player por exercício ao carregar a lista travaria o
              // celular e gastaria a internet dele à toa.
              GestureDetector(
                onTap: !e.temVideo
                    ? null
                    : () => setState(() => _videoAberto = aberto ? null : e.id),
                child: PhdMiniaturaExercicio(
                  imagemUrl: e.capa,
                  temVideo: e.temVideo,
                  tamanho: 64,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$numero',
                            style: AppText.number(12,
                                color: AppColors.textMuted)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(e.nome,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.title(15)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _prescricao(e),
                  ],
                ),
              ),
            ],
          ),

          // O método é informação de execução, não enfeite: "pirâmide"
          // muda o que o aluno faz em cada série.
          if (!dentroDeBloco && e.metodoRotulo != null) ...[
            const SizedBox(height: AppSpacing.sm),
            PhdStatusChip(label: e.metodoRotulo!, tone: PhdTone.accent),
          ],

          // A observação do personal fica destacada, não em cinza
          // pequeno no rodapé. É onde ele escreve a progressão de carga da
          // pirâmide, o drop, o que o aluno precisa ler para executar
          // certo — e era o que mais se perdia na lista antiga.
          if ((e.observacoes?.trim().isNotEmpty ?? false)) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.tint(AppColors.accent),
                borderRadius: AppRadius.rMd,
                border: Border(
                  left: BorderSide(color: AppColors.accent, width: 3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.push_pin_rounded, size: 15, color: AppColors.accent),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      e.observacoes!.trim(),
                      style: AppText.body(13.5).copyWith(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (aberto) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: AppRadius.rMd,
              child: PhdVideo(url: e.videoUrl!, altura: 200),
            ),
          ],
        ],
      ),
    );
  }

  /// Séries, repetições, carga e descanso — a prescrição inteira, não só
  /// o nome e a quantidade de séries.
  Widget _prescricao(FichaExercicio e) {
    final partes = <(IconData, String)>[
      (Icons.repeat_rounded, e.prescricao),
      if (e.cargaFormatada != null)
        (Icons.fitness_center_rounded, e.cargaFormatada!),
      if (e.descansoFormatado != null)
        (Icons.timer_outlined, e.descansoFormatado!),
    ];

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: 4,
      children: [
        for (final (icone, texto) in partes)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icone, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(texto, style: AppText.number(12.5)),
            ],
          ),
      ],
    );
  }

  // ── Começar ─────────────────────────────────────────────────

  Widget _rodape() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.md,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'O cronômetro começa quando você tocar aqui.',
              style: AppText.caption(11.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: AppSpacing.sm),
            PhdButton(
              label: 'Começar treino',
              icon: Icons.play_arrow_rounded,
              onPressed: _comecar,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _comecar() async {
    await context.push('/aluno/treino', extra: {
      'ficha': widget.ficha,
      'diaSelecionado': widget.dia,
    });
    if (mounted) Navigator.of(context).pop(true);
  }
}
