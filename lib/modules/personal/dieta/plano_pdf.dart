import 'dart:typed_data';
import 'package:flutter/material.dart' show BuildContext, ScaffoldMessenger, SnackBar, Text;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/dieta.dart';
import '../../../core/models/perfil.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/utils/datas.dart';

/// Gera o PDF do plano e abre o "compartilhar" do sistema.
///
/// [marca] é o perfil cuja marca vai no cabeçalho. Sem ela, usa o perfil de
/// quem está logado — o caso do profissional. O aluno passa a do personal.
Future<void> compartilharPlanoPdf(
  BuildContext context,
  PlanoAlimentar plano, {
  required String alunoNome,
  Perfil? marca,
}) async {
  try {
    var perfil = marca;
    if (perfil == null) {
      final m = await ProfileService.getPerfil();
      if (m != null) perfil = Perfil.doMapa(m);
    }
    final bytes = await PlanoPdf.gerar(plano, alunoNome: alunoNome, perfil: perfil);
    final nome = alunoNome
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    await Printing.sharePdf(bytes: bytes, filename: 'plano_alimentar_$nome.pdf');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não consegui gerar o PDF: $e')));
    }
  }
}

/// O plano alimentar em papel: o que comer em cada refeição, as trocas, as
/// receitas no fim e a assinatura com CRN.
///
/// Fundo branco pelo mesmo motivo do PDF da avaliação: vai para impressora
/// e para o WhatsApp, onde um PDF escuro parece erro.
abstract class PlanoPdf {
  static const _tinta = PdfColor.fromInt(0xFF141417);
  static const _apoio = PdfColor.fromInt(0xFF5C5C66);
  static const _fraco = PdfColor.fromInt(0xFF9A9AA2);
  static const _linha = PdfColor.fromInt(0xFFE4E4E7);
  static const _fundo = PdfColor.fromInt(0xFFF4F4F5);

  static Future<Uint8List> gerar(
    PlanoAlimentar p, {
    required String alunoNome,
    Perfil? perfil,
  }) async {
    final fontes = await _fontes();
    final logo = await _baixar(perfil?.marcaLogoUrl);
    final marca = _cor(perfil?.marcaCor);

    // Cada receita aparece uma vez no apêndice, mesmo se usada em várias
    // refeições.
    final receitas = <String, Receita>{
      for (final r in p.refeicoes)
        for (final rr in r.receitas) rr.receita.id: rr.receita,
    };

    final doc = pw.Document(
      title: 'Plano alimentar — $alunoNome',
      author: perfil?.nomeExibicao,
      theme: pw.ThemeData.withFont(base: fontes.$1, bold: fontes.$2),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: _linha, width: 0.6)),
              ),
              child: pw.Row(children: [
                pw.Expanded(child: _texto('$alunoNome · ${p.nome}', size: 8.5, cor: _apoio)),
                if (perfil != null) _texto(perfil.marcaNome ?? perfil.nomeExibicao, size: 8.5, cor: _apoio),
              ]),
            ),
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: _texto(
                p.assinado
                    ? 'Plano prescrito por nutricionista · CRN ${p.crnAssinatura} · '
                        'assinado em ${Datas.curta(p.assinadoEm!.toLocal())}'
                    : 'Plano ainda não assinado pelo nutricionista.',
                size: 7.5,
                cor: _fraco,
              ),
            ),
            _texto('${ctx.pageNumber}/${ctx.pagesCount}', size: 8, cor: _fraco),
          ],
        ),
      ),
      build: (ctx) => [
        _cabecalho(p, alunoNome, perfil, logo, marca),
        pw.SizedBox(height: 16),
        for (final r in p.refeicoes)
          if (!r.vazia) _refeicao(r, marca),
        if (p.observacoes?.trim().isNotEmpty == true) ...[
          pw.SizedBox(height: 6),
          _titulo('Orientações'),
          pw.SizedBox(height: 4),
          _texto(p.observacoes!.trim(), size: 10, cor: _apoio),
        ],
        if (receitas.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          _titulo('Receitas'),
          pw.SizedBox(height: 6),
          for (final r in receitas.values) _receita(r),
        ],
      ],
    ));

    return doc.save();
  }

  // ── Seções ─────────────────────────────────────────────────

  static pw.Widget _cabecalho(
    PlanoAlimentar p,
    String alunoNome,
    Perfil? perfil,
    Uint8List? logo,
    PdfColor marca,
  ) {
    final nomeMarca = perfil?.marcaNome?.trim().isNotEmpty == true
        ? perfil!.marcaNome!
        : perfil?.nomeExibicao ?? 'Plano alimentar';
    final kcal = p.metaKcal ?? p.totalPrescrito.kcal;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 5, color: marca),
        pw.SizedBox(height: 14),
        pw.Row(
          children: [
            if (logo != null) ...[
              pw.ClipRRect(
                horizontalRadius: 6,
                verticalRadius: 6,
                child: pw.Image(pw.MemoryImage(logo), width: 40, height: 40, fit: pw.BoxFit.cover),
              ),
              pw.SizedBox(width: 10),
            ],
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _texto(nomeMarca, size: 15, bold: true),
                  if (perfil?.nome != null)
                    _texto(
                      [perfil!.nome!, if (p.crnAssinatura != null) 'CRN ${p.crnAssinatura}'].join(' · '),
                      size: 9,
                      cor: _apoio,
                    ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _rotulo('Plano alimentar'),
                _texto(p.nome, size: 13, bold: true),
                if (p.dataInicio != null)
                  _texto('Desde ${Datas.curta(p.dataInicio!)}', size: 8.5, cor: _apoio),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(
            color: _fundo,
            borderRadius: pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [_rotulo('Paciente'), _texto(alunoNome, size: 13, bold: true)],
                ),
              ),
              _par('Energia', '${kcal.round()} kcal'),
              if (p.metaProteina != null) ...[
                pw.SizedBox(width: 16),
                _par(
                  'P · C · G',
                  '${p.metaProteina!.round()} · ${p.metaCarboidrato?.round() ?? 0} · '
                      '${p.metaGordura?.round() ?? 0} g',
                ),
              ],
              if (p.aguaMl != null) ...[
                pw.SizedBox(width: 16),
                _par('Água', '${(p.aguaMl! / 1000).toStringAsFixed(1).replaceAll('.', ',')} L'),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _refeicao(Refeicao r, PdfColor marca) {
    final soltos = r.itens.where((i) => i.grupoSubstituicao == null).toList();
    final grupos = <String, List<ItemRefeicao>>{};
    for (final i in r.itens.where((i) => i.grupoSubstituicao != null)) {
      grupos.putIfAbsent(i.grupoSubstituicao!, () => []).add(i);
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _linha, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              if (r.horarioTexto != null) ...[
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: pw.BoxDecoration(
                    color: marca,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    r.horarioTexto!,
                    style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  ),
                ),
                pw.SizedBox(width: 8),
              ],
              pw.Expanded(child: _texto(r.nome, size: 12.5, bold: true)),
              _texto('${r.total.kcal.round()} kcal', size: 9, cor: _apoio),
            ],
          ),
          pw.SizedBox(height: 6),
          for (final i in soltos) _linhaItem(i.alimento.rotulo, i.quantidadeTexto),
          for (final g in grupos.values)
            if (g.length == 1)
              _linhaItem(g.first.alimento.rotulo, g.first.quantidadeTexto)
            else
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 3, bottom: 3),
                padding: const pw.EdgeInsets.all(6),
                decoration: const pw.BoxDecoration(
                  color: _fundo,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(5)),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _rotulo('Escolha uma opção'),
                    pw.SizedBox(height: 2),
                    for (final i in g) _linhaItem(i.alimento.rotulo, i.quantidadeTexto),
                  ],
                ),
              ),
          for (final rr in r.receitas)
            _linhaItem('Receita: ${rr.receita.nome}', rr.porcoesTextoCompleto),
          if (r.observacoes?.trim().isNotEmpty == true) ...[
            pw.SizedBox(height: 4),
            _texto(r.observacoes!.trim(), size: 9, cor: _apoio),
          ],
        ],
      ),
    );
  }

  static pw.Widget _linhaItem(String nome, String quantidade) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _texto('•  $nome', size: 10)),
            pw.SizedBox(width: 8),
            _texto(quantidade, size: 9.5, cor: _apoio),
          ],
        ),
      );

  static pw.Widget _receita(Receita r) {
    final p = r.porPorcao;
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _linha, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _texto(r.nome, size: 12.5, bold: true),
          _texto(
            [
              'Rende ${r.rendimentoTexto}',
              if (r.tempoMinutos != null) '${r.tempoMinutos} min',
              'por porção: ${p.kcal.round()} kcal · P ${p.proteina.round()} g · '
                  'C ${p.carboidrato.round()} g · G ${p.gordura.round()} g',
            ].join(' · '),
            size: 8.5,
            cor: _apoio,
          ),
          pw.SizedBox(height: 6),
          _rotulo('Ingredientes'),
          for (final i in r.ingredientes) _linhaItem(i.alimento.rotulo, i.quantidadeTexto),
          if (r.modoPreparo?.trim().isNotEmpty == true) ...[
            pw.SizedBox(height: 6),
            _rotulo('Modo de preparo'),
            pw.SizedBox(height: 2),
            _texto(r.modoPreparo!.trim(), size: 10),
          ],
        ],
      ),
    );
  }

  // ── Peças ──────────────────────────────────────────────────

  static pw.Widget _par(String rotulo, String valor) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [_rotulo(rotulo), _texto(valor, size: 10.5, bold: true)],
      );

  static pw.Widget _titulo(String s) => pw.Text(
        _t(s),
        style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _tinta),
      );

  static pw.Widget _texto(String s, {double size = 10, PdfColor? cor, bool bold = false}) => pw.Text(
        _t(s),
        style: pw.TextStyle(
          fontSize: size,
          color: cor ?? _tinta,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          lineSpacing: 2,
        ),
      );

  static pw.Widget _rotulo(String s) => pw.Text(
        _t(s.toUpperCase()),
        style: const pw.TextStyle(
          fontSize: 7.5,
          color: _fraco,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.4,
        ),
      );

  // ── Recursos (mesma estratégia do PDF da avaliação) ─────────

  static bool _helvetica = false;

  static Future<(pw.Font, pw.Font)> _fontes() async {
    try {
      final r = await Future.wait([PdfGoogleFonts.manropeRegular(), PdfGoogleFonts.manropeBold()]);
      if (r[0] is pw.TtfFont && r[1] is pw.TtfFont) {
        _helvetica = false;
        return (r[0], r[1]);
      }
    } catch (_) {
      // Sem internet: Helvetica embutida.
    }
    _helvetica = true;
    return (pw.Font.helvetica(), pw.Font.helveticaBold());
  }

  /// A Helvetica embutida só cobre Latin-1: travessão e afins viram
  /// quadradinho.
  static String _t(String s) {
    if (!_helvetica) return s;
    return s.replaceAll('—', '-').replaceAll('–', '-').replaceAll('−', '-').replaceAll('•', '-');
  }

  static Future<Uint8List?> _baixar(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  static PdfColor _cor(String? hex) {
    try {
      return PdfColor.fromHex((hex ?? '#DC2626').replaceFirst('#', ''));
    } catch (_) {
      return PdfColor.fromHex('DC2626');
    }
  }
}
