import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conquista.dart';

/// Conquistas e desbloqueios.
///
/// Quem decide o que foi merecido é o banco, em `conceder_conquistas`:
/// ele recalcula os critérios a partir das execuções e dos registros
/// reais. Este serviço pede e lê — nunca concede. Deixar o app inserir
/// significaria que qualquer um com a chave anônima se dá 500 treinos.
class ConquistaService {
  static final _db = Supabase.instance.client;

  /// Os números do aluno, de onde sai todo progresso.
  static Future<NumerosDoAluno> numeros(String alunoId) async {
    final r = await _db.rpc('numeros_do_aluno', params: {'p_aluno_id': alunoId});
    final lista = List<Map<String, dynamic>>.from(r as List);
    return lista.isEmpty
        ? const NumerosDoAluno()
        : NumerosDoAluno.doMapa(lista.first);
  }

  static Future<List<ConquistaDoAluno>> doAluno(String alunoId) async {
    final linhas = await _db
        .from('aluno_conquistas')
        .select()
        .eq('aluno_id', alunoId)
        .order('desbloqueado_em', ascending: false);
    return List<Map<String, dynamic>>.from(linhas)
        .map(ConquistaDoAluno.doMapa)
        .toList();
  }

  /// Recalcula e grava o que foi merecido. Devolve só as NOVAS.
  ///
  /// É com essa lista que a tela comemora: sem ela, o app teria de
  /// comparar o antes e o depois e acertaria na maioria das vezes.
  ///
  /// Chamada ao concluir um treino e ao abrir a tela de conquistas. É
  /// idempotente — rodar dez vezes não duplica nem muda a data.
  static Future<List<String>> conceder(String alunoId) async {
    final r =
        await _db.rpc('conceder_conquistas', params: {'p_aluno_id': alunoId});
    return [
      for (final l in List<Map<String, dynamic>>.from(r as List))
        l['conquista'] as String,
    ];
  }

  /// Os exercícios que o aluno já recebeu em alguma prescrição.
  ///
  /// Só os desbloqueados: a especificação é explícita em não mostrar os
  /// outros nem como bloqueados. Mostrar o que ele nunca viu viraria
  /// vitrine de treino que não é dele.
  static Future<List<Map<String, dynamic>>> exerciciosDesbloqueados(
    String alunoId,
  ) async {
    final linhas = await _db
        .from('aluno_exercicios')
        .select('desbloqueado_em, '
            'exercicios(id, nome, grupo_muscular, equipamento, '
            'midia_url, thumb_url, video_url)')
        .eq('aluno_id', alunoId)
        .order('desbloqueado_em', ascending: false);

    return [
      for (final l in List<Map<String, dynamic>>.from(linhas))
        if (l['exercicios'] != null)
          {
            ...Map<String, dynamic>.from(l['exercicios'] as Map),
            'desbloqueado_em': l['desbloqueado_em'],
          },
    ];
  }
}
