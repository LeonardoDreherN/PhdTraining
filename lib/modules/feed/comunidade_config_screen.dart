import 'package:flutter/material.dart';

import '../../core/models/feed.dart';
import '../../core/services/feed_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/widgets.dart';

/// O que o profissional habilita na comunidade dele.
///
/// Tudo começa com o feed desligado. Ligar é uma decisão dele, não um
/// padrão: nem todo profissional quer rede social no produto, e um feed
/// vazio na tela do aluno parece defeito.
class ComunidadeConfigScreen extends StatefulWidget {
  const ComunidadeConfigScreen({super.key, required this.personalId});

  final String personalId;

  @override
  State<ComunidadeConfigScreen> createState() => _ComunidadeConfigScreenState();
}

class _ComunidadeConfigScreenState extends State<ComunidadeConfigScreen> {
  ConfigComunidade _c = const ConfigComunidade();
  bool _carregando = true;
  bool _salvando = false;
  Object? _erro;

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
      final c = await FeedService.config(widget.personalId);
      if (mounted) setState(() => _c = c);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// Grava a cada toque. Uma tela de interruptores com botão "Salvar" é
  /// onde a pessoa mexe em três e sai sem salvar nenhum.
  Future<void> _mudar(ConfigComunidade novo) async {
    final antes = _c;
    setState(() {
      _c = novo;
      _salvando = true;
    });
    try {
      await FeedService.salvarConfig(novo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _c = antes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Não consegui salvar: $e', style: AppText.body(13.5)),
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Comunidade', style: AppText.title(16)),
        actions: [
          if (_salvando)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.lg),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent),
                ),
              ),
            ),
        ],
      ),
      body: _corpo(),
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
        message: '$_erro',
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.huge * 2,
      ),
      children: [
        _chave(
          'Comunidade ligada',
          'Seus alunos passam a ver um feed com avisos seus e as '
              'conquistas de quem autorizou.',
          _c.feedAtivo,
          (v) => _mudar(_c.copiaCom(feedAtivo: v)),
          destaque: true,
        ),

        if (_c.feedAtivo) ...[
          const SizedBox(height: AppSpacing.xl),
          const PhdSectionHeader(label: 'O que os alunos podem'),
          const SizedBox(height: AppSpacing.sm),
          _chave(
            'Publicar',
            'Fotos e textos no feed da comunidade.',
            _c.alunosPostam,
            (v) => _mudar(_c.copiaCom(alunosPostam: v)),
          ),
          _chave(
            'Comentar',
            'Comentários nas publicações.',
            _c.comentarios,
            (v) => _mudar(_c.copiaCom(comentarios: v)),
          ),
          _chave(
            'Reagir',
            'Força, parabéns e inspirador.',
            _c.reacoes,
            (v) => _mudar(_c.copiaCom(reacoes: v)),
          ),

          const SizedBox(height: AppSpacing.xl),
          const PhdSectionHeader(label: 'Publicações automáticas'),
          const SizedBox(height: AppSpacing.sm),
          _chave(
            'Conquistas',
            'Publica quando um aluno desbloqueia uma medalha.',
            _c.conquistasAuto,
            (v) => _mudar(_c.copiaCom(conquistasAuto: v)),
          ),
          _chave(
            'Destaques da semana',
            'Reconhece quem teve maior adesão à própria programação.',
            _c.destaquesAtivos,
            (v) => _mudar(_c.copiaCom(destaquesAtivos: v)),
          ),
          if (_c.destaquesAtivos) ...[
            const SizedBox(height: AppSpacing.md),
            _quando(),
          ],

          const SizedBox(height: AppSpacing.xl),
          PhdAviso(
            // A regra mais importante da especificação, dita ao
            // profissional em vez de escondida no código.
            texto: 'Cada aluno decide se as conquistas dele aparecem. Peso, '
                'medidas, fotos de evolução e dados da dieta nunca são '
                'publicados — nem com a comunidade ligada.',
            icone: Icons.lock_outline_rounded,
            cor: AppColors.success,
            corTexto: AppColors.successText,
          ),
        ],
      ],
    );
  }

  Widget _chave(
    String titulo,
    String descricao,
    bool valor,
    ValueChanged<bool> onChanged, {
    bool destaque = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PhdCard(
        accentBar: destaque && valor ? AppColors.accent : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(titulo,
                      style: destaque
                          ? AppText.title(15)
                          : AppText.bodyStrong(13.5)),
                  const SizedBox(height: 2),
                  Text(descricao,
                      style:
                          AppText.caption(11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Switch(
              value: valor,
              activeThumbColor: AppColors.accent,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _quando() {
    const dias = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];

    return PhdCard(
      color: AppColors.surfaceHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quando publicar', style: AppText.caption(12.5)),
          const SizedBox(height: 7),
          PhdFilterBar(
            children: [
              for (var i = 0; i < dias.length; i++)
                PhdFilterChip(
                  label: dias[i],
                  selected: _c.destaquesDia == i + 1,
                  onTap: () => _mudar(_c.copiaCom(destaquesDia: i + 1)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: 16, color: AppColors.textMuted),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text('${_c.destaquesHora}h',
                    style: AppText.number(14)),
              ),
              IconButton(
                onPressed: _c.destaquesHora <= 0
                    ? null
                    : () => _mudar(
                        _c.copiaCom(destaquesHora: _c.destaquesHora - 1)),
                icon: Icon(Icons.remove_rounded,
                    size: 18, color: AppColors.textSecondary),
                tooltip: 'Uma hora antes',
              ),
              IconButton(
                onPressed: _c.destaquesHora >= 23
                    ? null
                    : () => _mudar(
                        _c.copiaCom(destaquesHora: _c.destaquesHora + 1)),
                icon: Icon(Icons.add_rounded,
                    size: 18, color: AppColors.textSecondary),
                tooltip: 'Uma hora depois',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Toda ${_c.diaNome}, às ${_c.destaquesHora}h, sobre a semana '
            'anterior.',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
