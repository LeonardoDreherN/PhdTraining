import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/app_tokens.dart';

/// Player do vídeo de execução de um exercício.
///
/// Toque pausa e retoma; a barra embaixo mostra o tempo e deixa arrastar.
/// Começa mudo e em loop por padrão: é demonstração de movimento, assistida
/// na academia, onde som alto incomoda e o personal quer ver de novo.
class PhdVideo extends StatefulWidget {
  const PhdVideo({
    super.key,
    required this.url,
    this.autoplay = true,
    this.altura = 240,
  });

  final String url;
  final bool autoplay;

  /// Altura enquanto carrega ou quando falha. Tocando, vale a proporção do
  /// vídeo (limitada a esta altura × 1,6, para vídeo em pé não engolir a
  /// tela).
  final double altura;

  @override
  State<PhdVideo> createState() => _PhdVideoState();
}

class _PhdVideoState extends State<PhdVideo> {
  VideoPlayerController? _c;
  bool _falhou = false;
  bool _mudo = true;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void didUpdateWidget(PhdVideo old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _c?.dispose();
      _c = null;
      _falhou = false;
      _iniciar();
    }
  }

  void _iniciar() {
    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;
    c.addListener(_mudou);
    c.initialize().then((_) async {
      if (!mounted) return;
      await c.setLooping(true);
      await c.setVolume(0);
      if (widget.autoplay) await c.play();
      if (mounted) setState(() {});
    }).catchError((Object _) {
      // Formato que o aparelho não toca ou link quebrado: avisa no lugar
      // do player em vez de deixar um quadro preto girando para sempre.
      if (mounted) setState(() => _falhou = true);
    });
  }

  void _mudou() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _c?.removeListener(_mudou);
    _c?.dispose();
    super.dispose();
  }

  static String _tempo(Duration d) =>
      '${d.inMinutes.toString().padLeft(1, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_falhou) {
      return _caixa(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 30),
          const SizedBox(height: AppSpacing.sm),
          Text('Não consegui tocar este vídeo', style: AppText.bodyStrong(13, color: Colors.white)),
          const SizedBox(height: 2),
          Text('Envie em MP4 para funcionar em todos os aparelhos.',
              style: AppText.caption(11.5, color: Colors.white70)),
        ],
      ));
    }
    if (c == null || !c.value.isInitialized) {
      return _caixa(const CircularProgressIndicator(color: Colors.white));
    }

    final v = c.value;
    return ClipRRect(
      borderRadius: AppRadius.rXl,
      child: ColoredBox(
        // Preto nos dois temas: é tela de vídeo.
        color: Colors.black,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.altura * 1.6),
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => v.isPlaying ? c.pause() : c.play(),
                child: Center(
                  child: AspectRatio(aspectRatio: v.aspectRatio, child: VideoPlayer(c)),
                ),
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  opacity: v.isPlaying ? 0 : 1,
                  duration: AppDuration.normal,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.lg, AppSpacing.xs, AppSpacing.xs),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(_tempo(v.position), style: AppText.caption(11, color: Colors.white)),
                      Expanded(
                        child: VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 10),
                          colors: VideoProgressColors(
                            playedColor: AppColors.accent,
                            bufferedColor: Colors.white30,
                            backgroundColor: Colors.white12,
                          ),
                        ),
                      ),
                      Text(_tempo(v.duration), style: AppText.caption(11, color: Colors.white)),
                      IconButton(
                        tooltip: _mudo ? 'Ligar o som' : 'Tirar o som',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(_mudo ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () {
                          setState(() => _mudo = !_mudo);
                          c.setVolume(_mudo ? 0 : 1);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _caixa(Widget filho) => ClipRRect(
        borderRadius: AppRadius.rXl,
        child: Container(
          height: widget.altura,
          width: double.infinity,
          color: Colors.black,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: filho,
        ),
      );
}

/// Miniatura de exercício: a imagem quando há, senão um ícone; com selo de
/// "play" quando o exercício tem vídeo. A mesma peça na biblioteca, no
/// seletor e no montador da ficha.
class PhdMiniaturaExercicio extends StatelessWidget {
  const PhdMiniaturaExercicio({
    super.key,
    this.imagemUrl,
    this.temVideo = false,
    this.tamanho = 48,
    this.raio,
  });

  final String? imagemUrl;
  final bool temVideo;

  /// `null` = ocupa a largura disponível (cartão da grade, 4:3).
  final double? tamanho;
  final BorderRadius? raio;

  @override
  Widget build(BuildContext context) {
    final r = raio ?? (tamanho == null ? AppRadius.rLg : BorderRadius.circular((tamanho ?? 48) * 0.28));
    final icone = Icon(Icons.fitness_center_rounded,
        color: AppColors.accent, size: tamanho == null ? 30 : (tamanho! * 0.42));

    Widget base = Container(
      width: tamanho,
      height: tamanho,
      decoration: BoxDecoration(color: AppColors.tint(AppColors.accent), borderRadius: r),
      clipBehavior: Clip.antiAlias,
      child: imagemUrl == null || imagemUrl!.isEmpty
          ? Center(child: icone)
          : Image.network(imagemUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: icone)),
    );
    if (tamanho == null) base = AspectRatio(aspectRatio: 4 / 3, child: base);
    if (!temVideo) return base;

    final selo = tamanho == null ? 28.0 : (tamanho! * 0.4).clamp(16.0, 24.0);
    return Stack(
      children: [
        base,
        Positioned(
          right: 4,
          bottom: 4,
          child: Container(
            width: selo,
            height: selo,
            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
            child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: selo * 0.7),
          ),
        ),
      ],
    );
  }
}
