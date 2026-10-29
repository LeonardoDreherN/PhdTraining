import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/dieta.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/lista_compras.dart';
import '../../../core/widgets/widgets.dart';

/// A lista de compras do plano, para 1 a 4 semanas.
///
/// O que já foi pego no mercado fica marcado no aparelho, por plano: sair
/// da tela no meio da compra e voltar não pode zerar o carrinho.
class ListaComprasScreen extends StatefulWidget {
  const ListaComprasScreen({super.key, required this.plano});

  final PlanoAlimentar plano;

  @override
  State<ListaComprasScreen> createState() => _ListaComprasScreenState();
}

class _ListaComprasScreenState extends State<ListaComprasScreen> {
  int _semanas = 1;
  Set<String> _marcados = {};

  String get _chave => 'compras_${widget.plano.id}';

  @override
  void initState() {
    super.initState();
    _ler();
  }

  Future<void> _ler() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _marcados = (p.getStringList(_chave) ?? const []).toSet();
        _semanas = p.getInt('${_chave}_semanas') ?? 1;
      });
    } catch (_) {
      // Sem armazenamento local: a lista funciona, só não lembra.
    }
  }

  Future<void> _gravar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_chave, _marcados.toList());
      await p.setInt('${_chave}_semanas', _semanas);
    } catch (_) {}
  }

  void _alternar(ItemCompra i) {
    setState(() {
      if (!_marcados.remove(i.chave)) _marcados.add(i.chave);
    });
    _gravar();
  }

  String _texto(List<ItemCompra> lista) {
    final b = StringBuffer('🛒 Lista de compras — ${widget.plano.nome} '
        '($_semanas ${_semanas == 1 ? 'semana' : 'semanas'})\n');
    void bloco(String titulo, Iterable<ItemCompra> itens) {
      if (itens.isEmpty) return;
      b.writeln('\n$titulo');
      for (final i in itens) {
        b.writeln('• ${i.alimento.rotulo} — ${i.pesoTexto}'
            '${i.medidaTexto == null ? '' : ' (${i.medidaTexto})'}');
      }
    }

    bloco('Itens do plano', lista.where((i) => !i.deTroca));
    bloco('Opções de troca (escolha uma de cada)', lista.where((i) => i.deTroca));
    return b.toString();
  }

  Future<void> _compartilhar(List<ItemCompra> lista) async {
    final texto = _texto(lista);
    final uri = Uri.https('wa.me', '/', {'text': texto});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (ok || !mounted) return;
    await Clipboard.setData(ClipboardData(text: texto));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lista copiada. Cole onde quiser.', style: AppText.body(13.5))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = listaDeCompras(widget.plano, dias: _semanas * 7);
    final fixos = lista.where((i) => !i.deTroca).toList();
    final trocas = lista.where((i) => i.deTroca).toList();
    final pegos = lista.where((i) => _marcados.contains(i.chave)).length;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Lista de compras', style: AppText.title(16)),
        actions: [
          IconButton(
            tooltip: 'Copiar lista',
            icon: Icon(Icons.copy_rounded, color: AppColors.textPrimary, size: 21),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: _texto(lista)));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Lista copiada.', style: AppText.body(13.5))),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Mandar pelo WhatsApp',
            icon: Icon(Icons.share_rounded, color: AppColors.textPrimary, size: 21),
            onPressed: () => _compartilhar(lista),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.huge),
        children: [
          Row(
            children: [
              for (final n in const [1, 2, 3, 4]) ...[
                Expanded(
                  child: PhdFilterChip(
                    label: n == 1 ? '1 semana' : '$n sem.',
                    selected: _semanas == n,
                    onTap: () {
                      setState(() => _semanas = n);
                      _gravar();
                    },
                  ),
                ),
                if (n < 4) const SizedBox(width: AppSpacing.sm),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          PhdCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Expanded(child: PhdStat(label: 'No carrinho', value: '$pegos de ${lista.length}', valueSize: 22)),
                if (_marcados.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => _marcados.clear());
                      _gravar();
                    },
                    child: Text('Recomeçar', style: AppText.bodyStrong(13, color: AppColors.accent)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          PhdProgressBar(value: lista.isEmpty ? 0 : pegos / lista.length, height: 6),
          if (lista.isEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const PhdEmptyState(
              icon: Icons.shopping_basket_outlined,
              title: 'Nada para comprar',
              message: 'Quando o plano tiver alimentos, a lista aparece aqui.',
            ),
          ],
          if (fixos.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const PhdSectionHeader(label: 'Itens do plano'),
            const SizedBox(height: AppSpacing.sm),
            _bloco(fixos),
          ],
          if (trocas.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            const PhdSectionHeader(label: 'Opções de troca'),
            const SizedBox(height: 4),
            Text(
              'Seu plano deixa escolher entre estes. Compre só a opção que vai comer.',
              style: AppText.caption(12),
            ),
            const SizedBox(height: AppSpacing.sm),
            _bloco(trocas),
          ],
        ],
      ),
    );
  }

  Widget _bloco(List<ItemCompra> itens) {
    return PhdCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (n, i) in itens.indexed) ...[
            if (n > 0) Divider(height: 1, color: AppColors.line, indent: 52),
            _linha(i),
          ],
        ],
      ),
    );
  }

  Widget _linha(ItemCompra i) {
    final marcado = _marcados.contains(i.chave);
    return InkWell(
      onTap: () => _alternar(i),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
        child: Row(
          children: [
            AnimatedContainer(
              duration: AppDuration.fast,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: marcado ? AppColors.success : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: marcado ? null : Border.all(color: AppColors.lineStrong, width: 1.5),
              ),
              child: marcado ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i.alimento.rotulo,
                    style: AppText.body(14, color: marcado ? AppColors.textMuted : AppColors.textPrimary)
                        .copyWith(decoration: marcado ? TextDecoration.lineThrough : null),
                  ),
                  if (i.medidaTexto != null)
                    Text(i.medidaTexto!, style: AppText.caption(11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              i.pesoTexto,
              style: AppText.number(14, color: marcado ? AppColors.textMuted : AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
