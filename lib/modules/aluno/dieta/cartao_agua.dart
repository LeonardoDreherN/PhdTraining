import 'package:flutter/material.dart';
import '../../../core/services/diario_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';

/// Azul-céu da água. Fora de `AppColors` pelo mesmo motivo dos macros: é
/// categoria, não estado — e precisa se distinguir do azul da marca.
const corAgua = Color(0xFF0EA5E9);

/// `1,25 L` — litros com vírgula, sem zeros sobrando.
String litrosTexto(int ml) {
  var s = (ml / 1000).toStringAsFixed(ml % 100 == 0 ? 1 : 2).replaceAll('.', ',');
  if (s.endsWith(',0')) s = s.substring(0, s.length - 2);
  return '$s L';
}

/// Água do dia: quanto já foi, quanto falta, e um toque para somar.
///
/// Carrega e grava sozinho, para a home e a dieta usarem o mesmo cartão
/// sem duplicar a lógica. [compacto] é a versão de uma linha da home.
class CartaoAgua extends StatefulWidget {
  const CartaoAgua({
    super.key,
    required this.alunoId,
    required this.dia,
    required this.metaMl,
    this.compacto = false,
  });

  final String alunoId;
  final DateTime dia;
  final int metaMl;
  final bool compacto;

  @override
  State<CartaoAgua> createState() => _CartaoAguaState();
}

class _CartaoAguaState extends State<CartaoAgua> {
  List<({String id, int ml})> _copos = [];
  bool _carregou = false;
  bool _gravando = false;

  int get _total => _copos.fold(0, (s, c) => s + c.ml);

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void didUpdateWidget(CartaoAgua old) {
    super.didUpdateWidget(old);
    if (old.dia != widget.dia || old.alunoId != widget.alunoId) _carregar();
  }

  Future<void> _carregar() async {
    try {
      final copos = await DiarioService.aguaDoDia(widget.alunoId, widget.dia);
      if (mounted) setState(() => _copos = copos);
    } catch (_) {
      // Sem a tabela (migration ainda não aplicada) ou sem rede: o cartão
      // fica no zero em vez de derrubar a tela.
    } finally {
      if (mounted) setState(() => _carregou = true);
    }
  }

  Future<void> _beber(int ml) async {
    // Soma na tela antes do servidor responder: quem toca duas vezes por
    // achar que não pegou registra o dobro.
    const temp = '';
    setState(() {
      _gravando = true;
      _copos = [..._copos, (id: temp, ml: ml)];
    });
    try {
      final id = await DiarioService.beberAgua(widget.alunoId, widget.dia, ml);
      if (!mounted) return;
      setState(() {
        final i = _copos.lastIndexWhere((c) => c.id == temp);
        if (i >= 0) _copos[i] = (id: id, ml: ml);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _copos = _copos.where((c) => c.id != temp).toList());
      _avisar('Não consegui registrar: $e');
    } finally {
      if (mounted) setState(() => _gravando = false);
    }
  }

  Future<void> _desfazer() async {
    final ultimo = _copos.lastOrNull;
    if (ultimo == null || ultimo.id.isEmpty) return;
    setState(() {
      _gravando = true;
      _copos = _copos.sublist(0, _copos.length - 1);
    });
    try {
      await DiarioService.apagarAgua(ultimo.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _copos = [..._copos, ultimo]);
      _avisar('Não consegui desfazer: $e');
    } finally {
      if (mounted) setState(() => _gravando = false);
    }
  }

  void _avisar(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg, style: AppText.body(13.5))));

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final meta = widget.metaMl;
    final bateu = total >= meta;

    final numero = Text.rich(TextSpan(children: [
      TextSpan(
        text: _carregou ? litrosTexto(total) : '—',
        style: AppText.number(widget.compacto ? 18 : 26, weight: FontWeight.w800),
      ),
      TextSpan(text: '  de ${litrosTexto(meta)}', style: AppText.caption(12)),
    ]));

    final botoes = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.compacto && _copos.isNotEmpty) ...[
          _botao(
            icone: Icons.undo_rounded,
            rotulo: null,
            dica: 'Desfazer o último copo',
            onTap: _gravando ? null : _desfazer,
          ),
          const SizedBox(width: 6),
        ],
        if (!widget.compacto) ...[
          _botao(rotulo: '+250 ml', onTap: _gravando ? null : () => _beber(250)),
          const SizedBox(width: 6),
        ],
        _botao(
          rotulo: widget.compacto ? '+250' : '+500 ml',
          destaque: true,
          onTap: _gravando ? null : () => _beber(widget.compacto ? 250 : 500),
        ),
      ],
    );

    if (widget.compacto) {
      return PhdCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _gota(36),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  numero,
                  const SizedBox(height: 6),
                  PhdProgressBar(value: meta == 0 ? 0 : total / meta, height: 5, color: corAgua),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            botoes,
          ],
        ),
      );
    }

    return PhdCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _gota(40),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ÁGUA', style: AppText.label()),
                    const SizedBox(height: 2),
                    numero,
                  ],
                ),
              ),
              if (bateu) const PhdStatusChip(label: 'Meta batida', tone: PhdTone.success),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PhdProgressBar(value: meta == 0 ? 0 : total / meta, height: 8, color: corAgua),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  _copos.isEmpty
                      ? 'Nenhum copo registrado'
                      : '${_copos.length} ${_copos.length == 1 ? 'registro' : 'registros'}',
                  style: AppText.caption(12, color: AppColors.textMuted),
                ),
              ),
              botoes,
            ],
          ),
        ],
      ),
    );
  }

  Widget _gota(double tamanho) => Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          color: corAgua.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(tamanho * 0.32),
        ),
        child: Icon(Icons.water_drop_rounded, size: tamanho * 0.52, color: corAgua),
      );

  Widget _botao({
    String? rotulo,
    IconData? icone,
    String? dica,
    bool destaque = false,
    VoidCallback? onTap,
  }) {
    final fundo = destaque ? corAgua : AppColors.surfaceHigh;
    final frente = destaque ? Colors.white : AppColors.textPrimary;
    final botao = Material(
      color: fundo,
      borderRadius: AppRadius.rPill,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 36,
          constraints: const BoxConstraints(minWidth: 36),
          padding: EdgeInsets.symmetric(horizontal: rotulo == null ? 0 : 12),
          alignment: Alignment.center,
          child: rotulo == null
              ? Icon(icone, size: 18, color: frente)
              : Text(rotulo, style: AppText.bodyStrong(12.5, color: frente)),
        ),
      ),
    );
    return dica == null ? botao : Tooltip(message: dica, child: botao);
  }
}
