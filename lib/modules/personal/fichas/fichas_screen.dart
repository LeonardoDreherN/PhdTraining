import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/ficha_service.dart';

class FichasScreen extends StatefulWidget {
  const FichasScreen({super.key});

  @override
  State<FichasScreen> createState() => _FichasScreenState();
}

class _FichasScreenState extends State<FichasScreen> {
  List<Map<String, dynamic>> _fichas = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (!mounted) return;
    setState(() => _carregando = true);
    try {
      final lista = await FichaService.listar();
      if (mounted) setState(() => _fichas = lista);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Biblioteca de Treinos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _criarFicha(),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _fichas.isEmpty
              ? _buildVazio()
              : _buildLista(),
    );
  }

  Widget _buildLista() {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _carregar,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _fichas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _buildCard(_fichas[i]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> ficha) {
    return GestureDetector(
      onTap: () async {
        await context.push('/fichas/detalhe', extra: ficha);
        _carregar();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.fitness_center, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ficha['nome'],
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (ficha['descricao'] != null && ficha['descricao'].toString().isNotEmpty)
                    Text(ficha['descricao'], style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            PopupMenuButton<String>(
              color: AppColors.surface,
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
              onSelected: (v) => _onMenu(v, ficha),
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'renomear', child: Text('Renomear', style: TextStyle(color: AppColors.textPrimary))),
                const PopupMenuItem(value: 'deletar', child: Text('Excluir', style: TextStyle(color: AppColors.error))),
              ],
            ),
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
          const Text('Nenhuma ficha criada', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _criarFicha,
            icon: const Icon(Icons.add),
            label: const Text('Criar Ficha'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(160, 44)),
          ),
        ],
      ),
    );
  }

  Future<void> _criarFicha() async {
    final nomeController = TextEditingController();
    final descController = TextEditingController();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Nova Ficha', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Ex: Treino A - Peito e Tríceps'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'Descrição (opcional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Criar', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmar == true && nomeController.text.trim().isNotEmpty) {
      await FichaService.criar(
        nome: nomeController.text.trim(),
        descricao: descController.text.trim().isNotEmpty ? descController.text.trim() : null,
      );
      if (mounted) _carregar();
    }
  }

  Future<void> _onMenu(String action, Map<String, dynamic> ficha) async {
    if (action == 'deletar') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Excluir ficha', style: TextStyle(color: AppColors.textPrimary)),
          content: Text('Excluir "${ficha['nome']}"?', style: const TextStyle(color: AppColors.textSecondary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir', style: TextStyle(color: AppColors.error))),
          ],
        ),
      );
      if (ok == true) {
        try {
          await FichaService.deletar(ficha['id']);
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
    } else if (action == 'renomear') {
      final ctrl = TextEditingController(text: ficha['nome']);
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Renomear', style: TextStyle(color: AppColors.textPrimary)),
          content: TextField(controller: ctrl, autofocus: true, style: const TextStyle(color: AppColors.textPrimary)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Salvar', style: TextStyle(color: AppColors.primary))),
          ],
        ),
      );
      if (ok == true && ctrl.text.trim().isNotEmpty) {
        await FichaService.atualizar(ficha['id'], ctrl.text.trim(), ficha['descricao']);
        if (mounted) _carregar();
      }
    }
  }
}
