import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/arquivo_service.dart';

class ArquivosScreen extends StatefulWidget {
  final String alunoId;
  final String alunoNome;
  const ArquivosScreen({super.key, required this.alunoId, required this.alunoNome});

  @override
  State<ArquivosScreen> createState() => _ArquivosScreenState();
}

class _ArquivosScreenState extends State<ArquivosScreen> {
  List<Map<String, dynamic>> _arquivos = [];
  bool _carregando = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final lista = await ArquivoService.listar(widget.alunoId);
      setState(() => _arquivos = lista);
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    setState(() => _enviando = true);
    try {
      await ArquivoService.adicionar(
        alunoId: widget.alunoId,
        arquivo: result.files.first,
      );
      await _carregar();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arquivo enviado!'), backgroundColor: AppColors.active),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _deletar(Map<String, dynamic> arquivo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Excluir arquivo', style: TextStyle(color: Colors.white)),
        content: Text('Deseja excluir "${arquivo['nome']}"?',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await ArquivoService.deletar(arquivo['id'].toString(), arquivo['arquivo_url']);
      await _carregar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Arquivos', style: TextStyle(fontSize: 16)),
            Text(widget.alunoNome,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _enviando ? null : _upload,
        backgroundColor: AppColors.primary,
        icon: _enviando
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.upload_rounded),
        label: Text(_enviando ? 'Enviando...' : 'Enviar arquivo'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _arquivos.isEmpty
              ? _buildVazio()
              : RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: _carregar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _arquivos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildCard(_arquivos[i]),
                  ),
                ),
    );
  }

  Widget _buildVazio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(Icons.folder_open_outlined,
                  color: AppColors.primary, size: 44),
            ),
            const SizedBox(height: 24),
            const Text('Nenhum arquivo ainda',
                style: TextStyle(
                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Envie planos alimentares, PDFs,\nplanilhas e qualquer documento',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> arquivo) {
    final nome = arquivo['nome'] as String? ?? '';
    final tipo = arquivo['tipo_mime'] as String? ?? '';
    final tamanho = arquivo['tamanho_bytes'] as int? ?? 0;
    final criadoEm = arquivo['criado_em'] as String? ?? '';
    final dt = criadoEm.isNotEmpty ? DateTime.parse(criadoEm).toLocal() : null;
    final dataStr = dt != null
        ? '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _iconColor(tipo).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconData(tipo), color: _iconColor(tipo), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  '${_formatarTamanho(tamanho)}${dataStr.isNotEmpty ? '  ·  $dataStr' : ''}',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () async {
              final url = arquivo['arquivo_url'] as String?;
              if (url != null) {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            icon: const Icon(Icons.download_rounded, color: AppColors.primary, size: 24),
            tooltip: 'Baixar',
          ),
          IconButton(
            onPressed: () => _deletar(arquivo),
            icon: Icon(Icons.delete_outline_rounded,
                color: AppColors.error.withValues(alpha: 0.8), size: 22),
            tooltip: 'Excluir',
          ),
        ],
      ),
    );
  }

  IconData _iconData(String tipo) {
    if (tipo.contains('pdf')) return Icons.picture_as_pdf_rounded;
    if (tipo.contains('image')) return Icons.image_rounded;
    if (tipo.contains('word') || tipo.contains('document')) return Icons.description_rounded;
    if (tipo.contains('excel') || tipo.contains('sheet')) return Icons.table_chart_rounded;
    return Icons.insert_drive_file_rounded;
  }

  Color _iconColor(String tipo) {
    if (tipo.contains('pdf')) return const Color(0xFFE53935);
    if (tipo.contains('image')) return const Color(0xFF1E88E5);
    if (tipo.contains('word') || tipo.contains('document')) return const Color(0xFF1565C0);
    if (tipo.contains('excel') || tipo.contains('sheet')) return const Color(0xFF2E7D32);
    return AppColors.primary;
  }

  String _formatarTamanho(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
