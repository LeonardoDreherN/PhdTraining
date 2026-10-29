import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/models/avaliacao.dart';
import '../../../core/models/perfil.dart';
import '../../../core/utils/avaliacao_calculos.dart';
import '../../../core/utils/datas.dart';
import 'avaliacao_resumo.dart';
import 'avaliacao_widgets.dart';

/// O relatório da avaliação que o personal manda para o aluno.
///
/// Fundo branco, ao contrário do app: é feito para ser impresso e lido no
/// WhatsApp, onde um PDF escuro parece erro. A marca do personal (nome,
/// logo, cor) é a que o aluno já vê no app dele.
abstract class AvaliacaoPdf {
  static const _tinta = PdfColor.fromInt(0xFF141417);
  static const _apoio = PdfColor.fromInt(0xFF5C5C66);
  static const _fraco = PdfColor.fromInt(0xFF9A9AA2);
  static const _linha = PdfColor.fromInt(0xFFE4E4E7);
  static const _fundo = PdfColor.fromInt(0xFFF4F4F5);
  static const _bom = PdfColor.fromInt(0xFF15803D);
  static const _atencao = PdfColor.fromInt(0xFFB45309);
  static const _risco = PdfColor.fromInt(0xFFB91C1C);

  static Future<void> compartilhar(AvaliacaoCompleta av, Perfil? perfil) async {
    final bytes = await gerar(av, perfil);
    final nome = (av.aluno['nome'] as String? ?? 'aluno')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    await Printing.sharePdf(bytes: bytes, filename: 'avaliacao_${nome}_${Datas.iso(av.data)}.pdf');
  }

  static Future<Uint8List> gerar(AvaliacaoCompleta av, Perfil? perfil) async {
    final fontes = await _fontes();
    final logo = await _baixar(perfil?.marcaLogoUrl);
    final fotos = <VistaPostural, pw.MemoryImage>{};
    for (final v in VistaPostural.values) {
      final url = av.postural?[v.coluna] as String?;
      if (url != null && url.startsWith('http')) {
        final b = await _baixar(url);
        if (b != null) fotos[v] = pw.MemoryImage(b);
      }
    }

    final marca = _cor(perfil?.marcaCor);
    final doc = pw.Document(
      title: 'Avaliação física — ${av.aluno['nome'] ?? ''}',
      author: perfil?.nomeExibicao,
      theme: pw.ThemeData.withFont(base: fontes.$1, bold: fontes.$2),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 36),
      header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : _cabecalhoCurto(av, perfil),
      footer: (ctx) => _rodape(ctx),
      build: (ctx) => [
        _cabecalho(av, perfil, logo, marca),
        pw.SizedBox(height: 18),
        _destaques(av),
        pw.SizedBox(height: 18),
        ..._medidas(av),
        ..._indices(av),
        ..._comparacao(av),
        ..._testes(av),
        ..._zonas(av),
        ..._postural(av, fotos, marca),
        ..._fechamento(av),
      ],
    ));

    return doc.save();
  }

  // ── Recursos ───────────────────────────────────────────────

  /// Manrope, a mesma do app. Sem internet cai na Helvetica embutida, e
  /// [_t] troca os poucos caracteres que ela não tem.
  static bool _helvetica = false;

  static Future<(pw.Font, pw.Font)> _fontes() async {
    try {
      final r = await Future.wait([PdfGoogleFonts.manropeRegular(), PdfGoogleFonts.manropeBold()]);
      // Quando o download falha, o `printing` não lança: devolve a
      // Helvetica REGULAR para as duas — e o negrito do relatório some.
      // Só aceitamos se as duas vieram de fato.
      if (r[0] is pw.TtfFont && r[1] is pw.TtfFont) {
        _helvetica = false;
        return (r[0], r[1]);
      }
    } catch (_) {
      // Cai para a Helvetica abaixo.
    }
    _helvetica = true;
    return (pw.Font.helvetica(), pw.Font.helveticaBold());
  }

  static String _t(String s) {
    var r = s.replaceAll('₂', '2');
    // A Helvetica embutida só cobre Latin-1: travessão e sinal de menos
    // viram quadradinho.
    if (_helvetica) {
      r = r.replaceAll('−', '-').replaceAll('–', '-').replaceAll('—', '-').replaceAll('≥', '>=');
    }
    return r;
  }

  static Future<Uint8List?> _baixar(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      return r.statusCode == 200 ? r.bodyBytes : null;
    } catch (_) {
      // Foto que não baixa sai do relatório; o resto continua.
      return null;
    }
  }

  static PdfColor _cor(String? hex) {
    try {
      return PdfColor.fromHex((hex ?? '#2F6BFF').replaceFirst('#', ''));
    } catch (_) {
      return PdfColor.fromHex('2F6BFF');
    }
  }

  static PdfColor _corNivel(Nivel? n) => switch (n) {
        Nivel.bom => _bom,
        Nivel.atencao => _atencao,
        Nivel.risco => _risco,
        _ => _apoio,
      };

  // ── Peças ──────────────────────────────────────────────────

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
        style: const pw.TextStyle(fontSize: 7.5, color: _fraco, fontWeight: pw.FontWeight.bold, letterSpacing: 1.4),
      );

  static List<pw.Widget> _secao(String titulo, List<pw.Widget> corpo) {
    if (corpo.isEmpty) return const [];
    return [
      pw.SizedBox(height: 14),
      pw.Text(_t(titulo), style: const pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _tinta)),
      pw.SizedBox(height: 6),
      ...corpo,
    ];
  }

  static pw.Widget _tabela(List<String> cabecalho, List<List<pw.Widget>> linhas, {Map<int, pw.TableColumnWidth>? larguras}) {
    return pw.Table(
      columnWidths: larguras,
      border: const pw.TableBorder(horizontalInside: pw.BorderSide(color: _linha, width: 0.6)),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _fundo),
          children: [
            for (final c in cabecalho)
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: _rotulo(c)),
          ],
        ),
        for (final l in linhas)
          pw.TableRow(children: [
            for (final c in l)
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: c),
          ]),
      ],
    );
  }

  // ── Seções ─────────────────────────────────────────────────

  static pw.Widget _cabecalho(AvaliacaoCompleta av, Perfil? perfil, Uint8List? logo, PdfColor marca) {
    final nomeMarca = perfil?.marcaNome?.trim().isNotEmpty == true
        ? perfil!.marcaNome!
        : perfil?.nomeExibicao ?? 'Avaliação física';
    final idade = av.idade;
    final sexo = av.sexoIndefinido ? null : (av.masculino ? 'Masculino' : 'Feminino');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(height: 5, color: marca),
        pw.SizedBox(height: 14),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
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
                      [perfil!.nome!, if (perfil.cref?.isNotEmpty == true) 'CREF ${perfil.cref}'].join(' · '),
                      size: 9,
                      cor: _apoio,
                    ),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _rotulo('Avaliação física'),
                _texto(Datas.longa(av.data), size: 13, bold: true),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: const pw.BoxDecoration(color: _fundo, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _rotulo('Aluno'),
                    _texto(av.aluno['nome'] as String? ?? '—', size: 13, bold: true),
                  ],
                ),
              ),
              if (idade != null) _par('Idade', '$idade anos'),
              if (sexo != null) ...[pw.SizedBox(width: 18), _par('Sexo', sexo)],
              if (av.anterior != null) ...[pw.SizedBox(width: 18), _par('Anterior', Datas.curta(av.anterior!.data))],
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _par(String rotulo, String valor) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [_rotulo(rotulo), _texto(valor, size: 10.5, bold: true)],
      );

  static pw.Widget _cabecalhoCurto(AvaliacaoCompleta av, Perfil? perfil) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _linha, width: 0.6))),
        child: pw.Row(children: [
          pw.Expanded(child: _texto('${av.aluno['nome'] ?? ''} · Avaliação de ${Datas.curta(av.data)}', size: 8.5, cor: _apoio)),
          if (perfil != null) _texto(perfil.marcaNome ?? perfil.nomeExibicao, size: 8.5, cor: _apoio),
        ]),
      );

  static pw.Widget _rodape(pw.Context ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Expanded(
              child: _texto(
                'Índices de triagem baseados em medidas antropométricas e testes de campo. '
                'Não substituem avaliação médica.',
                size: 7.5,
                cor: _fraco,
              ),
            ),
            pw.SizedBox(width: 12),
            _texto('${ctx.pageNumber}/${ctx.pagesCount}', size: 8, cor: _fraco),
          ],
        ),
      );

  static pw.Widget _destaques(AvaliacaoCompleta av) {
    final itens = <(String, String, String?, Nivel?)>[
      ('Peso', av.peso == null ? '—' : '${numBr(av.peso)} kg', null, null),
      ('Gordura', av.percGordura == null ? '—' : '${numBr(av.percGordura)}%', av.origemGordura, null),
      ('IMC', av.imc == null ? '—' : numBr(av.imc!.valor), av.imc?.classificacao?.rotulo, av.imc?.classificacao?.nivel),
      ('VO₂máx', av.vo2max == null ? '—' : numBr(av.vo2max), av.classificacaoVo2?.rotulo, av.classificacaoVo2?.nivel),
    ];
    return pw.Row(
      children: [
        for (final (i, (rotulo, valor, sub, nivel)) in itens.indexed) ...[
          if (i > 0) pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _linha, width: 0.8),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _rotulo(rotulo),
                  pw.SizedBox(height: 3),
                  _texto(valor, size: 17, bold: true),
                  if (sub != null) _texto(sub, size: 8, cor: _corNivel(nivel)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  static List<pw.Widget> _medidas(AvaliacaoCompleta av) {
    final s = av.sessao;
    final linhas = <(String, String)>[
      if (av.peso != null) ('Peso', '${numBr(av.peso)} kg'),
      if (av.estatura != null) ('Estatura', '${numBr(av.estatura)} cm'),
      if (av.cintura != null) ('Cintura', '${numBr(av.cintura)} cm'),
      if (av.quadril != null) ('Quadril', '${numBr(av.quadril)} cm'),
      if (av.massaMagra != null) ('Massa magra', '${numBr(av.massaMagra)} kg'),
      if (av.massaGorda != null) ('Massa gorda', '${numBr(av.massaGorda)} kg'),
      if (s.paSistolica != null && s.paDiastolica != null)
        ('Pressão arterial', '${s.paSistolica}/${s.paDiastolica} mmHg${av.pressao == null ? '' : ' · ${av.pressao!.rotulo}'}'),
      if (s.fcRepouso != null) ('FC de repouso', '${s.fcRepouso} bpm'),
    ];
    if (linhas.isEmpty) return const [];
    // Duas colunas de pares: a lista inteira numa coluna só ocupava meia
    // página para oito números.
    final metade = (linhas.length / 2).ceil();
    pw.Widget coluna(Iterable<(String, String)> ls) => pw.Column(children: [
          for (final (r, v) in ls)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: _linha, width: 0.6))),
              child: pw.Row(children: [
                pw.Expanded(child: _texto(r, cor: _apoio)),
                _texto(v, bold: true),
              ]),
            ),
        ]);
    return _secao('Medidas e sinais vitais', [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: coluna(linhas.take(metade))),
          pw.SizedBox(width: 20),
          pw.Expanded(child: coluna(linhas.skip(metade))),
        ],
      ),
    ]);
  }

  static List<pw.Widget> _indices(AvaliacaoCompleta av) {
    final itens = <(String, Indice?, String, int)>[
      ('Índice de massa corporal (IMC)', av.imc, 'kg/m²', 1),
      ('Relação cintura-quadril', av.rcq, '', 2),
      ('Relação cintura-estatura', av.rce, '', 2),
      ('Circunferência da cintura', av.indiceCintura, 'cm', 1),
      ('Índice de adiposidade corporal (estimativa de gordura)', av.iac, '%', 1),
    ];
    final linhas = [
      for (final (nome, ind, unidade, casas) in itens)
        if (ind != null)
          [
            _texto(nome),
            _texto('${numBr(ind.valor, casas: casas)}${unidade.isEmpty ? '' : ' $unidade'}', bold: true),
            _texto(ind.classificacao?.rotulo ?? 'Estimativa', cor: _corNivel(ind.classificacao?.nivel), bold: true),
            _texto(ind.referencia ?? '', size: 8.5, cor: _fraco),
          ],
    ];
    if (linhas.isEmpty) return const [];
    return _secao('Índices de saúde', [
      _tabela(['Índice', 'Valor', 'Classificação', 'Fonte'], linhas, larguras: const {
        0: pw.FlexColumnWidth(3.2),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1),
      }),
    ]);
  }

  static List<pw.Widget> _comparacao(AvaliacaoCompleta av) {
    final linhas = comparacao(av);
    if (linhas.isEmpty) return const [];
    return _secao('Evolução desde ${Datas.curta(av.anterior!.data)}', [
      _tabela(
        ['Medida', Datas.curta(av.anterior!.data), Datas.curta(av.data), 'Diferença'],
        [
          for (final l in linhas)
            [
              _texto(l.rotulo),
              _texto(comUnidade(numBr(l.anterior), l.unidade), cor: _apoio),
              _texto(comUnidade(numBr(l.atual), l.unidade), bold: true),
              _texto(comUnidade(deltaBr(l.atual, l.anterior) ?? '', l.unidade),
                  bold: true, cor: _corNivel(l.nivel)),
            ],
        ],
      ),
    ]);
  }

  static List<pw.Widget> _testes(AvaliacaoCompleta av) {
    final linhas = [
      ...linhasComposicao(av),
      ...linhasNeuromotoras(av),
      ...linhasCardio(av),
    ];
    if (linhas.isEmpty) return const [];
    return _secao('Testes realizados', [
      _tabela(
        ['Teste', 'Resultado', 'Análise'],
        [
          for (final l in linhas) [_texto(l.titulo), _texto(l.valor, bold: true), _texto(l.detalhe ?? '', cor: _apoio)],
        ],
        larguras: const {0: pw.FlexColumnWidth(2.4), 1: pw.FlexColumnWidth(1.6), 2: pw.FlexColumnWidth(2)},
      ),
    ]);
  }

  static List<pw.Widget> _zonas(AvaliacaoCompleta av) {
    final zonas = av.zonas;
    if (zonas.isEmpty) return const [];
    return _secao('Zonas de treino', [
      _texto(
        'FC máxima estimada de ${av.fcMax} bpm (Tanaka)'
        '${av.sessao.fcRepouso == null ? '' : ' e FC de repouso de ${av.sessao.fcRepouso} bpm (Karvonen)'}.',
        size: 9,
        cor: _apoio,
      ),
      pw.SizedBox(height: 6),
      _tabela(
        ['Zona', 'Objetivo', 'Intensidade', 'Batimentos'],
        [
          for (final z in zonas)
            [
              _texto(z.id, bold: true),
              _texto(z.nome),
              _texto('${(z.pctDe * 100).round()}–${(z.pctAte * 100).round()}%', cor: _apoio),
              _texto('${z.bpmDe}–${z.bpmAte} bpm', bold: true),
            ],
        ],
      ),
    ]);
  }

  static List<pw.Widget> _postural(AvaliacaoCompleta av, Map<VistaPostural, pw.MemoryImage> fotos, PdfColor marca) {
    final desvios = av.desvios;
    if (av.postural == null || (fotos.isEmpty && desvios.isEmpty)) return const [];
    final corpo = <pw.Widget>[];
    if (fotos.isNotEmpty) {
      corpo.add(pw.Row(
        children: [
          for (final (i, e) in fotos.entries.indexed) ...[
            if (i > 0) pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Column(children: [
                pw.AspectRatio(
                  aspectRatio: 3 / 4,
                  child: pw.Stack(fit: pw.StackFit.expand, children: [
                    pw.Image(e.value, fit: pw.BoxFit.cover),
                    pw.CustomPaint(painter: (canvas, size) => _grade(canvas, size, marca)),
                  ]),
                ),
                pw.SizedBox(height: 3),
                _texto(e.key.rotulo, size: 8, cor: _apoio),
              ]),
            ),
          ],
          // Mantém o tamanho da foto mesmo com menos de quatro vistas.
          for (var i = fotos.length; i < 4; i++) ...[pw.SizedBox(width: 8), pw.Expanded(child: pw.SizedBox())],
        ],
      ));
      corpo.add(pw.SizedBox(height: 10));
    }
    if (desvios.isEmpty) {
      corpo.add(_texto('Nenhum desvio postural relevante observado.', cor: _apoio));
    } else {
      corpo.add(_tabela(
        ['Região', 'Desvio', 'Grau'],
        [
          for (final r in regioesPosturais)
            for (final d in r.desvios)
              if (desvios[d.chave] case final g?)
                [
                  _texto(r.nome, cor: _apoio),
                  _texto(d.nome),
                  _texto(g.rotulo,
                      bold: true,
                      cor: switch (g) {
                        GrauDesvio.leve => _apoio,
                        GrauDesvio.moderado => _atencao,
                        GrauDesvio.acentuado => _risco,
                      }),
                ],
        ],
      ));
    }
    final obs = (av.postural?['observacoes'] as String?)?.trim();
    if (obs != null && obs.isNotEmpty) {
      corpo.add(pw.SizedBox(height: 6));
      corpo.add(_texto(obs, size: 9.5, cor: _apoio));
    }
    return _secao('Avaliação postural', corpo);
  }

  /// A mesma grade da tela: oitavos claros e o fio de prumo na cor da marca.
  /// No PDF a origem é o canto INFERIOR esquerdo.
  static void _grade(PdfGraphics canvas, PdfPoint size, PdfColor marca) {
    canvas
      ..setStrokeColor(const PdfColor(1, 1, 1, 0.45))
      ..setLineWidth(0.4);
    for (var i = 1; i < 8; i++) {
      final x = size.x * i / 8;
      final y = size.y * i / 8;
      canvas
        ..drawLine(x, 0, x, size.y)
        ..drawLine(0, y, size.x, y);
    }
    canvas.strokePath();
    canvas
      ..setStrokeColor(marca)
      ..setLineWidth(1)
      ..drawLine(size.x / 2, 0, size.x / 2, size.y)
      ..strokePath();
  }

  static List<pw.Widget> _fechamento(AvaliacaoCompleta av) {
    final obs = av.sessao.observacoes?.trim();
    final proxima = av.sessao.proximaAvaliacao;
    return _secao('Orientações', [
      if (obs != null && obs.isNotEmpty) _texto(obs, size: 10.5),
      if (obs == null || obs.isEmpty)
        _texto('Continue com o plano de treino combinado. Qualquer desconforto, avise seu treinador.', cor: _apoio),
      if (proxima != null) ...[
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: const pw.BoxDecoration(color: _fundo, borderRadius: pw.BorderRadius.all(pw.Radius.circular(8))),
          child: pw.Row(children: [
            pw.Expanded(child: _rotulo('Próxima avaliação')),
            _texto(Datas.longa(proxima), size: 12, bold: true),
          ]),
        ),
      ],
    ]);
  }
}
