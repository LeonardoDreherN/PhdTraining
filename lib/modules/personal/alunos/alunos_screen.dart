import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/aluno_service.dart';

class AlunosScreen extends StatefulWidget {
  const AlunosScreen({super.key});

  @override
  State<AlunosScreen> createState() => _AlunosScreenState();
}

class _AlunosScreenState extends State<AlunosScreen> {
  List<Map<String, dynamic>> _alunos = [];
  bool _carregando = true;
  bool _mostrarAtivos = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await AlunoService.listar(ativo: _mostrarAtivos);
      setState(() => _alunos = lista);
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alunos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context.push('/alunos/adicionar');
              _carregar();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFiltro(),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _alunos.isEmpty
                    ? _buildVazio()
                    : _buildLista(),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltro() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildFiltroBtn('Ativos', true),
          const SizedBox(width: 10),
          _buildFiltroBtn('Inativos', false),
        ],
      ),
    );
  }

  Widget _buildFiltroBtn(String label, bool isAtivo) {
    final selected = _mostrarAtivos == isAtivo;
    final color = isAtivo ? AppColors.active : AppColors.inactive;
    return GestureDetector(
      onTap: () {
        setState(() => _mostrarAtivos = isAtivo);
        _carregar();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha:0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? color : AppColors.textSecondary,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildLista() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _alunos.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildCard(_alunos[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> aluno) {
    return GestureDetector(
      onTap: () => context.push('/alunos/perfil', extra: aluno),
      child: _buildCardContent(aluno),
    );
  }

  Widget _buildCardContent(Map<String, dynamic> aluno) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          _buildAvatar(aluno),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  aluno['nome'],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  aluno['email'] ?? '',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                if (aluno['whatsapp'] != null && aluno['whatsapp'].isNotEmpty)
                  Text(
                    aluno['whatsapp'],
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.surface,
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (v) => _onMenuAction(v, aluno),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'toggle', child: Text('Ativar/Inativar', style: TextStyle(color: AppColors.textPrimary))),
              const PopupMenuItem(value: 'deletar', child: Text('Excluir', style: TextStyle(color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline, color: AppColors.textHint, size: 64),
          const SizedBox(height: 16),
          Text(
            'Nenhum aluno ${_mostrarAtivos ? 'ativo' : 'inativo'}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              await context.push('/alunos/adicionar');
              _carregar();
            },
            icon: const Icon(Icons.add),
            label: const Text('Cadastrar Aluno'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(180, 44)),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(Map<String, dynamic> aluno) {
    final fotoUrl = aluno['foto_url'] as String?;
    final inicial = aluno['nome'].toString().substring(0, 1).toUpperCase();
    final placeholder = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(inicial,
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
    );
    if (fotoUrl == null) return placeholder;
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: fotoUrl,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        placeholder: (_, __) => placeholder,
        errorWidget: (_, __, ___) => placeholder,
      ),
    );
  }

  Future<void> _onMenuAction(String action, Map<String, dynamic> aluno) async {
    if (action == 'toggle') {
      await AlunoService.alterarStatus(aluno['id'], !(aluno['ativo'] as bool));
      _carregar();
    } else if (action == 'deletar') {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Excluir aluno', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('Deseja excluir ${aluno['nome']}?', style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: AppColors.error))),
          ],
        ),
      );
      if (confirmar == true) {
        await AlunoService.deletar(aluno['id']);
        _carregar();
      }
    }
  }
}
