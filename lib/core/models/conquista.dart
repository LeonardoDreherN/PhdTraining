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
    this.pesagens = 0,
    this.fotosDiario = 0,
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
  final int diasPlanoCompleto;
  final int pesagens;
  final int fotosDiario;

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
        pesagens: _i(m['pesagens']),
        fotosDiario: _i(m['fotos_diario']),
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

  static List<Conquista> de(CategoriaConquista c) =>
      [...catalogoTreino].where((x) => x.categoria == c).toList();

  static Conquista? porCodigo(String codigo) {
    for (final c in catalogoTreino) {
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
