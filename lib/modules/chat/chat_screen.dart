import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/models/conversa.dart';
import '../../core/services/chat_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/widgets.dart';

/// A conversa entre o aluno e o profissional. A mesma tela serve aos dois:
/// "minha" mensagem é a de quem está logado, venha de que lado vier.
///
/// Mensagem nova chega pelo Realtime, sem recarregar. A que o próprio
/// usuário manda entra na hora (com o retorno do insert) e o eco do
/// Realtime é descartado pelo id.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.alunoId,
    required this.titulo,
    this.subtitulo,
    this.avatarUrl,
  });

  final String alunoId;
  final String titulo;
  final String? subtitulo;
  final String? avatarUrl;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _campo = TextEditingController();
  final _rolagem = ScrollController();
  List<Mensagem> _mensagens = [];
  bool _carregando = true;
  Object? _erro;
  bool _enviando = false;
  RealtimeChannel? _canal;

  String get _eu => Supabase.instance.client.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _carregar();
    try {
      _canal = ChatService.ouvir(widget.alunoId, _chegou);
    } catch (_) {
      // Sem Realtime (rede ruim, demo): a conversa funciona, só não
      // atualiza sozinha — puxar para baixo recarrega.
    }
  }

  @override
  void dispose() {
    final c = _canal;
    if (c != null) ChatService.pararDeOuvir(c);
    _campo.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final m = await ChatService.mensagens(widget.alunoId);
      if (!mounted) return;
      setState(() {
        _mensagens = m;
        _erro = null;
      });
      ChatService.marcarLidas(widget.alunoId);
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _chegou(Mensagem m) {
    if (!mounted || _mensagens.any((x) => x.id == m.id)) return;
    setState(() => _mensagens = [..._mensagens, m]);
    if (m.autorId != _eu) ChatService.marcarLidas(widget.alunoId);
  }

  Future<void> _enviar() async {
    final texto = _campo.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    try {
      final m = await ChatService.enviar(widget.alunoId, texto);
      _campo.clear();
      _chegou(m);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não consegui enviar: $e', style: AppText.body(13.5))),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            PhdAvatar(name: widget.titulo, imageUrl: widget.avatarUrl, size: 36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.titulo, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.title(15.5)),
                  if (widget.subtitulo != null)
                    Text(widget.subtitulo!, style: AppText.caption(11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(child: _lista()),
          _barraDeEnvio(),
        ],
      ),
    );
  }

  Widget _lista() {
    if (_carregando) return Center(child: CircularProgressIndicator(color: AppColors.accent));
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        message: '$_erro',
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }
    if (_mensagens.isEmpty) {
      return const PhdEmptyState(
        icon: Icons.forum_outlined,
        title: 'Comece a conversa',
        message: 'Dúvida sobre o treino ou a dieta? Mande por aqui — fica tudo '
            'registrado no app.',
      );
    }

    // Lista invertida: a mensagem mais nova fica embaixo, junto do campo,
    // e a lista já abre no fim sem precisar rolar.
    final invertidas = _mensagens.reversed.toList();
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _carregar,
      child: ListView.builder(
        controller: _rolagem,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
        itemCount: invertidas.length,
        itemBuilder: (_, i) {
          final m = invertidas[i];
          final anterior = i + 1 < invertidas.length ? invertidas[i + 1] : null;
          final novoDia = anterior == null || !_mesmoDia(anterior.criadoEm, m.criadoEm);
          return Column(
            children: [
              if (novoDia) _separadorDia(m.criadoEm),
              _balao(m, agrupada: !novoDia && anterior.autorId == m.autorId),
            ],
          );
        },
      ),
    );
  }

  Widget _balao(Mensagem m, {required bool agrupada}) {
    final minha = m.autorId == _eu;
    final hora = '${m.criadoEm.hour.toString().padLeft(2, '0')}:'
        '${m.criadoEm.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: minha ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: agrupada ? 3 : AppSpacing.sm),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 6),
        decoration: BoxDecoration(
          color: minha ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(minha ? 16 : 4),
            bottomRight: Radius.circular(minha ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              m.texto,
              style: AppText.body(14.5, color: minha ? AppColors.onAccent : AppColors.textPrimary),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hora,
                  style: AppText.caption(10.5,
                      color: minha ? AppColors.onAccent.withValues(alpha: 0.75) : AppColors.textMuted),
                ),
                if (minha) ...[
                  const SizedBox(width: 3),
                  Icon(
                    m.lidaEm == null ? Icons.done_rounded : Icons.done_all_rounded,
                    size: 14,
                    color: AppColors.onAccent.withValues(alpha: 0.85),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _separadorDia(DateTime d) {
    final hoje = DateTime.now();
    final h = DateTime(hoje.year, hoje.month, hoje.day);
    final dia = DateTime(d.year, d.month, d.day);
    final dif = h.difference(dia).inDays;
    final texto = dif == 0
        ? 'Hoje'
        : dif == 1
            ? 'Ontem'
            : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: AppRadius.rPill),
          child: Text(texto, style: AppText.caption(11.5)),
        ),
      ),
    );
  }

  Widget _barraDeEnvio() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.sm, AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _campo,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.body(14.5),
                onSubmitted: (_) => _enviar(),
                decoration: InputDecoration(
                  hintText: 'Escreva uma mensagem',
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 12),
                  border: OutlineInputBorder(borderRadius: AppRadius.rXxl, borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: AppRadius.rXxl, borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.rXxl,
                    borderSide: BorderSide(color: AppColors.accent),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Material(
              color: AppColors.accent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _enviando ? null : _enviar,
                child: SizedBox.square(
                  dimension: 46,
                  child: _enviando
                      ? Padding(
                          padding: const EdgeInsets.all(13),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
                        )
                      : Icon(Icons.send_rounded, color: AppColors.onAccent, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _mesmoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
