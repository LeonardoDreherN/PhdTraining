import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversa.dart';

/// Agenda de consultas: o profissional agenda, o aluno responde e avalia.
class AgendaService {
  static final _db = Supabase.instance.client;

  /// Consultas do profissional entre [de] e [ate], com o aluno junto.
  static Future<List<Consulta>> doProfissional({required DateTime de, required DateTime ate}) async {
    final linhas = await _db
        .from('consultas')
        .select('*, alunos(id, nome, foto_url, whatsapp)')
        .eq('personal_id', _db.auth.currentUser!.id)
        .gte('inicio', de.toUtc().toIso8601String())
        .lt('inicio', ate.toUtc().toIso8601String())
        .order('inicio', ascending: true);
    return List<Map<String, dynamic>>.from(linhas).map(Consulta.doMapa).toList();
  }

  /// As consultas do aluno: as futuras e as dos últimos 30 dias (para ele
  /// avaliar a que acabou de acontecer).
  static Future<List<Consulta>> doAluno(String alunoId) async {
    final de = DateTime.now().subtract(const Duration(days: 30));
    final linhas = await _db
        .from('consultas')
        .select()
        .eq('aluno_id', alunoId)
        .gte('inicio', de.toUtc().toIso8601String())
        .order('inicio', ascending: true);
    return List<Map<String, dynamic>>.from(linhas).map(Consulta.doMapa).toList();
  }

  static Future<void> salvar({
    String? id,
    required String alunoId,
    required DateTime inicio,
    required int duracaoMin,
    required TipoConsulta tipo,
    String? local,
    String? link,
    String? observacoes,
  }) async {
    String? limpo(String? s) => (s?.trim().isEmpty ?? true) ? null : s!.trim();
    final dados = {
      'aluno_id': alunoId,
      'inicio': inicio.toUtc().toIso8601String(),
      'duracao_min': duracaoMin,
      'tipo': tipo.name,
      'local': limpo(local),
      'link': limpo(link),
      'observacoes': limpo(observacoes),
    };
    if (id == null) {
      await _db.from('consultas').insert(dados);
    } else {
      // Mudou data ou hora: a confirmação antiga não vale para o horário
      // novo, então volta a aguardar o aluno.
      await _db.from('consultas').update({
        ...dados,
        'status': 'agendada',
        'respondida_em': null,
      }).eq('id', id);
    }
  }

  static Future<void> mudarStatus(String id, StatusConsulta status) async {
    await _db.from('consultas').update({'status': status.name}).eq('id', id);
  }

  static Future<void> excluir(String id) async {
    await _db.from('consultas').delete().eq('id', id);
  }

  // ── Aluno ───────────────────────────────────────────────────

  static Future<void> responder(String id, {required bool confirmar}) async {
    await _db.rpc('responder_consulta', params: {
      'p_consulta_id': id,
      'p_acao': confirmar ? 'confirmar' : 'remarcar',
    });
  }

  static Future<void> avaliar(String id, int nota, String? comentario) async {
    await _db.rpc('avaliar_consulta', params: {
      'p_consulta_id': id,
      'p_nota': nota,
      'p_comentario': comentario,
    });
  }
}
