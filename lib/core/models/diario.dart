import '../utils/datas.dart';

/// "Como foi?" — a resposta do aluno ao registrar uma refeição.
enum Aderencia {
  seguiu('Segui o plano'),
  parecido('Comi parecido'),
  fora('Fugi do plano');

  const Aderencia(this.rotulo);
  final String rotulo;

  static Aderencia? de(String? v) =>
      Aderencia.values.where((a) => a.name == v).firstOrNull;
}

/// Uma entrada do diário alimentar: o que o aluno comeu de fato.
class RegistroDiario {
  const RegistroDiario({
    required this.id,
    required this.alunoId,
    required this.data,
    required this.titulo,
    required this.registradoEm,
    this.refeicaoId,
    this.descricao,
    this.fotoPath,
    this.fotoUrl,
    this.aderencia,
  });

  final String id;
  final String alunoId;
  final DateTime data;

  /// Nulo = algo fora do plano (o lanche que não estava previsto).
  final String? refeicaoId;
  final String titulo;
  final String? descricao;

  /// Caminho no bucket. [fotoUrl] é a URL assinada, que vence — por isso
  /// a linha guarda o caminho e a URL só existe em memória.
  final String? fotoPath;
  final String? fotoUrl;
  final Aderencia? aderencia;
  final DateTime registradoEm;

  bool get foraDoPlano => refeicaoId == null;

  RegistroDiario comUrl(String? url) => RegistroDiario(
        id: id,
        alunoId: alunoId,
        data: data,
        titulo: titulo,
        registradoEm: registradoEm,
        refeicaoId: refeicaoId,
        descricao: descricao,
        fotoPath: fotoPath,
        fotoUrl: url,
        aderencia: aderencia,
      );

  factory RegistroDiario.doMapa(Map<String, dynamic> m) => RegistroDiario(
        id: m['id'] as String,
        alunoId: m['aluno_id'] as String,
        data: Datas.ler(m['data']) ?? DateTime.now(),
        refeicaoId: m['refeicao_id'] as String?,
        titulo: m['titulo'] as String? ?? 'Refeição',
        descricao: m['descricao'] as String?,
        fotoPath: m['foto_path'] as String?,
        aderencia: Aderencia.de(m['aderencia'] as String?),
        registradoEm:
            DateTime.tryParse(m['registrado_em'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}

/// Um peso anotado — pelo aluno em casa ou pelo profissional na consulta.
class RegistroPeso {
  const RegistroPeso({required this.id, required this.data, required this.pesoKg});

  final String id;
  final DateTime data;
  final double pesoKg;

  factory RegistroPeso.doMapa(Map<String, dynamic> m) => RegistroPeso(
        id: m['id'] as String,
        data: Datas.ler(m['data']) ?? DateTime.now(),
        pesoKg: (m['peso_kg'] as num).toDouble(),
      );
}
