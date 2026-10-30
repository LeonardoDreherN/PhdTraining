import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/exercicio_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import 'exercicio_detalhe.dart';

/// Biblioteca de exercícios: catálogo visual, em grade.
///
/// A imagem vem primeiro porque é por ela que o personal reconhece o
/// exercício; o selo de play diz de relance quais já têm vídeo — e um toque
/// abre o vídeo tocando, para conferir.
class ExerciciosScreen extends StatefulWidget {
  const ExerciciosScreen({super.key});

  @override
  State<ExerciciosScreen> createState() => _ExerciciosScreenState();
}

class _ExerciciosScreenState extends State<ExerciciosScreen> {
  List<Map<String, dynamic>> _exercicios = [];
  bool _carregando = true;
  Object? _erro;
  String _grupo = 'Todos';
  bool _soComVideo = false;
  final _busca = TextEditingController();
  bool _importou = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _busca.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      // Na primeira abertura, garante os exercícios-padrão na biblioteca
      // (só insere os que ainda não existem).
      if (!_importou) {
        _importou = true;
        await ExercicioService.importarPadrao();
      }
      final lista = await ExercicioService.listar();
      if (mounted) setState(() => _exercicios = lista);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  bool _temVideo(Map<String, dynamic> e) => ((e['video_url'] as String?) ?? '').trim().isNotEmpty;

  List<Map<String, dynamic>> get _filtrados {
    final termo = _busca.text.trim().toLowerCase();
    return _exercicios.where((e) {
      if (_grupo != 'Todos' && e['grupo_muscular'] != _grupo) return false;
      if (_soComVideo && !_temVideo(e)) return false;
      return termo.isEmpty || (e['nome'] as String? ?? '').toLowerCase().contains(termo);
    }).toList();
  }

  Future<void> _novo([Map<String, dynamic>? existente]) async {
    await context.push('/exercicios/adicionar', extra: existente);
    _carregar();
  }

  Future<void> _abrir(Map<String, dynamic> e) async {
    final acao = await abrirExercicio(context, e);
    if (!mounted) return;
    if (acao == 'editar') return _novo(e);
    if (acao == 'excluir') return _excluir(e);
  }

  Future<void> _excluir(Map<String, dynamic> e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Excluir "${e['nome']}"?', style: AppText.title(17)),
        content: Text('Ele sai da biblioteca. Se estiver em alguma ficha, o banco não deixa excluir.',
            style: AppText.body(13.5, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: AppText.bodyStrong(13.5, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: AppText.bodyStrong(13.5, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ExercicioService.deletar(e['id'].toString());
      _carregar();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('"${e['nome']}" está em uma ficha. Tire das fichas antes de excluir.',
              style: AppText.body(13.5)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;
    final comVideo = _exercicios.where(_temVideo).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Exercícios', style: AppText.title(17)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.lg),
            child: PhdButton(
              label: 'Novo',
              icon: Icons.add_rounded,
              size: PhdButtonSize.small,
              expand: false,
              onPressed: _novo,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: AppSpacing.screen,
            child: TextField(
              controller: _busca,
              onChanged: (_) => setState(() {}),
              style: AppText.body(14.5),
              decoration: InputDecoration(
                hintText: 'Buscar entre ${_exercicios.length} exercícios',
                prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted, size: 19),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: AppSpacing.screen,
              children: [
                PhdFilterChip(
                  label: 'Com vídeo',
                  count: comVideo,
                  selected: _soComVideo,
                  tone: PhdTone.success,
                  onTap: () => setState(() => _soComVideo = !_soComVideo),
                ),
                const SizedBox(width: AppSpacing.sm),
                for (final g in ExercicioService.grupos) ...[
                  PhdFilterChip(label: g, selected: _grupo == g, onTap: () => setState(() => _grupo = g)),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: _carregando
                ? Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _erro != null
                    ? PhdEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Não consegui carregar',
                        message: '$_erro',
                        actionLabel: 'Tentar de novo',
                        onAction: _carregar,
                      )
                    : lista.isEmpty
                        ? PhdEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'Nada por aqui',
                            message: 'Nenhum exercício com esse filtro.',
                            actionLabel: 'Cadastrar exercício',
                            onAction: _novo,
                          )
                        : RefreshIndicator(
                            color: AppColors.accent,
                            onRefresh: _carregar,
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.huge),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: AppSpacing.sm,
                                mainAxisSpacing: AppSpacing.sm,
                                childAspectRatio: 0.92,
                              ),
                              itemCount: lista.length,
                              itemBuilder: (_, i) => _cartao(lista[i]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _cartao(Map<String, dynamic> e) {
    return PhdCard(
      onTap: () => _abrir(e),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PhdMiniaturaExercicio(
            imagemUrl: e['midia_url'] as String?,
            temVideo: _temVideo(e),
            tamanho: null,
            raio: AppRadius.rLg,
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(e['nome'] as String? ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(13.5)),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(e['grupo_muscular'] as String? ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(11.5)),
          ),
        ],
      ),
    );
  }
}
