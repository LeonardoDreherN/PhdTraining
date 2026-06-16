import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';

// Shared widgets and helpers for all neuromotores sub-screens.

// ─── Scaffold de Lista ───────────────────────────────────────────────────────

class NeuromotoresListScaffold extends StatelessWidget {
  final Map<String, dynamic> aluno;
  final String titulo;
  final String? subtitulo;
  final bool carregando;
  final List<Map<String, dynamic>> lista;
  final VoidCallback onNova;
  final void Function(Map<String, dynamic>) onEditar;
  final NeuroMetrica? Function(Map<String, dynamic>) buildMetrica;

  const NeuromotoresListScaffold({
    super.key,
    required this.aluno,
    required this.titulo,
    this.subtitulo,
    required this.carregando,
    required this.lista,
    required this.onNova,
    required this.onEditar,
    required this.buildMetrica,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(aluno['nome'] as String? ?? 'Aluno',
                style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            Text(titulo,
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onNova,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('Nova avaliação',
                    style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: carregando
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : lista.isEmpty
                    ? _buildEmpty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        itemCount: lista.length,
                        itemBuilder: (_, i) => _buildCard(lista[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider, width: 0.5),
            ),
            child: const Icon(Icons.folder_open_rounded,
                color: AppColors.textHint, size: 30),
          ),
          const SizedBox(height: 16),
          Text('Nenhuma avaliação registrada',
              style: GoogleFonts.montserrat(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('Toque em "Nova avaliação" para começar',
              style: GoogleFonts.montserrat(
                  color: AppColors.textHint, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> av) {
    final dataStr = neuroFormatData(av['data_avaliacao'] as String?);
    final metrica = buildMetrica(av);

    return GestureDetector(
      onTap: () => onEditar(av),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: GoogleFonts.montserrat(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(dataStr,
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (metrica != null) ...[
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(metrica.valor,
                      style: GoogleFonts.montserrat(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  Text(metrica.label,
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Scaffold de Formulário ──────────────────────────────────────────────────

class NeuromotoresFormScaffold extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Map<String, dynamic> aluno;
  final bool salvando;
  final bool podeSalvar;
  final VoidCallback onSalvar;
  final List<NeuroSecao> sections;

  const NeuromotoresFormScaffold({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.aluno,
    required this.salvando,
    required this.podeSalvar,
    required this.onSalvar,
    required this.sections,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: subtitulo != null
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo,
                    style: GoogleFonts.montserrat(
                        color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                Text(subtitulo!,
                    style: GoogleFonts.montserrat(
                        color: AppColors.textSecondary, fontSize: 11)),
              ])
            : Text(titulo,
                style: GoogleFonts.montserrat(
                    color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
        actions: [
          if (salvando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: podeSalvar ? onSalvar : null,
              child: Text('Salvar',
                  style: GoogleFonts.montserrat(
                      color:
                          podeSalvar ? AppColors.primary : AppColors.textHint,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...sections.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildSecao(s),
                )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: podeSalvar ? onSalvar : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.divider,
                  disabledForegroundColor: AppColors.textHint,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Salvar',
                    style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSecao(NeuroSecao secao) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text(secao.titulo,
              style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Column(
            children: neuroIntercalar(
              secao.filhos,
              const Divider(
                  height: 1, thickness: 0.5, color: AppColors.divider),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Modelos ─────────────────────────────────────────────────────────────────

class NeuroSecao {
  final String titulo;
  final List<Widget> filhos;
  const NeuroSecao(this.titulo, this.filhos);
}

class NeuroMetrica {
  final String valor;
  final String label;
  const NeuroMetrica(this.valor, this.label);
}

// ─── Widgets de linha ────────────────────────────────────────────────────────

class NeuroLinhaEdit extends StatelessWidget {
  final String label;
  final String valor;
  final VoidCallback onTap;
  const NeuroLinhaEdit(this.label, this.valor, this.onTap, {super.key});

  @override
  Widget build(BuildContext context) {
    final vazio = valor == '—';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label,
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(valor,
                style: GoogleFonts.montserrat(
                    color: vazio ? AppColors.textHint : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.edit_outlined,
                color: AppColors.textHint, size: 14),
          ],
        ),
      ),
    );
  }
}

class NeuroLinhaReadOnly extends StatelessWidget {
  final String label;
  final String valor;
  final String? hint;
  const NeuroLinhaReadOnly(this.label, this.valor, {super.key, this.hint});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: GoogleFonts.montserrat(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const Spacer(),
              Text(valor,
                  style: GoogleFonts.montserrat(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text('* $hint',
                style: GoogleFonts.montserrat(
                    color: const Color(0xFFEF9A9A), fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

class NeuroLinhaCalc extends StatelessWidget {
  final String label;
  final String valor;
  final String? badge;
  final Color? badgeColor;
  const NeuroLinhaCalc(this.label, this.valor,
      {super.key, this.badge, this.badgeColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(label,
              style: GoogleFonts.montserrat(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          if (badge != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: (badgeColor ?? AppColors.textSecondary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(badge!,
                  style: GoogleFonts.montserrat(
                      color: badgeColor ?? AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
          ],
          Text(valor,
              style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class NeuroLinhaDate extends StatelessWidget {
  final String label;
  final DateTime? data;
  final void Function(DateTime) onPick;
  final String placeholder;
  const NeuroLinhaDate(this.label, this.data, this.onPick,
      {super.key, this.placeholder = '—'});

  @override
  Widget build(BuildContext context) {
    final texto = data != null
        ? '${data!.day.toString().padLeft(2, '0')}/${data!.month.toString().padLeft(2, '0')}/${data!.year}'
        : placeholder;
    return InkWell(
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: data ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                  primary: AppColors.primary, surface: AppColors.surface),
            ),
            child: child!,
          ),
        );
        if (d != null) onPick(d);
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label,
                style: GoogleFonts.montserrat(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(texto,
                style: GoogleFonts.montserrat(
                    color: data != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            const Icon(Icons.calendar_today_rounded,
                color: AppColors.textHint, size: 14),
          ],
        ),
      ),
    );
  }
}

class NeuroLinhaTextarea extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  const NeuroLinhaTextarea(this.label, this.ctrl, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.montserrat(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            maxLines: 3,
            style:
                GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: '...',
              hintStyle:
                  GoogleFonts.montserrat(color: AppColors.textHint, fontSize: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }
}

class NeuroInfoRow extends StatelessWidget {
  final String texto;
  const NeuroInfoRow(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(texto,
          style: GoogleFonts.montserrat(
              color: AppColors.textHint,
              fontSize: 11,
              fontStyle: FontStyle.italic)),
    );
  }
}

// ─── Funções utilitárias ─────────────────────────────────────────────────────

List<Widget> neuroIntercalar(List<Widget> items, Widget sep) {
  final result = <Widget>[];
  for (int i = 0; i < items.length; i++) {
    result.add(items[i]);
    if (i < items.length - 1) result.add(sep);
  }
  return result;
}

String neuroFormatData(String? raw) {
  if (raw == null) return '—';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

Future<void> neuroEditDouble(BuildContext context, String label,
    String unidade, double? atual, void Function(double) set) async {
  final ctrl = TextEditingController(
      text: atual != null ? atual.toStringAsFixed(1) : '');
  final v = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(label,
          style: GoogleFonts.montserrat(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      content: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        autofocus: true,
        style: GoogleFonts.montserrat(color: AppColors.textPrimary),
        decoration: InputDecoration(
          suffixText: unidade,
          suffixStyle:
              GoogleFonts.montserrat(color: AppColors.textSecondary),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancelar',
              style:
                  GoogleFonts.montserrat(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            final val =
                double.tryParse(ctrl.text.trim().replaceAll(',', '.'));
            Navigator.pop(ctx, val);
          },
          child: Text('OK',
              style: GoogleFonts.montserrat(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  if (v != null && v > 0) set(v);
}

Future<void> neuroEditInt(BuildContext context, String label, String unidade,
    int? atual, void Function(int) set) async {
  final ctrl = TextEditingController(text: atual != null ? '$atual' : '');
  final v = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(label,
          style: GoogleFonts.montserrat(
              color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
      content: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        style: GoogleFonts.montserrat(color: AppColors.textPrimary),
        decoration: InputDecoration(
          suffixText: unidade,
          suffixStyle:
              GoogleFonts.montserrat(color: AppColors.textSecondary),
          enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.divider)),
          focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary)),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancelar',
              style:
                  GoogleFonts.montserrat(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () {
            final val = int.tryParse(ctrl.text.trim());
            Navigator.pop(ctx, val);
          },
          child: Text('OK',
              style: GoogleFonts.montserrat(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  if (v != null && v > 0) set(v);
}

void neuroShowErro(BuildContext context, Object e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Erro ao salvar: $e',
          style: GoogleFonts.montserrat(color: Colors.black)),
      backgroundColor: Colors.red,
    ),
  );
}

Color neuroCorClass(String? c) {
  switch (c) {
    case 'Excelente':
      return const Color(0xFF4CAF50);
    case 'Bom':
      return const Color(0xFF8BC34A);
    case 'Regular':
      return const Color(0xFFFFC107);
    case 'Fraco':
      return const Color(0xFFF44336);
    default:
      return AppColors.textSecondary;
  }
}
