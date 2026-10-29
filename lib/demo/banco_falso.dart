import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Um Supabase de mentira, em memória, para a demonstração.
///
/// Entra no lugar do servidor pelo `httpClient` do `Supabase.initialize`:
/// as telas e os serviços continuam os mesmos, sem saber que não há banco
/// de verdade. Cobre só o pedaço do PostgREST e do Storage que a avaliação
/// física e a home do aluno usam — filtros `eq`, `lt`, `gte`, `in`, `not.is.null`, `order`, `limit`,
/// upsert, update e delete.
///
/// Não vai para produção: só as demos de `lib/demo/` usam isto.
class BancoFalso {
  BancoFalso(Map<String, List<Map<String, dynamic>>> inicial)
      : _tabelas = {for (final e in inicial.entries) e.key: [...e.value]};

  final Map<String, List<Map<String, dynamic>>> _tabelas;
  final _rand = Random();

  /// Fotos que o "storage" conhece. O resto vira uma foto genérica.
  static const fotosConhecidas = {'frente.png', 'costas.png', 'lado_dir.png', 'lado_esq.png'};

  http.Client get cliente => MockClient(_responder);

  // Toda resposta leva `request: req`: o postgrest lê `response.request!`
  // e quebra com "Null check operator" sem isso.

  Future<http.Response> _responder(http.Request req) async {
    final caminho = req.url.path;
    if (caminho.contains('/storage/v1/')) return _storage(req);
    if (caminho.contains('/rest/v1/')) return _rest(req);
    // Auth e o resto: a demo não tem login.
    return http.Response('{}', 200, headers: _json, request: req);
  }

  static const _json = {'content-type': 'application/json; charset=utf-8'};

  String _id() => List.generate(32, (_) => _rand.nextInt(16).toRadixString(16)).join();

  // ── PostgREST ───────────────────────────────────────────────

  Future<http.Response> _rest(http.Request req) async {
    final tabela = req.url.pathSegments.last;
    final linhas = _tabelas.putIfAbsent(tabela, () => []);
    final params = req.url.queryParametersAll;
    final filtros = <String, String>{
      for (final e in params.entries)
        if (!const {'select', 'order', 'limit', 'on_conflict', 'offset'}.contains(e.key))
          e.key: e.value.first,
    };
    final prefer = req.headers['prefer'] ?? req.headers['Prefer'] ?? '';
    final objeto = (req.headers['accept'] ?? req.headers['Accept'] ?? '').contains('vnd.pgrst.object');
    final representar = prefer.contains('return=representation');

    List<Map<String, dynamic>> resultado;
    switch (req.method) {
      case 'GET':
        resultado = linhas.where((l) => _passa(l, filtros)).toList();
        _ordenar(resultado, params['order']?.first);
        final limite = int.tryParse(params['limit']?.first ?? '');
        if (limite != null && resultado.length > limite) resultado = resultado.sublist(0, limite);
        break;
      case 'POST':
        final corpo = jsonDecode(req.body);
        final novas = corpo is List ? corpo.cast<Map<String, dynamic>>() : [corpo as Map<String, dynamic>];
        final conflito = params['on_conflict']?.first.split(',');
        resultado = [];
        for (final n in novas) {
          Map<String, dynamic>? existente;
          if (conflito != null) {
            for (final l in linhas) {
              if (conflito.every((c) => '${l[c]}' == '${n[c]}')) existente = l;
            }
          }
          if (existente != null) {
            if (prefer.contains('ignore-duplicates')) continue;
            existente.addAll(n);
            resultado.add(existente);
          } else {
            final linha = {
              'id': _id(),
              'criado_em': DateTime.now().toUtc().toIso8601String(),
              ...n,
            };
            linhas.add(linha);
            resultado.add(linha);
          }
        }
        break;
      case 'PATCH':
        final campos = jsonDecode(req.body) as Map<String, dynamic>;
        resultado = linhas.where((l) => _passa(l, filtros)).toList();
        for (final l in resultado) {
          l.addAll(campos);
        }
        break;
      case 'DELETE':
        resultado = linhas.where((l) => _passa(l, filtros)).toList();
        linhas.removeWhere(resultado.contains);
        break;
      default:
        resultado = [];
    }

    if (req.method != 'GET' && !representar) return http.Response('', 201, request: req);
    if (objeto) {
      if (resultado.length != 1) {
        return http.Response(
          jsonEncode({'code': 'PGRST116', 'message': 'JSON object requested, multiple (or no) rows returned'}),
          406,
          headers: _json,
          request: req,
        );
      }
      return http.Response(jsonEncode(resultado.first), 200, headers: _json, request: req);
    }
    return http.Response(jsonEncode(resultado), 200, headers: _json, request: req);
  }

  bool _passa(Map<String, dynamic> linha, Map<String, String> filtros) {
    for (final e in filtros.entries) {
      final v = linha[e.key];
      final f = e.value;
      if (f.startsWith('eq.')) {
        if ('$v' != f.substring(3)) return false;
      } else if (f.startsWith('lt.')) {
        if (v == null || _compara(v, f.substring(3)) >= 0) return false;
      } else if (f.startsWith('gt.')) {
        if (v == null || _compara(v, f.substring(3)) <= 0) return false;
      } else if (f.startsWith('gte.')) {
        if (v == null || _compara(v, f.substring(4)) < 0) return false;
      } else if (f.startsWith('lte.')) {
        if (v == null || _compara(v, f.substring(4)) > 0) return false;
      } else if (f.startsWith('in.(')) {
        final valores = f.substring(4, f.length - 1).split(',').map((x) => x.replaceAll('"', ''));
        if (!valores.contains('$v')) return false;
      } else if (f == 'not.is.null') {
        if (v == null) return false;
      } else if (f == 'is.null') {
        if (v != null) return false;
      }
    }
    return true;
  }

  int _compara(Object a, String b) {
    if (a is num) return a.compareTo(num.tryParse(b) ?? 0);
    return '$a'.compareTo(b);
  }

  void _ordenar(List<Map<String, dynamic>> linhas, String? ordem) {
    if (ordem == null) return;
    final partes = ordem.split(',').first.split('.');
    final coluna = partes.first;
    final desc = partes.contains('desc');
    linhas.sort((a, b) {
      final x = a[coluna], y = b[coluna];
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      final c = x is num && y is num ? x.compareTo(y) : '$x'.compareTo('$y');
      return desc ? -c : c;
    });
  }

  // ── Storage ─────────────────────────────────────────────────

  Future<http.Response> _storage(http.Request req) async {
    final caminho = req.url.path;
    if (caminho.contains('/object/sign/')) {
      final corpo = jsonDecode(req.body) as Map<String, dynamic>;
      final paths = (corpo['paths'] as List).cast<String>();
      return http.Response(
        jsonEncode([
          for (final p in paths)
            {
              'path': p,
              // O cliente monta `<url>/storage/v1` + isto. A demo serve as
              // fotos de `storage/v1/demo/` ao lado do app.
              'signedURL': '/demo/${fotosConhecidas.contains(p.split('/').last) ? p.split('/').last : 'frente.png'}',
            },
        ]),
        200,
        headers: _json,
        request: req,
      );
    }
    if (req.method == 'POST' || req.method == 'PUT') {
      return http.Response(jsonEncode({'Key': caminho}), 200, headers: _json, request: req);
    }
    return http.Response('[]', 200, headers: _json, request: req);
  }
}
