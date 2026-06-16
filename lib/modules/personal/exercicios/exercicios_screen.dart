import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/exercicio_service.dart';

class ExerciciosScreen extends StatefulWidget {
  const ExerciciosScreen({super.key});

  @override
  State<ExerciciosScreen> createState() => _ExerciciosScreenState();
}

class _ExerciciosScreenState extends State<ExerciciosScreen> {
  List<Map<String, dynamic>> _exercicios = [];
  bool _carregando = true;
  String _grupoSelecionado = 'Todos';
  final _searchController = TextEditingController();
  String _busca = '';

  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    if (!mounted) return;
    setState(() => _carregando = true);
    try {
      if (!_seeded) {
        _seeded = true;
        await ExercicioService.importarPadrao();
      }
      final lista = await ExercicioService.listar(
        grupo: _grupoSelecionado == 'Todos' ? null : _grupoSelecionado,
      );
      if (mounted) setState(() => _exercicios = lista);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_busca.isEmpty) return _exercicios;
    return _exercicios
        .where((e) => e['nome'].toString().toLowerCase().contains(_busca.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Biblioteca de Exercícios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              await context.push('/exercicios/adicionar');
              _carregar();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearch(),
          _buildGruposFiltro(),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _filtrados.isEmpty
                    ? _buildVazio()
                    : _buildLista(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _busca = v),
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Buscar exercício...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
          suffixIcon: _busca.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _busca = '');
                  },
                  child: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildGruposFiltro() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: ExercicioService.grupos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final grupo = ExercicioService.grupos[index];
          final selected = grupo == _grupoSelecionado;
          return GestureDetector(
            onTap: () {
              setState(() => _grupoSelecionado = grupo);
              _carregar();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.divider,
                ),
              ),
              child: Text(
                grupo,
                style: TextStyle(
                  color: selected ? Colors.black : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLista() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _filtrados.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _buildCard(_filtrados[index]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> exercicio) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: exercicio['midia_url'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(exercicio['midia_url'], fit: BoxFit.cover),
                )
              : const Icon(Icons.fitness_center, color: AppColors.primary, size: 24),
        ),
        title: Text(
          exercicio['nome'],
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: exercicio['grupo_muscular'] != null
            ? Text(exercicio['grupo_muscular'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
            : null,
        trailing: PopupMenuButton<String>(
          color: AppColors.surface,
          icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
          onSelected: (v) => _onMenuAction(v, exercicio),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'editar', child: Text('Editar', style: TextStyle(color: AppColors.textPrimary))),
            const PopupMenuItem(value: 'deletar', child: Text('Excluir', style: TextStyle(color: AppColors.error))),
          ],
        ),
      ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.fitness_center, color: AppColors.textHint, size: 64),
          const SizedBox(height: 16),
          Text(
            _busca.isNotEmpty ? 'Nenhum exercício encontrado' : 'Nenhum exercício cadastrado',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
          ),
          if (_busca.isEmpty) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                await context.push('/exercicios/adicionar');
                _carregar();
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar Exercício'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(180, 44)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onMenuAction(String action, Map<String, dynamic> exercicio) async {
    if (action == 'deletar') {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Excluir exercício', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('Deseja excluir "${exercicio['nome']}"?', style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: AppColors.error))),
          ],
        ),
      );
      if (confirmar == true) {
        try {
          await ExercicioService.deletar(exercicio['id'].toString());
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erro ao excluir: $e'), backgroundColor: AppColors.error),
            );
          }
          return;
        }
        if (mounted) _carregar();
      }
    } else if (action == 'editar') {
      await context.push('/exercicios/adicionar', extra: exercicio);
      _carregar();
    }
  }
}
