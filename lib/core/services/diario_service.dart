import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/diario.dart';
import '../utils/datas.dart';
import '../utils/midia.dart';

/// O dia do aluno: diário alimentar, água e peso.
///
/// Tudo por `alunoId`, não pelo usuário logado: o profissional usa os
/// mesmos métodos de leitura para ver o diário de quem acompanha.
class DiarioService {
  static final _db = Supabase.instance.client;
  static const _bucket = 'diario-fotos';
  static const _validadeSegundos = 3600;

  // ── Diário ──────────────────────────────────────────────────

  /// Registros entre [de] e [ate] (inclusive), do mais antigo ao mais novo
  /// dentro de cada dia, com a foto já assinada.
  static Future<List<RegistroDiario>> listar({
    required String alunoId,
    required DateTime de,
    DateTime? ate,
  }) async {
    var q = _db
        .from('diario_registros')
        .select()
        .eq('aluno_id', alunoId)
        .gte('data', Datas.iso(de));
    if (ate != null) q = q.lte('data', Datas.iso(ate));

    final linhas = List<Map<String, dynamic>>.from(
      await q.order('registrado_em', ascending: true),
    );
    final registros = linhas.map(RegistroDiario.doMapa).toList();
    return _assinar(registros);
  }

  /// Assina as fotos de uma vez. Um arquivo apagado no bucket não derruba
  /// a lista: o registro só fica sem foto.
  static Future<List<RegistroDiario>> _assinar(List<RegistroDiario> lista) async {
    final caminhos = lista.map((r) => r.fotoPath).whereType<String>().toList();
    if (caminhos.isEmpty) return lista;
    try {
      final resultados = await _db.storage
          .from(_bucket)
          .createSignedUrlsResult(caminhos, _validadeSegundos);
      final porCaminho = {
        for (final r in resultados.whereType<SignedUrlSuccess>()) r.path: r.signedUrl,
      };
      return [for (final r in lista) r.comUrl(porCaminho[r.fotoPath])];
    } catch (_) {
      return lista;
    }
  }

  static Future<void> registrar({
    required String alunoId,
    required DateTime dia,
    required String titulo,
    String? refeicaoId,
    String? descricao,
    Aderencia? aderencia,
    XFile? foto,
  }) async {
    String? caminho;
    if (foto != null) {
      final nome = foto.name.isNotEmpty ? foto.name : foto.path;
      final tipo = Midia.tipoDe(nome);
      if (tipo == null || !tipo.startsWith('image/')) {
        throw Exception(Midia.recusa(nome, video: false));
      }
      // A pasta é a permissão: a policy do bucket confere se o primeiro
      // segmento é um aluno do usuário logado.
      caminho = '$alunoId/${DateTime.now().millisecondsSinceEpoch}.${Midia.extensaoDe(nome)}';
      await _db.storage.from(_bucket).uploadBinary(
            caminho,
            await foto.readAsBytes(),
            fileOptions: FileOptions(contentType: tipo, upsert: false),
          );
    }

    try {
      await _db.from('diario_registros').insert({
        'aluno_id': alunoId,
        'data': Datas.iso(dia),
        'refeicao_id': refeicaoId,
        'titulo': titulo,
        'descricao': (descricao?.trim().isEmpty ?? true) ? null : descricao!.trim(),
        'aderencia': aderencia?.name,
        'foto_path': caminho,
      });
    } catch (e) {
      // Sem a linha, a foto ficaria órfã no bucket ocupando espaço do
      // aluno para sempre.
      if (caminho != null) {
        await _db.storage.from(_bucket).remove([caminho]).catchError((_) => <FileObject>[]);
      }
      rethrow;
    }
  }

  static Future<void> excluir(RegistroDiario r) async {
    await _db.from('diario_registros').delete().eq('id', r.id);
    if (r.fotoPath != null) {
      await _db.storage.from(_bucket).remove([r.fotoPath!]).catchError((_) => <FileObject>[]);
    }
  }

  // ── Água ────────────────────────────────────────────────────

  /// Os copos do dia, do primeiro ao último.
  static Future<List<({String id, int ml})>> aguaDoDia(String alunoId, DateTime dia) async {
    final linhas = await _db
        .from('agua_registros')
        .select('id, ml')
        .eq('aluno_id', alunoId)
        .eq('data', Datas.iso(dia))
        .order('registrado_em', ascending: true);
    return [
      for (final l in List<Map<String, dynamic>>.from(linhas))
        (id: l['id'] as String, ml: (l['ml'] as num).toInt()),
    ];
  }

  /// Devolve o id do registro, para o "desfazer" apagar exatamente ele.
  static Future<String> beberAgua(String alunoId, DateTime dia, int ml) async {
    final linha = await _db
        .from('agua_registros')
        .insert({'aluno_id': alunoId, 'data': Datas.iso(dia), 'ml': ml})
        .select('id')
        .single();
    return linha['id'] as String;
  }

  static Future<void> apagarAgua(String id) async {
    await _db.from('agua_registros').delete().eq('id', id);
  }

  /// Total por dia nos últimos [dias] — para o profissional ver a semana.
  static Future<Map<DateTime, int>> aguaPorDia(String alunoId, {int dias = 7}) async {
    final de = Datas.dia(DateTime.now()).subtract(Duration(days: dias - 1));
    final linhas = await _db
        .from('agua_registros')
        .select('data, ml')
        .eq('aluno_id', alunoId)
        .gte('data', Datas.iso(de));
    final total = <DateTime, int>{};
    for (final l in List<Map<String, dynamic>>.from(linhas)) {
      final d = Datas.ler(l['data']);
      if (d == null) continue;
      final k = Datas.dia(d);
      total[k] = (total[k] ?? 0) + (l['ml'] as num).toInt();
    }
    return total;
  }

  // ── Peso ────────────────────────────────────────────────────

  /// Do mais antigo ao mais recente: é a ordem que o gráfico desenha.
  static Future<List<RegistroPeso>> pesos(String alunoId, {int limite = 60}) async {
    final linhas = await _db
        .from('peso_registros')
        .select('id, data, peso_kg')
        .eq('aluno_id', alunoId)
        .order('data', ascending: false)
        .limit(limite);
    return List<Map<String, dynamic>>.from(linhas)
        .map(RegistroPeso.doMapa)
        .toList()
        .reversed
        .toList();
  }

  static Future<void> registrarPeso(String alunoId, double pesoKg, {DateTime? dia}) async {
    await _db.from('peso_registros').insert({
      'aluno_id': alunoId,
      'data': Datas.iso(dia ?? DateTime.now()),
      'peso_kg': pesoKg,
    });
  }

  /// Meta de água do dia, em ml. A do plano quando há; senão 35 ml por kg
  /// (a recomendação usual para adultos), e 2 L quando nem o peso se sabe.
  static int metaAgua({double? metaDoPlano, double? pesoKg}) {
    if (metaDoPlano != null && metaDoPlano > 0) return metaDoPlano.round();
    if (pesoKg != null && pesoKg > 0) return ((pesoKg * 35) / 50).round() * 50;
    return 2000;
  }
}
