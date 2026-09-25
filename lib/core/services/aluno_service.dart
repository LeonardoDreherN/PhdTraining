import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/aluno.dart';

class AlunoService {
  static final _db = Supabase.instance.client;
  static String get _personalId => _db.auth.currentUser!.id;

  /// Janela usada para calcular adesão e "sem treinar há X dias".
  static const _janelaDias = 30;

  /// Lista os alunos já com ficha, último treino e adesão.
  ///
  /// Três consultas em vez de N+1: buscar as execuções de cada aluno dentro
  /// do loop faria uma ida ao servidor por linha da lista, e com 60 alunos
  /// a tela levaria segundos para montar.
  static Future<List<Aluno>> listarComResumo() async {
    final desde = DateTime.now().subtract(const Duration(days: _janelaDias));

    final resultados = await Future.wait([
      _db.from('alunos').select().eq('personal_id', _personalId).order('nome'),
      _db
          .from('aluno_fichas')
          .select('aluno_id, dias_semana')
          .eq('ativa', true),
      _db
          .from('treino_execucoes')
          .select('aluno_id, executado_em')
          .eq('personal_id', _personalId)
          .gte('executado_em', desde.toIso8601String()),
    ]);

    final linhas = List<Map<String, dynamic>>.from(resultados[0]);
    final fichas = List<Map<String, dynamic>>.from(resultados[1]);
    final execucoes = List<Map<String, dynamic>>.from(resultados[2]);

    // Quantos treinos por semana cada aluno deveria fazer, somando os dias
    // de todas as fichas ativas dele.
    final diasPorSemana = <String, int>{};
    for (final f in fichas) {
      final id = f['aluno_id'] as String?;
      if (id == null) continue;
      final dias = (f['dias_semana'] as List?)?.length ?? 0;
      diasPorSemana[id] = (diasPorSemana[id] ?? 0) + dias;
    }

    final ultimo = <String, DateTime>{};
    final contagem = <String, int>{};
    for (final e in execucoes) {
      final id = e['aluno_id'] as String?;
      final quando = DateTime.tryParse(e['executado_em'] as String? ?? '');
      if (id == null || quando == null) continue;
      contagem[id] = (contagem[id] ?? 0) + 1;
      final atual = ultimo[id];
      if (atual == null || quando.isAfter(atual)) ultimo[id] = quando;
    }

    return linhas.map((m) {
      final id = m['id'] as String;
      final porSemana = diasPorSemana[id] ?? 0;

      // Sem ficha não há denominador: adesão fica nula em vez de zero.
      double? adesao;
      if (porSemana > 0) {
        final esperado = porSemana * (_janelaDias / 7);
        adesao = ((contagem[id] ?? 0) / esperado).clamp(0.0, 1.0);
      }

      return Aluno.doMapa(
        m,
        ultimoTreino: ultimo[id],
        temFicha: porSemana > 0 || diasPorSemana.containsKey(id),
        adesao: adesao,
      );
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> listar({bool? ativo}) async {
    var query = _db
        .from('alunos')
        .select()
        .eq('personal_id', _personalId);

    if (ativo != null) {
      query = query.eq('ativo', ativo);
    }

    return await query.order('nome');
  }

  static Future<Map<String, dynamic>> cadastrar({
    required String nome,
    required String email,
    required String senha,
    String? whatsapp,
    String? dataNascimento,
    String? genero,
    String? grupo,
    String anamneseTipo = 'nenhuma',
  }) async {
    // Cria o usuário auth via HTTP sem afetar a sessão do personal
    final authResponse = await http.post(
      Uri.parse('${SupabaseConfig.url}/auth/v1/signup'),
      headers: {
        'apikey': SupabaseConfig.anonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': senha,
        'data': {'nome': nome, 'role': 'aluno'},
      }),
    );

    final authData = jsonDecode(authResponse.body);
    final userId = authData['user']?['id'] as String?;

    // Cria o registro na tabela alunos
    final data = await _db.from('alunos').insert({
      'personal_id': _personalId,
      'user_id': userId,
      'nome': nome,
      'email': email,
      'whatsapp': whatsapp,
      'data_nascimento': dataNascimento,
      'genero': genero,
      'grupo': grupo,
      'ativo': true,
      'anamnese_tipo': anamneseTipo,
      'anamnese_preenchida': false,
    }).select().single();

    return data;
  }

  static Future<void> atualizar(String id, Map<String, dynamic> dados) async {
    await _db.from('alunos').update(dados).eq('id', id);
  }

  static Future<void> alterarStatus(String id, bool ativo) async {
    await _db.from('alunos').update({'ativo': ativo}).eq('id', id);
  }

  static Future<void> deletar(String id) async {
    await _db.from('alunos').delete().eq('id', id);
  }

  static Future<Map<String, int>> contagem() async {
    final ativos = await _db
        .from('alunos')
        .select()
        .eq('personal_id', _personalId)
        .eq('ativo', true);

    final inativos = await _db
        .from('alunos')
        .select()
        .eq('personal_id', _personalId)
        .eq('ativo', false);

    return {
      'ativos': (ativos as List).length,
      'inativos': (inativos as List).length,
    };
  }
}
