import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/aluno_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Os destinos do menu do aluno. A home continua sendo o resumo do dia; cada
/// função tem a própria aba, com a tela inteira para ela.
class _Aba {
  const _Aba(this.rota, this.icone, this.iconeCheio, this.rotulo);
  final String rota;
  final IconData icone;
  final IconData iconeCheio;
  final String rotulo;
}

const _abas = [
  _Aba('/aluno/home', Icons.home_outlined, Icons.home_rounded, 'Início'),
  _Aba('/aluno/treinos', Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'Treino'),
  _Aba('/aluno/nutricao', Icons.restaurant_menu_outlined, Icons.restaurant_menu_rounded, 'Dieta'),
  _Aba('/aluno/progresso', Icons.insights_outlined, Icons.insights_rounded, 'Progresso'),
  _Aba('/aluno/perfil', Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
];

/// Barra de baixo do app do aluno — o mesmo desenho da do personal.
class AlunoShell extends StatelessWidget {
  const AlunoShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final rota = GoRouterState.of(context).uri.path;
    var atual = _abas.indexWhere((a) => rota.startsWith(a.rota));
    if (atual < 0) atual = 0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                for (var i = 0; i < _abas.length; i++)
                  Expanded(
                    child: _Botao(
                      aba: _abas[i],
                      selecionado: i == atual,
                      // `go`: as abas trocam a tela, não empilham.
                      onTap: () => context.go(_abas[i].rota),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Botao extends StatelessWidget {
  const _Botao({required this.aba, required this.selecionado, required this.onTap});

  final _Aba aba;
  final bool selecionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cor = selecionado ? AppColors.accent : AppColors.textMuted;
    return Semantics(
      button: true,
      selected: selecionado,
      label: aba.rotulo,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selecionado ? 1 : 0.94,
              duration: AppDuration.fast,
              child: Icon(selecionado ? aba.iconeCheio : aba.icone, size: 22, color: cor),
            ),
            const SizedBox(height: AppSpacing.xs + 1),
            Text(
              aba.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: selecionado ? AppText.bodyStrong(10.5, color: cor) : AppText.caption(10.5, color: cor),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carrega o cadastro do aluno logado e entrega o id para a aba.
///
/// O resultado fica guardado por usuário: trocar de aba não refaz a
/// consulta, e outra conta logada no mesmo aparelho não herda o cadastro.
class ComAluno extends StatefulWidget {
  const ComAluno({super.key, required this.builder});

  final Widget Function(String alunoId) builder;

  static final _cache = <String, Future<Map<String, dynamic>?>>{};

  @override
  State<ComAluno> createState() => _ComAlunoState();
}

class _ComAlunoState extends State<ComAluno> {
  late Future<Map<String, dynamic>?> _futuro = _buscar();

  Future<Map<String, dynamic>?> _buscar({bool deNovo = false}) {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (deNovo) ComAluno._cache.remove(uid);
    return ComAluno._cache.putIfAbsent(uid, () async {
      try {
        return await AlunoService.doUsuarioAtual();
      } catch (e) {
        // Falha não fica guardada: a próxima tentativa consulta de novo.
        ComAluno._cache.remove(uid);
        rethrow;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _futuro,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
          );
        }
        final id = snap.data?['id']?.toString();
        if (snap.hasError || id == null) {
          return Scaffold(
            backgroundColor: AppColors.bg,
            body: SafeArea(
              child: PhdEmptyState(
                icon: snap.hasError ? Icons.cloud_off_rounded : Icons.link_off_rounded,
                title: snap.hasError ? 'Não consegui carregar' : 'Conta ainda não vinculada',
                message: snap.hasError
                    ? '${snap.error}'
                    : 'Não encontrei seu cadastro de aluno. Peça ao seu personal para conferir o '
                        'e-mail que ele cadastrou para você.',
                actionLabel: 'Tentar de novo',
                onAction: () => setState(() => _futuro = _buscar(deNovo: true)),
              ),
            ),
          );
        }
        return widget.builder(id);
      },
    );
  }
}
