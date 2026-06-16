import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

class AlunoService {
  static final _db = Supabase.instance.client;
  static String get _personalId => _db.auth.currentUser!.id;

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
