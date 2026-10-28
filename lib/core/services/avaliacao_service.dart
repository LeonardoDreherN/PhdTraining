import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/avaliacao.dart';
import '../utils/avaliacao_calculos.dart';
import '../utils/datas.dart';
import '../utils/midia.dart';

/// Leitura e escrita da avaliação física por sessão (um dia).
///
/// As tabelas de teste do 0001 continuam sendo escritas pelos formulários
/// antigos; aqui elas só são lidas, agrupadas por `data_avaliacao`.
class AvaliacaoService {
  static final _db = Supabase.instance.client;
  static const _bucket = 'progresso-fotos';
  static const _validadeSegundos = 3600;

  static const _tabelasDeTeste = [
    'avaliacao_morfologica_dobras',
    'avaliacao_morfologica_bioimpedancia',
    'avaliacao_neuromotores_flexibilidade',
    'avaliacao_neuromotores_resistencia',
    'avaliacao_neuromotores_impulsao',
    'avaliacao_neuromotores_carga',
    'avaliacao_cardio',
    'avaliacao_postural',
  ];

  // ── Lista ──────────────────────────────────────────────────

  static Future<List<ResumoSessao>> listar(String alunoId) async {
    final sessoes = _db
        .from('avaliacoes')
        .select()
        .eq('aluno_id', alunoId)
        .order('data_avaliacao', ascending: false);

    // Peso e % de gordura vêm do teste, quando a sessão não tem.
    final composicao = [
      for (final t in _tabelasDeTeste.take(2))
        _db
            .from(t)
            .select('data_avaliacao, peso, perc_gordura, criado_em')
            .eq('aluno_id', alunoId)
            .order('criado_em', ascending: false),
    ];
    final outros = [
      for (final t in _tabelasDeTeste.skip(2))
        _db.from(t).select('data_avaliacao').eq('aluno_id', alunoId),
    ];

    final r = await Future.wait([sessoes, ...composicao, ...outros]);

    final contagem = <String, int>{};
    for (final lista in r.skip(1)) {
      for (final linha in lista) {
        final d = linha['data_avaliacao'] as String?;
        if (d != null) contagem[d] = (contagem[d] ?? 0) + 1;
      }
    }

    // Fica a primeira linha de cada data: as listas vêm da mais recente
    // para a mais antiga. Dobra antes de bioimpedância, pelo mesmo motivo
    // de `AvaliacaoCompleta.percGordura`.
    final porData = <String, Map<String, dynamic>>{};
    for (final lista in [r[1], r[2]]) {
      for (final linha in lista) {
        porData.putIfAbsent(linha['data_avaliacao'] as String, () => linha);
      }
    }

    return [
      for (final s in r[0])
        () {
          final sessao = AvaliacaoSessao.doMapa(s);
          final iso = Datas.iso(sessao.data);
          final teste = porData[iso];
          return ResumoSessao(
            sessao: sessao,
            peso: sessao.peso ?? (teste?['peso'] as num?)?.toDouble(),
            percGordura: (teste?['perc_gordura'] as num?)?.toDouble(),
            testes: contagem[iso] ?? 0,
          );
        }(),
    ];
  }

  /// Cria (ou devolve, se já existe) a sessão do dia.
  static Future<AvaliacaoSessao> abrir(String alunoId, DateTime data) async {
    // Lista, e não `maybeSingle`: quando a sessão já existe o upsert não
    // devolve linha, e o PostgREST responde 406 a um pedido de objeto
    // único vazio. O cliente só converte esse 406 em `null` se reconhecer
    // o texto do erro, que mudou entre versões do PostgREST.
    final linhas = await _db
        .from('avaliacoes')
        .upsert(
          {'aluno_id': alunoId, 'data_avaliacao': Datas.iso(data)},
          onConflict: 'aluno_id,data_avaliacao',
          // Sem isto o upsert sobrescreveria as medidas de uma sessão que
          // já existe com nulos.
          ignoreDuplicates: true,
        )
        .select();
    if (linhas.isNotEmpty) return AvaliacaoSessao.doMapa(linhas.first);

    // `ignoreDuplicates` não devolve a linha que já existia.
    final existente = await _db
        .from('avaliacoes')
        .select()
        .eq('aluno_id', alunoId)
        .eq('data_avaliacao', Datas.iso(data))
        .single();
    return AvaliacaoSessao.doMapa(existente);
  }

  static Future<void> salvarSessao(AvaliacaoSessao s) async {
    await _db
        .from('avaliacoes')
        .upsert(s.paraMapa(), onConflict: 'aluno_id,data_avaliacao');
  }

  /// Muda só as colunas passadas. A tela edita uma medida por vez; mandar
  /// a linha inteira sobrescreveria o que outra aba acabou de salvar.
  static Future<void> atualizar(String alunoId, DateTime data, Map<String, dynamic> campos) async {
    await _db
        .from('avaliacoes')
        .update({...campos, 'atualizado_em': DateTime.now().toUtc().toIso8601String()})
        .eq('aluno_id', alunoId)
        .eq('data_avaliacao', Datas.iso(data));
  }

  /// Apaga a sessão e TODOS os testes daquele dia, inclusive as fotos.
  static Future<void> excluir(String alunoId, DateTime data) async {
    final iso = Datas.iso(data);
    final postural = await _db
        .from('avaliacao_postural')
        .select()
        .eq('aluno_id', alunoId)
        .eq('data_avaliacao', iso)
        .maybeSingle();
    if (postural != null) {
      final caminhos = [
        for (final v in VistaPostural.values) postural[v.coluna] as String?,
      ].whereType<String>().where((c) => c.isNotEmpty).toList();
      if (caminhos.isNotEmpty) {
        try {
          await _db.storage.from(_bucket).remove(caminhos);
        } catch (_) {
          // Foto que sobra no bucket é lixo, não vazamento: ele é privado.
          // Não vale impedir a exclusão por isso.
        }
      }
    }

    await Future.wait([
      for (final t in _tabelasDeTeste)
        _db.from(t).delete().eq('aluno_id', alunoId).eq('data_avaliacao', iso),
    ]);
    // A sessão sai por último: se algum delete acima falhar, ela continua
    // de pé e o personal ainda enxerga o que sobrou.
    await _db
        .from('avaliacoes')
        .delete()
        .eq('aluno_id', alunoId)
        .eq('data_avaliacao', iso);
  }

  // ── Sessão completa ────────────────────────────────────────

  static Future<AvaliacaoCompleta> carregar(
    Map<String, dynamic> aluno,
    DateTime data,
  ) async {
    final alunoId = aluno['id'] as String;
    final sessao = await abrir(alunoId, data);

    final anteriores = await _db
        .from('avaliacoes')
        .select()
        .eq('aluno_id', alunoId)
        .lt('data_avaliacao', Datas.iso(data))
        .order('data_avaliacao', ascending: false)
        .limit(1);

    final atual = await _carregarDia(aluno, sessao);
    AvaliacaoCompleta? anterior;
    if (anteriores.isNotEmpty) {
      anterior = await _carregarDia(aluno, AvaliacaoSessao.doMapa(anteriores.first));
    }

    final estatura = atual.estatura ?? anterior?.estatura ?? await _ultimaEstatura(alunoId, data);

    return AvaliacaoCompleta(
      sessao: atual.sessao,
      aluno: aluno,
      dobras: atual.dobras,
      bioimpedancia: atual.bioimpedancia,
      flexibilidade: atual.flexibilidade,
      resistencia: atual.resistencia,
      impulsao: atual.impulsao,
      carga: atual.carga,
      cardio: atual.cardio,
      postural: atual.postural,
      estaturaAnterior: estatura,
      anterior: anterior,
    );
  }

  static Future<AvaliacaoCompleta> _carregarDia(
    Map<String, dynamic> aluno,
    AvaliacaoSessao sessao,
  ) async {
    final alunoId = aluno['id'] as String;
    final iso = Datas.iso(sessao.data);
    final r = await Future.wait([
      for (final t in _tabelasDeTeste)
        _db
            .from(t)
            .select()
            .eq('aluno_id', alunoId)
            .eq('data_avaliacao', iso)
            .order('criado_em', ascending: false),
    ]);

    final postural = r[7].isEmpty ? null : await _assinarPostural(r[7].first);

    return AvaliacaoCompleta(
      sessao: sessao,
      aluno: aluno,
      dobras: r[0].isEmpty ? null : r[0].first,
      bioimpedancia: r[1].isEmpty ? null : r[1].first,
      flexibilidade: r[2],
      resistencia: r[3],
      impulsao: r[4],
      carga: r[5],
      cardio: r[6],
      postural: postural,
    );
  }

  static Future<double?> _ultimaEstatura(String alunoId, DateTime antesDe) async {
    final linhas = await _db
        .from('avaliacoes')
        .select('estatura')
        .eq('aluno_id', alunoId)
        .lt('data_avaliacao', Datas.iso(antesDe))
        .not('estatura', 'is', null)
        .order('data_avaliacao', ascending: false)
        .limit(1);
    return linhas.isEmpty ? null : (linhas.first['estatura'] as num?)?.toDouble();
  }

  // ── Cardio ─────────────────────────────────────────────────

  /// Todos os testes cardiorrespiratórios do aluno, do mais novo ao mais
  /// antigo. É o que alimenta a evolução do VO₂máx.
  static Future<List<Map<String, dynamic>>> historicoCardio(String alunoId) async {
    return await _db
        .from('avaliacao_cardio')
        .select()
        .eq('aluno_id', alunoId)
        .order('data_avaliacao', ascending: false);
  }

  static Future<void> salvarCardio(Map<String, dynamic> dados) async {
    await _db
        .from('avaliacao_cardio')
        .upsert(dados, onConflict: 'aluno_id,data_avaliacao,protocolo');
  }

  static Future<void> excluirCardio(String id) async {
    await _db.from('avaliacao_cardio').delete().eq('id', id);
  }

  // ── Postural ───────────────────────────────────────────────

  /// A linha crua (com caminhos) e a mesma com URLs assinadas para exibir.
  static Future<({Map<String, dynamic>? linha, Map<String, String> urls})> carregarPostural(
    String alunoId,
    DateTime data,
  ) async {
    final linha = await _db
        .from('avaliacao_postural')
        .select()
        .eq('aluno_id', alunoId)
        .eq('data_avaliacao', Datas.iso(data))
        .maybeSingle();
    if (linha == null) return (linha: null, urls: const <String, String>{});
    final assinada = await _assinarPostural(linha);
    return (
      linha: linha,
      urls: {
        for (final v in VistaPostural.values)
          if (assinada[v.coluna] is String && (assinada[v.coluna] as String).startsWith('http'))
            v.coluna: assinada[v.coluna] as String,
      },
    );
  }

  /// Envia a foto e devolve o caminho no bucket. Não grava na tabela: a
  /// tela junta foto e checklist e salva tudo de uma vez.
  static Future<String> enviarFotoPostural({
    required String alunoId,
    required DateTime data,
    required VistaPostural vista,
    required XFile foto,
  }) async {
    final bytes = await foto.readAsBytes();
    final nome = foto.name.isNotEmpty ? foto.name : foto.path;
    final tipo = Midia.tipoDe(nome);
    if (tipo == null || !tipo.startsWith('image/')) {
      throw Exception(Midia.recusa(nome, video: false));
    }
    // A primeira pasta é o aluno: é o que a policy do bucket confere.
    final caminho = '$alunoId/postural/${Datas.iso(data)}_${vista.name}_'
        '${DateTime.now().millisecondsSinceEpoch}.${Midia.extensaoDe(nome)}';
    await _db.storage.from(_bucket).uploadBinary(
          caminho,
          bytes,
          fileOptions: FileOptions(contentType: tipo, upsert: false),
        );
    return caminho;
  }

  static Future<void> removerFoto(String caminho) async {
    try {
      await _db.storage.from(_bucket).remove([caminho]);
    } catch (_) {
      // Mesmo raciocínio de `excluir`: o bucket é privado.
    }
  }

  static Future<void> salvarPostural(Map<String, dynamic> dados) async {
    await _db
        .from('avaliacao_postural')
        .upsert(dados, onConflict: 'aluno_id,data_avaliacao');
  }

  /// Troca os caminhos das fotos por URLs assinadas, numa cópia.
  static Future<Map<String, dynamic>> _assinarPostural(Map<String, dynamic> linha) async {
    final copia = Map<String, dynamic>.from(linha);
    final caminhos = [
      for (final v in VistaPostural.values) linha[v.coluna] as String?,
    ].whereType<String>().where((c) => c.isNotEmpty && !c.startsWith('http')).toList();
    if (caminhos.isEmpty) return copia;
    try {
      final r = await _db.storage.from(_bucket).createSignedUrlsResult(caminhos, _validadeSegundos);
      final porCaminho = {
        for (final s in r.whereType<SignedUrlSuccess>()) s.path: s.signedUrl,
      };
      for (final v in VistaPostural.values) {
        final c = linha[v.coluna] as String?;
        if (c != null && porCaminho.containsKey(c)) copia[v.coluna] = porCaminho[c];
      }
    } catch (_) {
      // Sem assinatura a foto não aparece, mas o checklist sim.
    }
    return copia;
  }
}
