import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/checkin.dart';
import '../utils/datas.dart';

/// O check-in nutricional mensal.
///
/// Gravar é do aluno; ler é de quem acompanha. Quem garante isso é a
/// RLS da 0030, não este arquivo — aqui só se pede.
class CheckinService {
  static final _db = Supabase.instance.client;

  static const _tabela = 'nutricao_checkins';

  /// O check-in de um mês, ou nulo se ainda não existe.
  ///
  /// Sem `mes`, o mês corrente — que é o que a tela do aluno pergunta
  /// para saber se o cartão aparece.
  static Future<CheckinNutricional?> doMes(
    String alunoId, {
    DateTime? mes,
  }) async {
    final ref = mes ?? CheckinNutricional.mesAtual();
    final linha = await _db
        .from(_tabela)
        .select()
        .eq('aluno_id', alunoId)
        .eq('mes', Datas.iso(DateTime(ref.year, ref.month)))
        .maybeSingle();

    return linha == null ? null : CheckinNutricional.doMapa(linha);
  }

  /// Do mais recente para o mais antigo — é a ordem em que o
  /// profissional lê: o mês passado importa mais que o de março.
  static Future<List<CheckinNutricional>> historico(
    String alunoId, {
    int limite = 24,
  }) async {
    final linhas = await _db
        .from(_tabela)
        .select()
        .eq('aluno_id', alunoId)
        .order('mes', ascending: false)
        .limit(limite);

    return [
      for (final l in List<Map<String, dynamic>>.from(linhas))
        CheckinNutricional.doMapa(l),
    ];
  }

  /// Grava o check-in do mês. Responder de novo no mesmo mês corrige o
  /// que já estava lá — não cria um segundo.
  ///
  /// A chave única (aluno_id, mes) é o que impede o duplicado, e o
  /// `onConflict` faz o Postgres tratar o segundo envio como correção
  /// em vez de erro.
  static Future<CheckinNutricional> salvar(
    String alunoId,
    CheckinNutricional c,
  ) async {
    final linha = await _db
        .from(_tabela)
        .upsert(
          {
            'aluno_id': alunoId,
            ...c.paraBanco(),
            'atualizado_em': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'aluno_id,mes',
        )
        .select()
        .single();

    return CheckinNutricional.doMapa(linha);
  }
}
