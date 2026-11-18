import 'package:flutter/material.dart';

/// Os números do aluno, como o banco devolve em `numeros_do_aluno`.
///
/// É deste registro que todo progresso é calculado — nenhuma tela faz a
/// própria conta, senão duas telas dariam números diferentes para a mesma
/// conquista.
class NumerosDoAluno {
  const NumerosDoAluno({
    this.treinos = 0,
    this.diasPrevistos = 0,
    this.semanasCompletas = 0,
    this.sequenciaSemanas = 0,
    this.sequenciaDias = 0,
    this.exercicios = 0,
    this.catalogo = 0,
    this.refeicoesFeitas = 0,
    this.diasPlanoCompleto = 0,
    this.sequenciaDiasPlano = 0,
    this.pesagens = 0,
    this.semanasComPeso = 0,
    this.fotosDiario = 0,
    this.diasAguaMeta = 0,
    this.mesesAcompanhamento = 0,
    this.checkins = 0,
    this.checkinsSeguidos = 0,
  });

  final int treinos;

  /// Quantos dias por semana a programação vigente pede. Zero é "sem
  /// ficha": aí não existe denominador e semana completa não existe.
  final int diasPrevistos;

  final int semanasCompletas;
  final int sequenciaSemanas;
  final int sequenciaDias;

  final int exercicios;

  /// O catálogo oficial da plataforma. É o denominador da barra de
  /// desbloqueios — os exercícios que cada personal cria ficam de fora,
  /// senão o percentual do aluno mudaria conforme o acervo do professor.
  final int catalogo;

  final int refeicoesFeitas;

  /// Dias em que TODAS as refeições do plano foram marcadas. Acumulado,
  /// não consecutivo — a especificação pede para não penalizar o aluno
  /// por uma falha pontual.
  final int diasPlanoCompleto;

  /// A maior sequência de dias 100% no plano. É o que vira "Semana
  /// consistente"; o acumulado vira os marcos de 1, 7, 15, 30 e 60.
  final int sequenciaDiasPlano;

  final int pesagens;

  /// Semanas seguidas com pelo menos um registro de peso. Mede
  /// REGULARIDADE, nunca redução: o valor do peso não entra em conta
  /// nenhuma, e não existe marco diário de propósito.
  final int semanasComPeso;

  final int fotosDiario;
  final int diasAguaMeta;

  /// Meses desde o início do plano ativo.
  final int mesesAcompanhamento;

  /// Check-ins mensais respondidos, ao todo.
  final int checkins;

  /// Meses seguidos com check-in, contando a corrida que termina neste
  /// mês OU no anterior. O mês corrente não quebra a sequência — ele
  /// ainda não acabou, e a medalha de constância não pode cair no dia 1.
  final int checkinsSeguidos;

  double get progressoCatalogo =>
      catalogo <= 0 ? 0 : (exercicios / catalogo).clamp(0.0, 1.0);

  factory NumerosDoAluno.doMapa(Map<String, dynamic> m) => NumerosDoAluno(
        treinos: _i(m['treinos']),
        diasPrevistos: _i(m['dias_previstos']),
        semanasCompletas: _i(m['semanas_completas']),
        sequenciaSemanas: _i(m['sequencia_semanas']),
        sequenciaDias: _i(m['sequencia_dias']),
        exercicios: _i(m['exercicios']),
        catalogo: _i(m['catalogo']),
        refeicoesFeitas: _i(m['refeicoes_feitas']),
        diasPlanoCompleto: _i(m['dias_plano_completo']),
        sequenciaDiasPlano: _i(m['sequencia_dias_plano']),
        pesagens: _i(m['pesagens']),
        semanasComPeso: _i(m['semanas_com_peso']),
        fotosDiario: _i(m['fotos_diario']),
        diasAguaMeta: _i(m['dias_agua_meta']),
        mesesAcompanhamento: _i(m['meses_acompanhamento']),
        checkins: _i(m['checkins']),
        checkinsSeguidos: _i(m['checkins_seguidos']),
      );

  static int _i(Object? v) => (v as num?)?.toInt() ?? 0;
}

enum CategoriaConquista { treino, nutricao }

/// Uma conquista do catálogo.
///
/// O catálogo mora aqui, e não no banco, porque é texto de interface:
/// muda junto com a tela e não precisa de migração para ganhar uma
/// medalha nova. O banco guarda só o que foi desbloqueado e quando.
class Conquista {
  const Conquista({
    required this.codigo,
    required this.categoria,
    required this.nome,
    required this.descricao,
    required this.meta,
    required this.icone,
    required this.valorDe,
  });

  final String codigo;
  final CategoriaConquista categoria;
  final String nome;
  final String descricao;

  /// Quanto é preciso para desbloquear.
  final int meta;

  final IconData icone;

  /// De onde sai o número do aluno para esta conquista.
  final int Function(NumerosDoAluno) valorDe;

  /// 0 a 1. Serve para a barra de "falta pouco" nas que ainda não vieram.
  double progresso(NumerosDoAluno n) =>
      meta <= 0 ? 0 : (valorDe(n) / meta).clamp(0.0, 1.0);

  /// "37 de 50" — o que falta, em número, não em porcentagem. Porcentagem
  /// de treino não diz nada a quem quer saber quantos faltam.
  String progressoTexto(NumerosDoAluno n) {
    final v = valorDe(n);
    return '${v > meta ? meta : v} de $meta';
  }

  static const _treinos = [1, 10, 25, 50, 100, 250, 500];
  static const _semanas = [1, 2, 4, 8, 12, 26];

  /// Catálogo de treino.
  ///
  /// As de consistência medem semanas cumprindo a PRÓPRIA programação,
  /// não quantidade de treinos: quem treina três vezes e cumpre as três
  /// vale igual a quem treina cinco e cumpre as cinco. É o critério
  /// central da especificação, e o que impede a medalha de virar prêmio
  /// para quem tem mais tempo livre.
  static final catalogoTreino = <Conquista>[
    for (final m in _treinos)
      Conquista(
        codigo: 'treinos_$m',
        categoria: CategoriaConquista.treino,
        nome: m == 1 ? 'O primeiro' : '$m treinos',
        descricao: m == 1
            ? 'Você concluiu seu primeiro treino.'
            : 'Concluir $m treinos.',
        meta: m,
        icone: Icons.fitness_center_rounded,
        valorDe: (n) => n.treinos,
      ),
    for (final m in _semanas)
      Conquista(
        codigo: 'semanas_$m',
        categoria: CategoriaConquista.treino,
        nome: switch (m) {
          1 => 'Semana cheia',
          26 => 'Meio ano',
          _ => '$m semanas seguidas',
        },
        descricao: m == 1
            ? 'Cumprir toda a programação de uma semana.'
            : 'Cumprir a programação $m semanas seguidas.',
        meta: m,
        icone: Icons.local_fire_department_rounded,
        valorDe: (n) => n.sequenciaSemanas,
      ),
  ];

  static const _diasNoPlano = [1, 7, 15, 30, 60];

  /// Catálogo de nutrição.
  ///
  /// Duas regras da especificação viraram decisão de código aqui:
  ///
  /// A conquista de peso premia a REGULARIDADE do registro, nunca a
  /// redução — o valor do peso não aparece em nenhum critério. E a
  /// frequência é semanal: não existe marco diário, porque empurrar o
  /// aluno à balança todo dia é o oposto do que o documento pede.
  static final catalogoNutricao = <Conquista>[
    for (final m in _diasNoPlano)
      Conquista(
        codigo: 'plano_$m',
        categoria: CategoriaConquista.nutricao,
        nome: m == 1 ? 'Primeiro dia' : '$m dias no plano',
        descricao: m == 1
            ? 'Concluir todas as refeições de um dia.'
            : 'Somar $m dias com todas as refeições concluídas.',
        meta: m,
        icone: Icons.restaurant_rounded,
        // Acumulado, não seguido: um dia fora não zera o que já foi.
        valorDe: (n) => n.diasPlanoCompleto,
      ),
    Conquista(
      codigo: 'plano_semana',
      categoria: CategoriaConquista.nutricao,
      nome: 'Semana consistente',
      descricao: 'Sete dias seguidos com o plano completo.',
      meta: 7,
      icone: Icons.calendar_month_rounded,
      valorDe: (n) => n.sequenciaDiasPlano,
    ),
    Conquista(
      codigo: 'peso_1',
      categoria: CategoriaConquista.nutricao,
      nome: 'Primeiro passo',
      descricao: 'Registrar o primeiro peso.',
      meta: 1,
      icone: Icons.monitor_weight_outlined,
      valorDe: (n) => n.pesagens,
    ),
    for (final m in [4, 12])
      Conquista(
        codigo: 'peso_$m',
        categoria: CategoriaConquista.nutricao,
        nome: m == 4 ? 'Amigo da balança' : 'Constância na balança',
        descricao: 'Registrar o peso em $m semanas seguidas.',
        meta: m,
        icone: Icons.monitor_weight_rounded,
        valorDe: (n) => n.semanasComPeso,
      ),
    Conquista(
      codigo: 'fotos_1',
      categoria: CategoriaConquista.nutricao,
      nome: 'Primeira foto',
      descricao: 'Enviar o primeiro registro fotográfico.',
      meta: 1,
      icone: Icons.photo_camera_outlined,
      valorDe: (n) => n.fotosDiario,
    ),
    Conquista(
      codigo: 'fotos_3',
      categoria: CategoriaConquista.nutricao,
      nome: 'Fotografia da evolução',
      descricao: 'Completar três registros fotográficos.',
      meta: 3,
      icone: Icons.photo_library_rounded,
      valorDe: (n) => n.fotosDiario,
    ),
    for (final m in [1, 7, 30])
      Conquista(
        codigo: 'agua_$m',
        categoria: CategoriaConquista.nutricao,
        nome: switch (m) {
          1 => 'Hidratação em dia',
          7 => 'Semana hidratada',
          _ => 'Mês hidratado',
        },
        descricao: m == 1
            ? 'Bater a meta de água em um dia.'
            : 'Bater a meta de água em $m dias.',
        meta: m,
        icone: Icons.water_drop_rounded,
        valorDe: (n) => n.diasAguaMeta,
      ),
    for (final m in [3, 6])
      Conquista(
        codigo: 'meses_$m',
        categoria: CategoriaConquista.nutricao,
        // "Compromisso renovado" saiu daqui e foi para `checkin_6`: a
        // especificação dá esse nome a quem renova o compromisso MÊS A
        // MÊS, e tempo de plano passa sozinho, sem o aluno fazer nada.
        nome: m == 3 ? 'Evolução constante' : 'Meio ano de jornada',
        descricao: 'Completar $m meses de acompanhamento nutricional.',
        meta: m,
        icone: Icons.timeline_rounded,
        valorDe: (n) => n.mesesAcompanhamento,
      ),

    // ── Check-in mensal ───────────────────────────────────────
    // As três que o 0028 deixou de fora por não haver o recurso. A
    // 0030 criou o registro; aqui elas entram.
    Conquista(
      codigo: 'checkin_1',
      categoria: CategoriaConquista.nutricao,
      nome: 'Acompanhamento em dia',
      descricao: 'Responder o check-in nutricional do mês.',
      meta: 1,
      icone: Icons.assignment_turned_in_outlined,
      valorDe: (n) => n.checkins,
    ),
    Conquista(
      codigo: 'checkin_3',
      categoria: CategoriaConquista.nutricao,
      nome: 'Mestre da organização',
      descricao: 'Responder o check-in em três meses seguidos.',
      meta: 3,
      icone: Icons.event_available_rounded,
      // Sequência, não total: organização é não faltar, e somar três
      // check-ins em dois anos não é isso.
      valorDe: (n) => n.checkinsSeguidos,
    ),
    Conquista(
      codigo: 'checkin_6',
      categoria: CategoriaConquista.nutricao,
      nome: 'Compromisso renovado',
      descricao: 'Responder o check-in em seis meses seguidos.',
      meta: 6,
      icone: Icons.verified_rounded,
      valorDe: (n) => n.checkinsSeguidos,
    ),
  ];

  static List<Conquista> get todas => [...catalogoTreino, ...catalogoNutricao];

  static List<Conquista> de(CategoriaConquista c) =>
      todas.where((x) => x.categoria == c).toList();

  static Conquista? porCodigo(String codigo) {
    for (final c in todas) {
      if (c.codigo == codigo) return c;
    }
    return null;
  }
}

/// Uma conquista que o aluno já tem, com a data.
class ConquistaDoAluno {
  const ConquistaDoAluno({
    required this.codigo,
    required this.desbloqueadoEm,
    this.valor,
  });

  final String codigo;
  final DateTime desbloqueadoEm;

  /// O número que a disparou. Guardado porque o marco do catálogo pode
  /// mudar, e o que o aluno conquistou não muda.
  final int? valor;

  Conquista? get conquista => Conquista.porCodigo(codigo);

  factory ConquistaDoAluno.doMapa(Map<String, dynamic> m) => ConquistaDoAluno(
        codigo: m['codigo'] as String,
        desbloqueadoEm:
            DateTime.tryParse(m['desbloqueado_em'] as String? ?? '') ??
                DateTime.now(),
        valor: (m['valor'] as num?)?.toInt(),
      );
}
