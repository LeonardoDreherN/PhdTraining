import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';

/// Avatar com iniciais como padrão.
///
/// A maioria dos alunos nunca envia foto, então as iniciais não são o estado
/// de erro — são o estado normal, e precisam ficar bem. Foto é o bônus.
class PhdAvatar extends StatelessWidget {
  const PhdAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 42,
    this.ringColor,
  });

  final String name;
  final String? imageUrl;
  final double size;

  /// Anel de destaque — usado para marcar quem treinou hoje.
  final Color? ringColor;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final inner = size - (ringColor != null ? 4 : 0);

    Widget content = Container(
      width: inner,
      height: inner,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      // `Image.network`, e não `CachedNetworkImage`: no web o cache dele
      // busca os bytes por XHR, que depende de CORS e do armazenamento do
      // navegador. A foto aparecia na primeira pintura e sumia na releitura
      // do cache, caindo no fallback — era a "foto preta". O navegador já
      // guarda a imagem no cache HTTP, então aqui não se perde nada.
      child: imageUrl == null || imageUrl!.isEmpty
          ? _initialsText(inner)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              width: inner,
              height: inner,
              // Iniciais enquanto carrega e se falhar: foto é o bônus, as
              // iniciais são o estado normal.
              loadingBuilder: (_, filho, progresso) =>
                  progresso == null ? filho : _initialsText(inner),
              errorBuilder: (_, __, ___) => _initialsText(inner),
            ),
    );

    if (ringColor != null) {
      content = Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ringColor!, width: 2),
        ),
        child: content,
      );
    }

    return Semantics(label: name, child: ExcludeSemantics(child: content));
  }

  Widget _initialsText(double box) => Text(
        _initials,
        style: AppText.number(box * 0.32, weight: FontWeight.w700),
      );
}
