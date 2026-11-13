import 'package:flutter/material.dart';

import '../../../core/models/equipe.dart';
import '../../../core/services/aluno_service.dart';
import '../../../core/services/equipe_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Libera alunos específicos para um convidado. Devolve `true` se mudou.
Future<bool?> abrirLiberarAlunos(BuildContext context, VinculoEquipe v) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LiberarAlunosSheet(vinculo: v),
  );
}

/// Exceções à regra do plano.
///
/// O normal é o alcance sair do que o aluno contratou — quem está num
/// plano com dieta aparece para o nutricionista sozinho. Esta folha é
/// para o que foge disso: aluno sem assinatura lançada, cortesia, ou um
/// caso que o profissional quer acompanhar mesmo sem o plano prever.
class _LiberarAlunosSheet extends StatefulWidget {
  const _LiberarAlunosSheet({required this.vinculo});

  final VinculoEquipe vinculo;

  @override
  State<_LiberarAlunosSheet> createState() => _LiberarAlunosSheetState();
}

class _LiberarAlunosSheetState extends State<_LiberarAlunosSheet> {
  List<Map<String, dynamic>> _alunos = const [];
  Set<String> _liberados = {};
  bool _carregando = true;
  bool _mudou = false;
  final _ocupado = <String>{};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final (alunos, liberados) = await (
        AlunoService.listar(ativo: true),
        EquipeService.alunosLiberados(widget.vinculo.id),
      ).wait;
      if (!mounted) return;
      setState(() {
        _alunos = alunos;
        _liberados = liberados;
      });
    } catch (_) {
      // Lista vazia mostra o estado certo.
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _alternar(String alunoId) async {
    final estava = _liberados.contains(alunoId);
    setState(() {
      _ocupado.add(alunoId);
      if (estava) {
        _liberados.remove(alunoId);
      } else {
        _liberados.add(alunoId);
      }
    });
    try {
      if (estava) {
        await EquipeService.tirarAluno(widget.vinculo.id, alunoId);
      } else {
        await EquipeService.liberarAluno(widget.vinculo.id, alunoId);
      }
      _mudou = true;
    } catch (e) {
      if (!mounted) return;
      // Desfaz: deixar marcado o que não gravou faria o profissional
      // achar que liberou alguém que continua invisível para o colega.
      setState(() {
        if (estava) {
          _liberados.add(alunoId);
        } else {
          _liberados.remove(alunoId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content: Text('Não consegui salvar: $e', style: AppText.body(13.5)),
        ),
      );
    } finally {
      if (mounted) setState(() => _ocupado.remove(alunoId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.md),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lineStrong,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Liberar alunos', style: AppText.title(18)),
                  const SizedBox(height: 4),
                  Text(
                    'Os alunos cujo plano já inclui '
                    '${widget.vinculo.escopoNome.toLowerCase()} aparecem para '
                    '${widget.vinculo.rotulo} automaticamente. Marque aqui só '
                    'as exceções.',
                    style: AppText.caption(12, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Expanded(child: _lista(scroll)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl,
              ),
              child: SafeArea(
                top: false,
                child: PhdButton(
                  label: 'Pronto',
                  onPressed: () => Navigator.pop(context, _mudou),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lista(ScrollController scroll) {
    if (_carregando) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_alunos.isEmpty) {
      return const PhdEmptyState(
        icon: Icons.people_outline_rounded,
        title: 'Nenhum aluno ativo',
        message: 'Cadastre alunos para poder liberá-los.',
      );
    }

    return ListView.builder(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md,
      ),
      itemCount: _alunos.length,
      itemBuilder: (_, i) {
        final a = _alunos[i];
        final id = a['id'].toString();
        final marcado = _liberados.contains(id);
        final ocupado = _ocupado.contains(id);

        return PhdListRow(
          title: a['nome'] as String? ?? 'Aluno',
          leading: PhdAvatar(
            name: a['nome'] as String? ?? '',
            imageUrl: a['foto_url'] as String?,
            size: 34,
          ),
          trailing: ocupado
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  marcado
                      ? Icons.check_circle_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 22,
                  color: marcado ? AppColors.success : AppColors.textMuted,
                ),
          onTap: ocupado ? null : () => _alternar(id),
        );
      },
    );
  }
}
