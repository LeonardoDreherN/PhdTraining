import 'package:supabase_flutter/supabase_flutter.dart';

/// Como o acompanhamento nutricional deste aluno funciona.
///
/// A especificação pede que o profissional possa ajustar metas,
/// frequência e solicitações conforme o plano individual. Isto é essa
/// parte: o que ele decide, aluno a aluno.
class ConfigAcompanhamento {
  const ConfigAcompanhamento({
    this.pesoFrequenciaSemanas = 1,
    this.fotosMensais = false,
    this.checkinMensal = true,
  });

  /// De 1 a 4 semanas. Não existe diário de propósito — a
  /// especificação proíbe pedir ou incentivar pesagem diária, e o
  /// jeito de uma proibição durar é não ter a opção.
  final int pesoFrequenciaSemanas;

  /// O profissional pede as fotos de acompanhamento do mês. É o que
  /// destrava "Aluno disciplinado".
  final bool fotosMensais;

  final bool checkinMensal;

  String get frequenciaRotulo => switch (pesoFrequenciaSemanas) {
        1 => 'Toda semana',
        2 => 'A cada 15 dias',
        3 => 'A cada 3 semanas',
        _ => 'Uma vez por mês',
      };

  ConfigAcompanhamento copiaCom({
    int? pesoFrequenciaSemanas,
    bool? fotosMensais,
    bool? checkinMensal,
  }) =>
      ConfigAcompanhamento(
        pesoFrequenciaSemanas:
            pesoFrequenciaSemanas ?? this.pesoFrequenciaSemanas,
        fotosMensais: fotosMensais ?? this.fotosMensais,
        checkinMensal: checkinMensal ?? this.checkinMensal,
      );

  factory ConfigAcompanhamento.doMapa(Map<String, dynamic> m) =>
      ConfigAcompanhamento(
        pesoFrequenciaSemanas:
            (m['peso_frequencia_semanas'] as num?)?.toInt() ?? 1,
        fotosMensais: m['fotos_mensais'] as bool? ?? false,
        checkinMensal: m['checkin_mensal'] as bool? ?? true,
      );

  Map<String, dynamic> paraBanco() => {
        'peso_frequencia_semanas': pesoFrequenciaSemanas,
        'fotos_mensais': fotosMensais,
        'checkin_mensal': checkinMensal,
      };
}

class AcompanhamentoService {
  static final _db = Supabase.instance.client;

  /// Sem linha gravada valem os padrões — que são o comportamento que o
  /// app já tinha. Nenhum aluno muda de regra por esta tabela existir.
  static Future<ConfigAcompanhamento> doAluno(String alunoId) async {
    final linha = await _db
        .from('acompanhamento_config')
        .select()
        .eq('aluno_id', alunoId)
        .maybeSingle();

    return linha == null
        ? const ConfigAcompanhamento()
        : ConfigAcompanhamento.doMapa(linha);
  }

  static Future<void> salvar(String alunoId, ConfigAcompanhamento c) async {
    await _db.from('acompanhamento_config').upsert({
      'aluno_id': alunoId,
      ...c.paraBanco(),
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'aluno_id');
  }
}
