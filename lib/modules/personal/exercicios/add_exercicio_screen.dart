import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/exercicio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/navegacao.dart';
import '../../../core/widgets/widgets.dart';

/// Cadastro e edição de exercício.
///
/// O vídeo, depois de enviado, aparece tocando aqui mesmo: o personal
/// confere o corte e o enquadramento antes de salvar, em vez de descobrir
/// pelo aluno que o vídeo saiu de lado ou sem o movimento inteiro.
class AddExercicioScreen extends StatefulWidget {
  final Map<String, dynamic>? exercicio;
  const AddExercicioScreen({super.key, this.exercicio});

  @override
  State<AddExercicioScreen> createState() => _AddExercicioScreenState();
}

class _AddExercicioScreenState extends State<AddExercicioScreen> {
  late final _nome = TextEditingController(text: widget.exercicio?['nome'] as String?);
  late final _equip = TextEditingController(text: widget.exercicio?['equipamento'] as String?);
  late final _como = TextEditingController(text: widget.exercicio?['descricao'] as String?);
  late String? _grupo = widget.exercicio?['grupo_muscular'] as String?;
  late String? _imagem = widget.exercicio?['midia_url'] as String?;
  late String? _video = widget.exercicio?['video_url'] as String?;

  bool _enviandoImagem = false;
  bool _enviandoVideo = false;
  bool _salvando = false;
  String? _erro;

  bool get _editando => widget.exercicio != null;
  bool get _ocupado => _enviandoImagem || _enviandoVideo || _salvando;

  @override
  void dispose() {
    _nome.dispose();
    _equip.dispose();
    _como.dispose();
    super.dispose();
  }

  Future<void> _escolherImagem() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82, maxWidth: 1200);
    if (f == null) return;
    setState(() {
      _enviandoImagem = true;
      _erro = null;
    });
    try {
      final url = await ExercicioService.uploadImagem(f.name, await f.readAsBytes());
      if (mounted) setState(() => _imagem = url);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não consegui enviar a imagem: $e');
    } finally {
      if (mounted) setState(() => _enviandoImagem = false);
    }
  }

  Future<void> _escolherVideo() async {
    final f = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
    if (f == null) return;
    setState(() {
      _enviandoVideo = true;
      _erro = null;
    });
    try {
      final url = await ExercicioService.uploadVideo(f.name, await f.readAsBytes());
      if (mounted) setState(() => _video = url);
    } catch (e) {
      if (mounted) setState(() => _erro = 'Não consegui enviar o vídeo: $e');
    } finally {
      if (mounted) setState(() => _enviandoVideo = false);
    }
  }

  Future<void> _salvar() async {
    final nome = _nome.text.trim();
    if (nome.isEmpty) return setState(() => _erro = 'Dê um nome ao exercício.');
    if (_grupo == null) return setState(() => _erro = 'Escolha o grupo muscular.');
    setState(() {
      _salvando = true;
      _erro = null;
    });
    String? limpo(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    try {
      if (_editando) {
        await ExercicioService.atualizar(widget.exercicio!['id'].toString(), {
          'nome': nome,
          'grupo_muscular': _grupo,
          'equipamento': limpo(_equip),
          'descricao': limpo(_como),
          'midia_url': _imagem,
          'video_url': _video,
        });
      } else {
        await ExercicioService.cadastrar(
          nome: nome,
          grupoMuscular: _grupo!,
          equipamento: limpo(_equip),
          descricao: limpo(_como),
          midiaUrl: _imagem,
          videoUrl: _video,
        );
      }
      if (mounted) context.voltar(senaoPara: '/exercicios');
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text(_editando ? 'Editar exercício' : 'Novo exercício', style: AppText.title(17)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
        children: [
          Text('VÍDEO DA EXECUÇÃO', style: AppText.label()),
          const SizedBox(height: AppSpacing.sm),
          _secaoVideo(),
          const SizedBox(height: AppSpacing.xl),
          Text('IMAGEM DE CAPA', style: AppText.label()),
          const SizedBox(height: AppSpacing.sm),
          _secaoImagem(),
          const SizedBox(height: AppSpacing.xl),
          PhdField(
            controller: _nome,
            label: 'Nome',
            hint: 'Supino reto com barra',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Grupo muscular', style: AppText.caption(12.5)),
          const SizedBox(height: 7),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final g in ExercicioService.grupos.where((g) => g != 'Todos'))
                PhdFilterChip(label: g, selected: _grupo == g, onTap: () => setState(() => _grupo = g)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdField(
            controller: _equip,
            label: 'Equipamento (opcional)',
            hint: 'Barra, banco reto',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdField(
            controller: _como,
            label: 'Como executar (opcional)',
            hint: 'Deite no banco, desça a barra até o peito…',
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
          ),
          if (_erro != null) ...[
            const SizedBox(height: AppSpacing.lg),
            PhdAviso(texto: _erro!),
          ],
          const SizedBox(height: AppSpacing.xl),
          PhdButton(
            label: _editando ? 'Salvar alterações' : 'Cadastrar exercício',
            icon: Icons.check_rounded,
            loading: _salvando,
            onPressed: _ocupado ? null : _salvar,
          ),
        ],
      ),
    );
  }

  Widget _secaoVideo() {
    if (_enviandoVideo) {
      return _enviando('Enviando o vídeo… vídeos grandes levam um pouco.');
    }
    final v = _video;
    if (v == null || v.isEmpty) {
      return _cartaoEscolher(
        icone: Icons.video_call_rounded,
        titulo: 'Adicionar vídeo',
        apoio: 'MP4 ou MOV, até 2 minutos. O aluno assiste antes de cada série.',
        onTap: _escolherVideo,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PhdVideo(url: v),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: AppColors.successText),
            const SizedBox(width: 6),
            Expanded(child: Text('É assim que o aluno vai ver.', style: AppText.caption(12.5))),
            TextButton(
              onPressed: _escolherVideo,
              child: Text('Trocar', style: AppText.bodyStrong(13, color: AppColors.accent)),
            ),
            TextButton(
              onPressed: () => setState(() => _video = null),
              child: Text('Remover', style: AppText.bodyStrong(13, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _secaoImagem() {
    if (_enviandoImagem) return _enviando('Enviando a imagem…');
    final i = _imagem;
    if (i == null || i.isEmpty) {
      return _cartaoEscolher(
        icone: Icons.add_photo_alternate_outlined,
        titulo: 'Adicionar imagem',
        apoio: 'Aparece na biblioteca e na ficha. Pode ser um GIF.',
        onTap: _escolherImagem,
      );
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: AppRadius.rLg,
          child: Image.network(i, width: 120, height: 90, fit: BoxFit.cover),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton(
                onPressed: _escolherImagem,
                child: Text('Trocar imagem', style: AppText.bodyStrong(13, color: AppColors.accent)),
              ),
              TextButton(
                onPressed: () => setState(() => _imagem = null),
                child: Text('Remover', style: AppText.bodyStrong(13, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cartaoEscolher({
    required IconData icone,
    required String titulo,
    required String apoio,
    required VoidCallback onTap,
  }) {
    return PhdCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: AppColors.tint(AppColors.accent), borderRadius: BorderRadius.circular(16)),
            child: Icon(icone, color: AppColors.accent, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppText.bodyStrong(14.5)),
                const SizedBox(height: 2),
                Text(apoio, style: AppText.caption(12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _enviando(String texto) => PhdCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(texto, style: AppText.body(13.5))),
          ],
        ),
      );
}
