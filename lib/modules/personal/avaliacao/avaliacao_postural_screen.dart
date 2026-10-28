import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/avaliacao.dart';
import '../../../core/services/avaliacao_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/avaliacao_calculos.dart';
import '../../../core/utils/datas.dart';
import '../../../core/widgets/widgets.dart';
import 'avaliacao_widgets.dart';

/// Avaliação postural: quatro fotos com grade de alinhamento e o checklist
/// de desvios por região.
///
/// As fotos são salvas assim que enviadas — perder uma foto porque a
/// pessoa saiu da tela antes de tocar em "Salvar" faria o aluno posar de
/// novo. O checklist e as observações esperam o botão.
class AvaliacaoPosturalScreen extends StatefulWidget {
  const AvaliacaoPosturalScreen({super.key, required this.aluno});

  final Map<String, dynamic> aluno;

  @override
  State<AvaliacaoPosturalScreen> createState() => _AvaliacaoPosturalScreenState();
}

class _AvaliacaoPosturalScreenState extends State<AvaliacaoPosturalScreen> {
  late final DateTime _data = dataDaSessao(widget.aluno);
  String get _alunoId => widget.aluno['id'] as String;

  bool _carregando = true;
  bool _salvando = false;
  bool _alterado = false;
  String? _erro;

  /// Caminho no bucket, por vista. É o que vai para o banco.
  final Map<VistaPostural, String> _caminhos = {};

  /// O que exibir: URL assinada de foto que já estava salva...
  final Map<VistaPostural, String> _urls = {};

  /// ...ou os bytes da foto recém-escolhida, para não esperar assinar.
  final Map<VistaPostural, Uint8List> _locais = {};
  final Set<VistaPostural> _enviando = {};

  Map<String, GrauDesvio> _desvios = {};
  final _obs = TextEditingController();
  bool _grade = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final r = await AvaliacaoService.carregarPostural(_alunoId, _data);
      if (!mounted) return;
      setState(() {
        final linha = r.linha;
        if (linha != null) {
          for (final v in VistaPostural.values) {
            final c = linha[v.coluna] as String?;
            if (c != null && c.isNotEmpty) _caminhos[v] = c;
            final u = r.urls[v.coluna];
            if (u != null) _urls[v] = u;
          }
          final bruto = linha['desvios'];
          if (bruto is Map) {
            _desvios = {
              for (final e in bruto.entries)
                if (GrauDesvio.porId(e.value) != null) e.key as String: GrauDesvio.porId(e.value)!,
            };
          }
          _obs.text = linha['observacoes'] as String? ?? '';
        }
      });
    } catch (e) {
      if (mounted) setState(() => _erro = '$e');
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Map<String, dynamic> get _payload => {
        'aluno_id': _alunoId,
        'data_avaliacao': Datas.iso(_data),
        for (final v in VistaPostural.values) v.coluna: _caminhos[v],
        'desvios': {for (final e in _desvios.entries) e.key: e.value.id},
        'observacoes': _obs.text.trim().isEmpty ? null : _obs.text.trim(),
      };

  Future<void> _escolherFoto(VistaPostural vista) async {
    ImageSource? origem = ImageSource.gallery;
    if (!kIsWeb) {
      origem = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: AppColors.surface,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: AppColors.textPrimary),
                title: Text('Tirar foto', style: AppText.body(14)),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.textPrimary),
                title: Text('Escolher da galeria', style: AppText.body(14)),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
    }
    if (origem == null) return;

    final foto = await ImagePicker().pickImage(source: origem, maxWidth: 1600, imageQuality: 85);
    if (foto == null) return;

    final bytes = await foto.readAsBytes();
    final antigo = _caminhos[vista];
    setState(() {
      _locais[vista] = bytes;
      _enviando.add(vista);
    });
    try {
      final caminho = await AvaliacaoService.enviarFotoPostural(
          alunoId: _alunoId, data: _data, vista: vista, foto: foto);
      _caminhos[vista] = caminho;
      await AvaliacaoService.salvarPostural(_payload);
      if (antigo != null) AvaliacaoService.removerFoto(antigo);
    } catch (e) {
      _locais.remove(vista);
      if (mounted) avisar(context, 'A foto não subiu: $e', erro: true);
    } finally {
      if (mounted) setState(() => _enviando.remove(vista));
    }
  }

  Future<void> _removerFoto(VistaPostural vista) async {
    final caminho = _caminhos.remove(vista);
    setState(() {
      _urls.remove(vista);
      _locais.remove(vista);
    });
    try {
      await AvaliacaoService.salvarPostural(_payload);
      if (caminho != null) AvaliacaoService.removerFoto(caminho);
    } catch (e) {
      if (mounted) avisar(context, 'Não removeu: $e', erro: true);
    }
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    try {
      await AvaliacaoService.salvarPostural(_payload);
      if (!mounted) return;
      avisar(context, 'Avaliação postural salva');
      Navigator.pop(context);
    } catch (e) {
      if (mounted) avisar(context, 'Não salvou: $e', erro: true);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _marcar(String chave, GrauDesvio grau) {
    setState(() {
      // Tocar no grau que já está marcado desmarca.
      if (_desvios[chave] == grau) {
        _desvios = {..._desvios}..remove(chave);
      } else {
        _desvios = {..._desvios, chave: grau};
      }
      _alterado = true;
    });
  }

  ImageProvider? _imagem(VistaPostural v) {
    final local = _locais[v];
    if (local != null) return MemoryImage(local);
    final url = _urls[v];
    if (url != null) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_alterado,
      onPopInvokedWithResult: (saiu, _) async {
        if (saiu) return;
        final sair = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: Text('Sair sem salvar o checklist?', style: AppText.title(17)),
            content: Text('As fotos já estão salvas. Os desvios marcados e as observações, não.',
                style: AppText.body(14, color: AppColors.textSecondary)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Continuar aqui')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sair')),
            ],
          ),
        );
        if (sair == true && context.mounted) {
          setState(() => _alterado = false);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: appBarAvaliacao(
          widget.aluno['nome'] as String? ?? 'Aluno',
          'Postural · ${Datas.curta(_data)}',
          actions: [
            IconButton(
              tooltip: _grade ? 'Esconder grade' : 'Mostrar grade',
              icon: Icon(_grade ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                  color: _grade ? AppColors.accent : AppColors.textSecondary),
              onPressed: () => setState(() => _grade = !_grade),
            ),
          ],
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
            : _erro != null
                ? PhdEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Não deu para abrir',
                    message: _erro!,
                    actionLabel: 'Tentar de novo',
                    onAction: () {
                      setState(() {
                        _carregando = true;
                        _erro = null;
                      });
                      _carregar();
                    },
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
                    children: [
                      const PhdSectionHeader(label: 'Fotos'),
                      const SizedBox(height: 4),
                      Text(
                        'Aluno de frente para a câmera, pés paralelos, braços soltos. '
                        'Câmera na altura do umbigo, a uns 3 metros.',
                        style: AppText.caption(12, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GradeDupla(children: [
                        for (final v in VistaPostural.values) _slot(v),
                      ]),
                      const SizedBox(height: AppSpacing.xxl),
                      PhdSectionHeader(
                        label: 'Desvios',
                        trailing: _desvios.isEmpty ? null : '${_desvios.length} marcados',
                        trailingColor: AppColors.textMuted,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final r in regioesPosturais) ...[
                        _regiao(r),
                        const SizedBox(height: AppSpacing.sm + 2),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      PhdField(
                        label: 'Observações',
                        controller: _obs,
                        hint: 'Compensações, dores relatadas, encaminhamento…',
                        onChanged: (_) {
                          if (!_alterado) setState(() => _alterado = true);
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PhdButton(
                        label: 'Salvar avaliação postural',
                        loading: _salvando,
                        onPressed: _salvando || _enviando.isNotEmpty ? null : _salvar,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _slot(VistaPostural v) {
    final img = _imagem(v);
    final enviando = _enviando.contains(v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: Material(
            color: AppColors.surface,
            borderRadius: AppRadius.rXl,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enviando
                  ? null
                  : img == null
                      ? () => _escolherFoto(v)
                      : () => _ampliar(v),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (img != null)
                    Image(image: img, fit: BoxFit.cover)
                  else
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo_outlined, color: AppColors.textMuted, size: 26),
                        const SizedBox(height: AppSpacing.sm),
                        Text('Adicionar', style: AppText.caption(12)),
                      ],
                    ),
                  if (_grade) const IgnorePointer(child: CustomPaint(painter: GradePostural())),
                  if (enviando)
                    const ColoredBox(
                      color: Color(0x99000000),
                      child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(v.rotulo, style: AppText.bodyStrong(12.5)),
      ],
    );
  }

  void _ampliar(VistaPostural v) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FotoAmpliada(
          titulo: v.rotulo,
          imagem: _imagem(v)!,
          gradeInicial: _grade,
          onTrocar: () => _escolherFoto(v),
          onRemover: () => _removerFoto(v),
        ),
      ),
    );
  }

  Widget _regiao(RegiaoPostural r) {
    final marcados = r.desvios.where((d) => _desvios.containsKey(d.chave)).length;
    return PhdCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: marcados > 0,
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
          iconColor: AppColors.textSecondary,
          collapsedIconColor: AppColors.textMuted,
          title: Text(r.nome, style: AppText.bodyStrong(14.5)),
          subtitle: Text(
            marcados == 0 ? 'Sem desvios' : '$marcados ${marcados == 1 ? 'marcado' : 'marcados'}',
            style: AppText.caption(11.5, color: marcados == 0 ? AppColors.textMuted : AppColors.warningText),
          ),
          children: [
            for (final d in r.desvios)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(child: Text(d.nome, style: AppText.body(13.5))),
                    for (final g in GrauDesvio.values) ...[
                      const SizedBox(width: 6),
                      _ChipGrau(
                        grau: g,
                        marcado: _desvios[d.chave] == g,
                        onTap: () => _marcar(d.chave, g),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChipGrau extends StatelessWidget {
  const _ChipGrau({required this.grau, required this.marcado, required this.onTap});
  final GrauDesvio grau;
  final bool marcado;
  final VoidCallback onTap;

  PhdTone get _tom => switch (grau) {
        GrauDesvio.leve => PhdTone.accent,
        GrauDesvio.moderado => PhdTone.warning,
        GrauDesvio.acentuado => PhdTone.danger,
      };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: marcado,
      label: grau.rotulo,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.rPill,
        child: Container(
          height: 32,
          width: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: marcado ? _tom.solid : Colors.transparent,
            borderRadius: AppRadius.rPill,
            border: Border.all(color: marcado ? Colors.transparent : AppColors.line),
          ),
          // Uma letra só: três rótulos inteiros não cabem ao lado do nome
          // do desvio num celular de 360px. O nome completo vai no leitor
          // de tela e na legenda do PDF.
          child: Text(
            grau.rotulo[0],
            style: AppText.bodyStrong(12, color: marcado ? AppColors.onAccent : AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// Grade de simetria: fio de prumo no centro e linhas a cada oitavo.
///
/// O fio fica em acento porque é a referência que o personal procura —
/// cabeça, esterno, umbigo e o meio dos pés deveriam estar sobre ele.
class GradePostural extends CustomPainter {
  const GradePostural();

  @override
  void paint(Canvas canvas, Size size) {
    final fina = Paint()
      ..color = const Color(0x55FFFFFF)
      ..strokeWidth = 0.6;
    for (var i = 1; i < 8; i++) {
      final x = size.width * i / 8;
      final y = size.height * i / 8;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), fina);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), fina);
    }
    final prumo = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), prumo);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FotoAmpliada extends StatefulWidget {
  const _FotoAmpliada({
    required this.titulo,
    required this.imagem,
    required this.gradeInicial,
    required this.onTrocar,
    required this.onRemover,
  });

  final String titulo;
  final ImageProvider imagem;
  final bool gradeInicial;
  final VoidCallback onTrocar;
  final VoidCallback onRemover;

  @override
  State<_FotoAmpliada> createState() => _FotoAmpliadaState();
}

class _FotoAmpliadaState extends State<_FotoAmpliada> {
  late bool _grade = widget.gradeInicial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        surfaceTintColor: Colors.transparent,
        title: Text(widget.titulo, style: AppText.title(17)),
        actions: [
          IconButton(
            tooltip: _grade ? 'Esconder grade' : 'Mostrar grade',
            icon: Icon(_grade ? Icons.grid_on_rounded : Icons.grid_off_rounded,
                color: _grade ? AppColors.accent : AppColors.textSecondary),
            onPressed: () => setState(() => _grade = !_grade),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image(image: widget.imagem, fit: BoxFit.cover),
                      if (_grade) const CustomPaint(painter: GradePostural()),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: PhdButton(
                      label: 'Remover',
                      variant: PhdButtonVariant.danger,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onRemover();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PhdButton(
                      label: 'Trocar foto',
                      variant: PhdButtonVariant.secondary,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onTrocar();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
