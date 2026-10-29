import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/diario.dart';
import '../../../core/services/diario_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Abre a folha de registro e devolve a aderência escolhida quando salvou
/// (ou `null` se o aluno desistiu). A tela usa a resposta para marcar a
/// refeição do plano como feita.
Future<({bool salvou, Aderencia? aderencia})?> registrarRefeicao(
  BuildContext context, {
  required String alunoId,
  required DateTime dia,
  String? refeicaoId,
  String? titulo,
}) {
  return showModalBottomSheet<({bool salvou, Aderencia? aderencia})>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _FolhaRefeicao(
      alunoId: alunoId,
      dia: dia,
      refeicaoId: refeicaoId,
      titulo: titulo,
    ),
  );
}

class _FolhaRefeicao extends StatefulWidget {
  const _FolhaRefeicao({
    required this.alunoId,
    required this.dia,
    this.refeicaoId,
    this.titulo,
  });

  final String alunoId;
  final DateTime dia;
  final String? refeicaoId;
  final String? titulo;

  @override
  State<_FolhaRefeicao> createState() => _FolhaRefeicaoState();
}

class _FolhaRefeicaoState extends State<_FolhaRefeicao> {
  final _titulo = TextEditingController();
  final _descricao = TextEditingController();
  XFile? _foto;
  Uint8List? _previa;

  /// Refeição do plano começa em "segui": é o caso comum, e um toque a
  /// menos é o que faz o aluno registrar todo dia.
  late Aderencia? _aderencia = widget.refeicaoId == null ? null : Aderencia.seguiu;
  bool _salvando = false;
  String? _erro;

  bool get _doPlano => widget.refeicaoId != null;

  @override
  void dispose() {
    _titulo.dispose();
    _descricao.dispose();
    super.dispose();
  }

  Future<void> _escolherFoto(ImageSource origem) async {
    try {
      // 1440 px e qualidade 80: nítida para o profissional ver o prato,
      // leve para subir no 4G da rua.
      final f = await ImagePicker().pickImage(source: origem, maxWidth: 1440, imageQuality: 80);
      if (f == null) return;
      final bytes = await f.readAsBytes();
      if (mounted) {
        setState(() {
          _foto = f;
          _previa = bytes;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não consegui abrir a foto: $e');
    }
  }

  Future<void> _salvar() async {
    final titulo = _doPlano ? widget.titulo! : _titulo.text.trim();
    if (titulo.isEmpty) {
      setState(() => _erro = 'Diga o que foi — "Lanche da tarde", por exemplo.');
      return;
    }
    if (_foto == null && _descricao.text.trim().isEmpty && !_doPlano) {
      setState(() => _erro = 'Tire uma foto ou escreva o que comeu.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await DiarioService.registrar(
        alunoId: widget.alunoId,
        dia: widget.dia,
        titulo: titulo,
        refeicaoId: widget.refeicaoId,
        descricao: _descricao.text,
        aderencia: _aderencia,
        foto: _foto,
      );
      if (mounted) Navigator.pop(context, (salvou: true, aderencia: _aderencia));
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _doPlano ? 'Registrar ${widget.titulo!.toLowerCase()}' : 'Algo fora do plano',
              style: AppText.title(19),
            ),
            const SizedBox(height: 4),
            Text(
              _doPlano
                  ? 'Uma foto do prato ajuda seu profissional a ajustar o plano.'
                  : 'Sem culpa: registrar é o que permite ajustar o plano à sua rotina.',
              style: AppText.caption(13),
            ),
            const SizedBox(height: AppSpacing.lg),
            _areaFoto(),
            if (_doPlano) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('COMO FOI?', style: AppText.label()),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final a in Aderencia.values)
                    PhdFilterChip(
                      label: a.rotulo,
                      selected: _aderencia == a,
                      tone: switch (a) {
                        Aderencia.seguiu => PhdTone.success,
                        Aderencia.parecido => PhdTone.accent,
                        Aderencia.fora => PhdTone.warning,
                      },
                      onTap: () => setState(() => _aderencia = a),
                    ),
                ],
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.lg),
              PhdField(
                controller: _titulo,
                label: 'O que foi?',
                hint: 'Lanche da tarde, happy hour…',
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            PhdField(
              controller: _descricao,
              label: _doPlano ? 'Observação (opcional)' : 'O que você comeu',
              hint: _doPlano ? 'Troquei o arroz por batata…' : '2 pães de queijo e um café',
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            if (_erro != null) ...[
              const SizedBox(height: AppSpacing.md),
              PhdAviso(texto: _erro!),
            ],
            const SizedBox(height: AppSpacing.lg),
            PhdButton(
              label: 'Salvar no diário',
              icon: Icons.check_rounded,
              loading: _salvando,
              onPressed: _salvar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _areaFoto() {
    if (_previa != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: AppRadius.rXl,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.memory(_previa!, fit: BoxFit.cover, width: double.infinity),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Remover foto',
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                onPressed: () => setState(() {
                  _foto = null;
                  _previa = null;
                }),
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Câmera só onde existe: no navegador, "tirar foto" abre o mesmo
        // seletor de arquivo que a galeria.
        if (!kIsWeb) ...[
          Expanded(child: _botaoFoto(Icons.photo_camera_rounded, 'Tirar foto', ImageSource.camera)),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: _botaoFoto(
            Icons.photo_library_rounded,
            kIsWeb ? 'Escolher foto' : 'Da galeria',
            ImageSource.gallery,
          ),
        ),
      ],
    );
  }

  Widget _botaoFoto(IconData icone, String rotulo, ImageSource origem) {
    return Material(
      color: AppColors.surfaceHigh,
      borderRadius: AppRadius.rXl,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _escolherFoto(origem),
        child: SizedBox(
          height: 96,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 26, color: AppColors.accent),
              const SizedBox(height: 6),
              Text(rotulo, style: AppText.bodyStrong(13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Peso
// ══════════════════════════════════════════════════════════════

/// Folha de peso. Devolve o peso salvo, ou `null` se cancelou.
Future<double?> registrarPeso(
  BuildContext context, {
  required String alunoId,
  double? ultimo,
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    builder: (_) => _FolhaPeso(alunoId: alunoId, ultimo: ultimo),
  );
}

class _FolhaPeso extends StatefulWidget {
  const _FolhaPeso({required this.alunoId, this.ultimo});

  final String alunoId;
  final double? ultimo;

  @override
  State<_FolhaPeso> createState() => _FolhaPesoState();
}

class _FolhaPesoState extends State<_FolhaPeso> {
  // Começa no último peso: quem se pesa toda semana muda dois dígitos, não
  // digita tudo de novo.
  late double _peso = widget.ultimo ?? 70;
  late final _campo = TextEditingController(text: _texto(_peso));
  bool _salvando = false;
  String? _erro;

  static String _texto(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _somar(double d) {
    setState(() {
      _peso = double.parse((_peso + d).clamp(20, 400).toStringAsFixed(1));
      _campo.text = _texto(_peso);
    });
  }

  Future<void> _salvar() async {
    final v = double.tryParse(_campo.text.replaceAll(',', '.'));
    if (v == null || v < 20 || v > 400) {
      setState(() => _erro = 'Digite um peso entre 20 e 400 kg.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await DiarioService.registrarPeso(widget.alunoId, v);
      if (mounted) Navigator.pop(context, v);
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
        AppSpacing.xl, 0, AppSpacing.xl,
        AppSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registrar peso', style: AppText.title(19)),
          const SizedBox(height: 4),
          Text(
            'Pese-se de manhã, em jejum e depois do banheiro: é o horário '
            'que dá para comparar de uma semana para a outra.',
            style: AppText.caption(13),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              _passo(Icons.remove_rounded, () => _somar(-0.1)),
              Expanded(
                child: TextField(
                  controller: _campo,
                  textAlign: TextAlign.center,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))],
                  style: AppText.display(44),
                  decoration: InputDecoration(
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    suffixText: 'kg',
                    suffixStyle: AppText.caption(16),
                  ),
                ),
              ),
              _passo(Icons.add_rounded, () => _somar(0.1)),
            ],
          ),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.md),
            PhdAviso(texto: _erro!),
          ],
          const SizedBox(height: AppSpacing.xl),
          PhdButton(label: 'Salvar peso', icon: Icons.check_rounded, loading: _salvando, onPressed: _salvar),
        ],
      ),
    );
  }

  Widget _passo(IconData icone, VoidCallback onTap) => Material(
        color: AppColors.surfaceHigh,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox.square(
            dimension: 48,
            child: Icon(icone, color: AppColors.textPrimary),
          ),
        ),
      );
}
