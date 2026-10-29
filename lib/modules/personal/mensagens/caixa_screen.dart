import 'package:flutter/material.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../chat/chat_screen.dart';

/// Abre a conversa com um aluno. Usado pela caixa e pelo perfil do aluno.
Future<void> abrirConversa(BuildContext context, Map<String, dynamic> aluno) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      builder: (_) => ChatScreen(
        alunoId: aluno['id'] as String,
        titulo: (aluno['nome'] as String?)?.trim() ?? 'Aluno',
        subtitulo: 'Aluno',
        avatarUrl: aluno['foto_url'] as String?,
      ),
    ),
  );
}

/// Caixa de mensagens do profissional: uma linha por aluno, quem falou por
/// último em cima, com o número de não lidas.
class CaixaMensagensScreen extends StatefulWidget {
  const CaixaMensagensScreen({super.key});

  @override
  State<CaixaMensagensScreen> createState() => _CaixaMensagensScreenState();
}

class _CaixaMensagensScreenState extends State<CaixaMensagensScreen> {
  List<ConversaResumo> _conversas = const [];
  bool _carregando = true;
  Object? _erro;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final c = await ChatService.caixa();
      if (mounted) setState(() => _conversas = c);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final termo = _busca.trim().toLowerCase();
    final lista = termo.isEmpty
        ? _conversas
        : _conversas
            .where((c) => (c.aluno['nome'] as String? ?? '').toLowerCase().contains(termo))
            .toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Mensagens', style: AppText.title(16)),
      ),
      body: _carregando
          ? Center(child: CircularProgressIndicator(color: AppColors.accent))
          : _erro != null
              ? PhdEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Não consegui carregar',
                  message: '$_erro',
                  actionLabel: 'Tentar de novo',
                  onAction: _carregar,
                )
              : RefreshIndicator(
                  color: AppColors.accent,
                  onRefresh: _carregar,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
                    children: [
                      TextField(
                        onChanged: (v) => setState(() => _busca = v),
                        style: AppText.body(14.5),
                        decoration: InputDecoration(
                          hintText: 'Buscar aluno',
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (lista.isEmpty)
                        const PhdEmptyState(
                          icon: Icons.forum_outlined,
                          title: 'Nenhuma conversa',
                          message: 'Os alunos ativos aparecem aqui para você mandar mensagem.',
                        ),
                      PhdCard(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            for (final (i, c) in lista.indexed) ...[
                              if (i > 0) Divider(height: 1, color: AppColors.line, indent: 72),
                              _linha(c),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _linha(ConversaResumo c) {
    final nome = (c.aluno['nome'] as String?)?.trim() ?? 'Aluno';
    final u = c.ultima;
    final temNova = c.naoLidas > 0;

    return InkWell(
      onTap: () async {
        await abrirConversa(context, c.aluno);
        if (mounted) _carregar();
      },
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            PhdAvatar(name: nome, imageUrl: c.aluno['foto_url'] as String?, size: 46),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nome, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong(14.5)),
                  const SizedBox(height: 2),
                  Text(
                    u == null ? 'Toque para mandar a primeira mensagem' : u.texto,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: temNova
                        ? AppText.bodyStrong(13, color: AppColors.textPrimary)
                        : AppText.caption(13, color: u == null ? AppColors.textMuted : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (u != null)
                  Text(_quando(u.criadoEm),
                      style: AppText.caption(11, color: temNova ? AppColors.accent : AppColors.textMuted)),
                if (temNova) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: AppRadius.rPill),
                    child: Text('${c.naoLidas}',
                        textAlign: TextAlign.center,
                        style: AppText.bodyStrong(11, color: AppColors.onAccent)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _quando(DateTime d) {
    final agora = DateTime.now();
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final dia = DateTime(d.year, d.month, d.day);
    final dif = hoje.difference(dia).inDays;
    if (dif == 0) return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (dif == 1) return 'ontem';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}

/// Ícone de mensagens com o selo de não lidas, para o cabeçalho.
class BotaoMensagens extends StatefulWidget {
  const BotaoMensagens({super.key, this.aoAbrir});

  /// Por padrão abre a caixa do profissional. O aluno passa a própria
  /// conversa.
  final Future<void> Function(BuildContext)? aoAbrir;

  @override
  State<BotaoMensagens> createState() => _BotaoMensagensState();
}

class _BotaoMensagensState extends State<BotaoMensagens> {
  int _naoLidas = 0;

  @override
  void initState() {
    super.initState();
    _contar();
  }

  Future<void> _contar() async {
    final m = await ChatService.naoLidas();
    if (mounted) setState(() => _naoLidas = m.values.fold(0, (s, n) => s + n));
  }

  @override
  Widget build(BuildContext context) {
    return PhdIconButton(
      icon: Icons.chat_bubble_outline_rounded,
      tooltip: _naoLidas == 0 ? 'Mensagens' : 'Mensagens — $_naoLidas não lidas',
      badge: _naoLidas > 0,
      onPressed: () async {
        final abrir = widget.aoAbrir;
        if (abrir != null) {
          await abrir(context);
        } else {
          await Navigator.push<void>(
            context,
            MaterialPageRoute(builder: (_) => const CaixaMensagensScreen()),
          );
        }
        if (mounted) _contar();
      },
    );
  }
}
