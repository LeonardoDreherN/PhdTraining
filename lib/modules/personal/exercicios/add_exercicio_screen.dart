import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/exercicio_service.dart';
import '../home/widgets/phd_logo.dart';

class AddExercicioScreen extends StatefulWidget {
  final Map<String, dynamic>? exercicio;
  const AddExercicioScreen({super.key, this.exercicio});

  @override
  State<AddExercicioScreen> createState() => _AddExercicioScreenState();
}

class _AddExercicioScreenState extends State<AddExercicioScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _descricaoController = TextEditingController();
  String? _grupoSelecionado;
  String? _midiaUrl;
  bool _salvando = false;

  bool get _editando => widget.exercicio != null;

  @override
  void initState() {
    super.initState();
    if (_editando) {
      _nomeController.text = widget.exercicio!['nome'] ?? '';
      _descricaoController.text = widget.exercicio!['descricao'] ?? '';
      _grupoSelecionado = widget.exercicio!['grupo_muscular'];
      _midiaUrl = widget.exercicio!['midia_url'];
    }
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      if (_editando) {
        await ExercicioService.atualizar(widget.exercicio!['id'], {
          'nome': _nomeController.text.trim(),
          'grupo_muscular': _grupoSelecionado,
          'descricao': _descricaoController.text.trim(),
          'midia_url': _midiaUrl,
        });
      } else {
        await ExercicioService.cadastrar(
          nome: _nomeController.text.trim(),
          grupoMuscular: _grupoSelecionado ?? '',
          descricao: _descricaoController.text.trim(),
          midiaUrl: _midiaUrl,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_editando ? 'Exercício atualizado!' : 'Exercício cadastrado!'),
            backgroundColor: AppColors.active,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Row(children: [
              Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 18),
              Text('voltar', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
        ),
        leadingWidth: 80,
        title: const PHDLogo(fontSize: 26),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _editando ? 'Editar Exercício' : 'Novo Exercício',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              _buildImagePicker(),
              const SizedBox(height: 20),
              _buildLabel('Nome do Exercício'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nomeController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(hintText: 'Ex: Supino Reto'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Grupo Muscular'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _grupoSelecionado,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(hintText: 'Selecione o grupo'),
                icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
                validator: (v) => v == null ? 'Campo obrigatório' : null,
                onChanged: (v) => setState(() => _grupoSelecionado = v),
                items: ExercicioService.grupos
                    .where((g) => g != 'Todos')
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g, style: const TextStyle(color: AppColors.textPrimary)),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              _buildLabel('Descrição / Execução (opcional)'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descricaoController,
                maxLines: 4,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Descreva como executar o exercício...',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_editando ? 'Salvar Alterações' : 'Cadastrar Exercício'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w500));
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: _midiaUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(_midiaUrl!, fit: BoxFit.cover),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary, size: 40),
                  SizedBox(height: 8),
                  Text('Adicionar foto / GIF', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _salvando = true);
      try {
        final url = await ExercicioService.uploadImagem(picked.path, bytes);
        if (mounted) setState(() => _midiaUrl = url);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erro ao fazer upload: $e'), backgroundColor: AppColors.error),
          );
        }
      } finally {
        if (mounted) setState(() => _salvando = false);
      }
    }
  }
}
