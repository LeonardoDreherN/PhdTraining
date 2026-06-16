import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/aluno_service.dart';
import '../home/widgets/phd_logo.dart';
import 'widgets/credentials_modal.dart';

class AddAlunoScreen extends StatefulWidget {
  const AddAlunoScreen({super.key});

  @override
  State<AddAlunoScreen> createState() => _AddAlunoScreenState();
}

class _AddAlunoScreenState extends State<AddAlunoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _dataNascimentoController = TextEditingController();

  String? _generoSelecionado;
  String? _grupoSelecionado;
  bool _enviarInfoAcesso = false;
  String _anamneseTipo = 'nenhuma'; // 'nenhuma' | 'parq' | 'padrao'
  bool _bloquearInadimplente = false;
  bool _salvando = false;

  final List<String> _generos = ['Masculino', 'Feminino', 'Outro'];
  final List<String> _grupos = ['Presencial', 'Online'];

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _dataNascimentoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final dataSemBarra = _dataNascimentoController.text.replaceAll('/', '');
      final senha = dataSemBarra.isNotEmpty ? dataSemBarra : _gerarSenhaAleatoria();

      await AlunoService.cadastrar(
        nome: _nomeController.text.trim(),
        email: _emailController.text.trim(),
        senha: senha,
        whatsapp: _whatsappController.text.trim(),
        dataNascimento: _converterData(_dataNascimentoController.text),
        genero: _generoSelecionado,
        grupo: _grupoSelecionado,
        anamneseTipo: _anamneseTipo,
      );
      if (mounted) _showCredentialsModal();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao cadastrar: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  void _showCredentialsModal() {
    final dataSemBarra = _dataNascimentoController.text.replaceAll('/', '');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CredentialsModal(
        email: _emailController.text,
        senhaGerada: dataSemBarra.isNotEmpty ? dataSemBarra : null,
        onClose: () {
          Navigator.of(context).pop();
          context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.adicionarAluno,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              _buildLabel(AppStrings.nomeCompleto),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _nomeController,
                hint: 'Nome completo do aluno',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              _buildLabel(AppStrings.email),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _emailController,
                hint: 'email@exemplo.com',
                keyboardType: TextInputType.emailAddress,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
                  if (!v.contains('@')) return 'E-mail inválido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel(AppStrings.selecioneGrupo),
              const SizedBox(height: 6),
              _buildDropdown(
                hint: 'Selecione um grupo',
                value: _grupoSelecionado,
                items: _grupos,
                onChanged: (v) => setState(() => _grupoSelecionado = v),
              ),
              const SizedBox(height: 16),
              _buildLabel(AppStrings.dataNascimento),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _dataNascimentoController,
                hint: 'DD/MM/AAAA',
                keyboardType: TextInputType.datetime,
                onTap: () => _selectDate(),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              _buildLabel(AppStrings.whatsapp),
              const SizedBox(height: 6),
              _buildTextField(
                controller: _whatsappController,
                hint: '(00) 00000-0000',
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildLabel(AppStrings.genero),
              const SizedBox(height: 6),
              _buildDropdown(
                hint: 'Selecione o gênero',
                value: _generoSelecionado,
                items: _generos,
                onChanged: (v) => setState(() => _generoSelecionado = v),
              ),
              const SizedBox(height: 8),
              _buildToggleRow(
                label: AppStrings.enviarInfoAcesso,
                value: _enviarInfoAcesso,
                onChanged: (v) => setState(() => _enviarInfoAcesso = v),
              ),
              _buildAnamneseSeletor(),
              _buildToggleRow(
                label: AppStrings.bloquearInadimplente,
                value: _bloquearInadimplente,
                onChanged: (v) => setState(() => _bloquearInadimplente = v),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _salvando ? null : _salvar,
                child: _salvando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(AppStrings.salvar),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: const Padding(
          padding: EdgeInsets.only(left: 12),
          child: Row(
            children: [
              Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 18),
              Text(AppStrings.voltar, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
      leadingWidth: 80,
      title: const PHDLogo(fontSize: 26),
      centerTitle: true,
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(hintText: hint),
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      onChanged: onChanged,
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(hintText: hint),
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary),
      items: items
          .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: const TextStyle(color: AppColors.textPrimary)),
              ))
          .toList(),
    );
  }

  Widget _buildAnamneseSeletor() {
    const opcoes = [('nenhuma', 'Não'), ('parq', 'PAR-Q'), ('padrao', 'Padrão')];
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.enviarAnamnese,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 10),
          Row(
            children: opcoes.map((o) {
              final sel = _anamneseTipo == o.$1;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _anamneseTipo = o.$1),
                  child: Container(
                    margin: EdgeInsets.only(right: o.$1 != 'padrao' ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? AppColors.primary : AppColors.inputBorder,
                      ),
                    ),
                    child: Text(
                      o.$2,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sel ? Colors.black : AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  String _gerarSenhaAleatoria() {
    final rand = Random();
    return List.generate(6, (_) => rand.nextInt(10)).join();
  }

  String? _converterData(String data) {
    if (data.isEmpty) return null;
    final partes = data.split('/');
    if (partes.length != 3) return null;
    return '${partes[2]}-${partes[1]}-${partes[0]}';
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.primary,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      _dataNascimentoController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }
}
