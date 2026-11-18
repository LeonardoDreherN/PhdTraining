import 'package:flutter/material.dart';

import '../utils/datas.dart';

/// Um check-in nutricional mensal: o autorrelato do aluno sobre o mês.
///
/// Quem preenche é o ALUNO. O profissional lê — não responde no lugar
/// dele, e o banco impede (ver a 0030). Autorrelato preenchido por
/// outra pessoa não é autorrelato, e a conquista de constância viraria
/// medalha por algo que o aluno não fez.
class CheckinNutricional {
  const CheckinNutricional({
    this.id,
    required this.mes,
    required this.adesao,
    this.energia,
    this.dificuldades = const [],
    this.intestino,
    this.observacoes,
    this.criadoEm,
  });

  final String? id;

  /// Sempre o dia 1 do mês de referência. Mês civil, não janela de 30
  /// dias: com janela corrida, responder dia 28 e dia 2 seriam dois
  /// check-ins em cinco dias.
  final DateTime mes;

  /// 1 a 5, o quanto conseguiu seguir o plano. O único campo
  /// obrigatório — é dele que sai a leitura rápida do profissional.
  final int adesao;

  final int? energia;

  /// Códigos do catálogo [dificuldadesCheckin].
  final List<String> dificuldades;

  /// Código de [intestinoCheckin]. Opcional de propósito: é a pergunta
  /// mais invasiva do formulário.
  final String? intestino;

  final String? observacoes;
  final DateTime? criadoEm;

  String get mesNome => Datas.mesAno(mes);

  /// O rótulo da escala de adesão. Mora aqui para a tela do aluno e a
  /// do profissional nunca divergirem no texto do mesmo número.
  String get adesaoRotulo => switch (adesao) {
        1 => 'Não consegui seguir',
        2 => 'Segui pouco',
        3 => 'Mais ou menos',
        4 => 'Segui bem',
        5 => 'Segui tudo',
        _ => '—',
      };

  Color adesaoCor(Color ruim, Color medio, Color bom) => switch (adesao) {
        1 || 2 => ruim,
        3 => medio,
        _ => bom,
      };

  List<String> get dificuldadesRotulos => [
        for (final d in dificuldades)
          dificuldadesCheckin[d] ?? d,
      ];

  String? get intestinoRotulo =>
      intestino == null ? null : intestinoCheckin[intestino];

  factory CheckinNutricional.doMapa(Map<String, dynamic> m) =>
      CheckinNutricional(
        id: m['id'] as String?,
        mes: Datas.ler(m['mes']) ?? mesAtual(),
        adesao: (m['adesao'] as num?)?.toInt() ?? 3,
        energia: (m['energia'] as num?)?.toInt(),
        dificuldades: [
          for (final d in (m['dificuldades'] as List?) ?? const [])
            d.toString(),
        ],
        intestino: m['intestino'] as String?,
        observacoes: m['observacoes'] as String?,
        criadoEm: Datas.ler(m['criado_em']),
      );

  /// O que vai para o banco. Sem `id` nem `criado_em`: o banco cuida dos
  /// dois, e `aluno_id` é posto pelo serviço.
  Map<String, dynamic> paraBanco() => {
        'mes': Datas.iso(mes),
        'adesao': adesao,
        'energia': energia,
        'dificuldades': dificuldades,
        'intestino': intestino,
        'observacoes': (observacoes?.trim().isEmpty ?? true)
            ? null
            : observacoes!.trim(),
      };

  CheckinNutricional copiaCom({
    int? adesao,
    int? energia,
    List<String>? dificuldades,
    String? intestino,
    bool limpaIntestino = false,
    String? observacoes,
  }) =>
      CheckinNutricional(
        id: id,
        mes: mes,
        adesao: adesao ?? this.adesao,
        energia: energia ?? this.energia,
        dificuldades: dificuldades ?? this.dificuldades,
        intestino: limpaIntestino ? null : (intestino ?? this.intestino),
        observacoes: observacoes ?? this.observacoes,
        criadoEm: criadoEm,
      );

  /// O primeiro dia do mês corrente — o `mes` de todo check-in de hoje.
  static DateTime mesAtual() {
    final h = DateTime.now();
    return DateTime(h.year, h.month);
  }
}

/// Os rótulos das dificuldades. Códigos no banco, texto aqui: mudar a
/// redação de uma opção não deveria pedir migration.
const dificuldadesCheckin = <String, String>{
  'rotina': 'Rotina corrida',
  'fome': 'Fome entre as refeições',
  'custo': 'Custo dos alimentos',
  'preparo': 'Tempo de preparo',
  'social': 'Eventos e saídas',
  'viagem': 'Viagens',
  'ansiedade': 'Comer por ansiedade',
  'enjoo': 'Cansei das refeições',
  'nenhuma': 'Nenhuma dificuldade',
};

const intestinoCheckin = <String, String>{
  'bem': 'Funcionando bem',
  'inchaco': 'Inchaço',
  'constipacao': 'Preso',
  'solto': 'Solto',
};
