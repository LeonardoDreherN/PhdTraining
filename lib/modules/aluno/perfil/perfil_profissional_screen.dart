import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/cupom.dart';
import '../../../core/services/cupom_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../core/widgets/widgets.dart';

/// O profissional visto pelo aluno: bio, formações, cupons e contato.
///
/// Serve também para o profissional indicado num cupom — aí sem cupons
/// (são do outro profissional) e com o WhatsApp já dizendo de onde o
/// aluno veio.
class PerfilProfissionalScreen extends StatefulWidget {
  const PerfilProfissionalScreen({
    super.key,
    required this.profissionalId,
    this.comCupons = true,
    this.indicadoPor,
    this.onChat,
  });

  final String profissionalId;

  /// Mostra os cupons deste profissional. Falso para um indicado: o aluno
  /// não lê os cupons de outro tenant.
  final bool comCupons;

  /// Nome de quem indicou, para a mensagem do WhatsApp.
  final String? indicadoPor;

  /// Abre o chat do app. Nulo = sem chat (indicado, ou chat desligado).
  final VoidCallback? onChat;

  @override
  State<PerfilProfissionalScreen> createState() => _PerfilProfissionalScreenState();
}

class _PerfilProfissionalScreenState extends State<PerfilProfissionalScreen> {
  PerfilPublico? _perfil;
  List<Cupom> _cupons = const [];
  bool _carregando = true;
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
      final (perfil, cupons) = await (
        CupomService.perfilPublico(widget.profissionalId),
        widget.comCupons
            ? CupomService.doProfissional(widget.profissionalId).catchError((_) => <Cupom>[])
            : Future.value(<Cupom>[]),
      ).wait;
      if (mounted) {
        setState(() {
          _perfil = perfil;
          _cupons = cupons;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _abrir(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Não consegui abrir o link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(backgroundColor: AppColors.bg, surfaceTintColor: Colors.transparent),
      body: _carregando
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _perfil == null
              ? PhdEmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Perfil indisponível',
                  message: _erro == null
                      ? 'Este perfil não está disponível para você.'
                      : 'Não consegui carregar o perfil.\n\n$_erro',
                  actionLabel: 'Tentar de novo',
                  onAction: _carregar,
                )
              : _corpo(_perfil!),
    );
  }

  Widget _corpo(PerfilPublico p) {
    final zap = linkWhatsApp(
      p.whatsapp,
      mensagem: widget.indicadoPor == null
          ? null
          : 'Olá! Vim pela indicação de ${widget.indicadoPor} no PHD.',
    );
    final bio = p.bio?.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge),
      children: [
        Center(child: PhdAvatar(name: p.nomeExibicao, imageUrl: p.avatarUrl, size: 96)),
        const SizedBox(height: AppSpacing.md),
        Text(p.nomeExibicao, textAlign: TextAlign.center, style: AppText.title(20)),
        if (p.registros != null) ...[
          const SizedBox(height: 2),
          Text(p.registros!, textAlign: TextAlign.center, style: AppText.caption(12.5)),
        ],
        if (widget.indicadoPor != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Center(child: PhdStatusChip(label: 'Indicação de ${widget.indicadoPor}', tone: PhdTone.accent)),
        ],
        if (zap != null || widget.onChat != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              if (widget.onChat != null)
                Expanded(
                  child: PhdButton(
                    label: 'Mensagem',
                    icon: Icons.forum_rounded,
                    size: PhdButtonSize.medium,
                    onPressed: widget.onChat,
                  ),
                ),
              if (widget.onChat != null && zap != null) const SizedBox(width: AppSpacing.sm),
              if (zap != null)
                Expanded(
                  child: PhdButton(
                    label: 'WhatsApp',
                    icon: Icons.chat_rounded,
                    size: PhdButtonSize.medium,
                    variant: widget.onChat == null ? PhdButtonVariant.primary : PhdButtonVariant.secondary,
                    onPressed: () => _abrir(zap),
                  ),
                ),
            ],
          ),
        ],
        if (bio != null && bio.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          const PhdSectionHeader(label: 'Sobre'),
          const SizedBox(height: AppSpacing.md),
          Text(bio, style: AppText.body(14.5, color: AppColors.textSecondary)),
        ],
        if (p.formacoes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          const PhdSectionHeader(label: 'Formações'),
          const SizedBox(height: AppSpacing.md),
          PhdCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Column(
              children: [
                for (final f in p.formacoes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.school_outlined, size: 18, color: AppColors.accent),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(child: Text(f, style: AppText.body(14))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (_cupons.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          PhdSectionHeader(label: 'Cupons de desconto', trailing: '${_cupons.length}', trailingColor: AppColors.textMuted),
          const SizedBox(height: AppSpacing.md),
          for (final c in _cupons) ...[
            _cartaoCupom(c, p),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
        if ((bio == null || bio.isEmpty) && p.formacoes.isEmpty && _cupons.isEmpty) ...[
          const SizedBox(height: AppSpacing.xxl),
          Text(
            '${p.nomeExibicao.split(' ').first} ainda não escreveu a bio.',
            textAlign: TextAlign.center,
            style: AppText.caption(13, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _cartaoCupom(Cupom c, PerfilPublico dono) {
    final link = c.link == null ? null : Uri.tryParse(c.link!.startsWith('http') ? c.link! : 'https://${c.link}');
    final v = c.validoAte;
    return PhdCard(
      accentBar: AppColors.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_offer_outlined, size: 18, color: AppColors.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text(c.titulo, style: AppText.bodyStrong(14.5))),
            ],
          ),
          if (c.descricao != null) ...[
            const SizedBox(height: 4),
            Text(c.descricao!, style: AppText.body(13.5, color: AppColors.textSecondary)),
          ],
          if (v != null) ...[
            const SizedBox(height: 4),
            Text(
              'Válido até ${v.day.toString().padLeft(2, '0')}/${v.month.toString().padLeft(2, '0')}/${v.year}',
              style: AppText.caption(11.5, color: AppColors.textMuted),
            ),
          ],
          if (c.codigo != null) ...[
            const SizedBox(height: AppSpacing.md),
            Material(
              color: AppColors.surfaceHigh,
              borderRadius: AppRadius.rMd,
              child: InkWell(
                borderRadius: AppRadius.rMd,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: c.codigo!));
                  if (mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Código ${c.codigo} copiado')));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                  child: Row(
                    children: [
                      Expanded(child: Text(c.codigo!, style: AppText.number(16))),
                      Icon(Icons.copy_rounded, size: 17, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text('Copiar', style: AppText.bodyStrong(12.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ],
          if (c.indicadoId != null || link != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                if (c.indicadoId != null)
                  TextButton.icon(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PerfilProfissionalScreen(
                          profissionalId: c.indicadoId!,
                          comCupons: false,
                          indicadoPor: dono.nomeExibicao,
                        ),
                      ),
                    ),
                    icon: Icon(Icons.person_search_outlined, size: 17, color: AppColors.accent),
                    label: Text('Conhecer ${c.indicadoNome ?? 'o profissional'}',
                        style: AppText.bodyStrong(13, color: AppColors.accent)),
                  ),
                if (link != null)
                  TextButton.icon(
                    onPressed: () => _abrir(link),
                    icon: Icon(Icons.open_in_new_rounded, size: 17, color: AppColors.accent),
                    label: Text('Usar o cupom', style: AppText.bodyStrong(13, color: AppColors.accent)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
