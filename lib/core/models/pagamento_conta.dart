/// O cadastro do personal no gateway de pagamento.
///
/// Os dados pessoais ficam nesta tabela, e não em `profiles`, porque
/// `profiles` é legível pelos alunos dele — é de lá que sai a marca. CPF,
/// renda e endereço residencial não têm por que viajar junto.
class PagamentoConta {
  const PagamentoConta({
    this.id,
    this.gateway = 'asaas',
    this.modo = 'subconta',
    this.gatewayAccountId,
    this.cpfCnpj,
    this.razaoSocial,
    this.nomeResponsavel,
    this.dataNascimento,
    this.tipoEmpresa,
    this.rendaMensalCentavos,
    this.emailCobranca,
    this.telefoneCelular,
    this.cep,
    this.logradouro,
    this.numero,
    this.complemento,
    this.bairro,
    this.cidade,
    this.uf,
    this.kycStatus = 'pendente',
    this.kycPendencias = const [],
    this.documentosEnviadosEm,
    this.aprovadoEm,
    this.recusadoMotivo,
    this.podeReceber = false,
    this.podeSacar = false,
  });

  final String? id;
  final String gateway;
  final String modo;
  final String? gatewayAccountId;

  final String? cpfCnpj;
  final String? razaoSocial;
  final String? nomeResponsavel;
  final DateTime? dataNascimento;

  /// MEI, LIMITED, INDIVIDUAL, ASSOCIATION.
  final String? tipoEmpresa;
  final int? rendaMensalCentavos;
  final String? emailCobranca;
  final String? telefoneCelular;

  final String? cep;
  final String? logradouro;
  final String? numero;
  final String? complemento;
  final String? bairro;
  final String? cidade;
  final String? uf;

  /// pendente, em_analise, aprovado, recusado.
  final String kycStatus;
  final List<String> kycPendencias;
  final DateTime? documentosEnviadosEm;
  final DateTime? aprovadoEm;
  final String? recusadoMotivo;

  /// Quem decide os dois é o gateway, nunca o app: a policy do 0003
  /// impede o próprio personal de ligá-los.
  final bool podeReceber;
  final bool podeSacar;

  bool get existe => id != null;
  bool get aprovado => kycStatus == 'aprovado';
  bool get emAnalise => kycStatus == 'em_analise';
  bool get recusado => kycStatus == 'recusado';

  /// `true` enquanto o cadastro ainda pode ser editado. Depois de aprovado,
  /// mudar CPF ou endereço exige passar pelo gateway de novo — a policy
  /// do banco já recusa o update.
  bool get editavel => kycStatus == 'pendente' || kycStatus == 'recusado';

  bool get temDados =>
      _cheio(cpfCnpj) &&
      _cheio(nomeResponsavel) &&
      _cheio(tipoEmpresa) &&
      rendaMensalCentavos != null;

  bool get temEndereco =>
      _cheio(cep) &&
      _cheio(logradouro) &&
      _cheio(numero) &&
      _cheio(cidade) &&
      _cheio(uf);

  bool get temDocumentos => documentosEnviadosEm != null;

  /// A subconta já existe no gateway. "criando:..." é a trava da Edge
  /// Function enquanto a criação está em andamento — ainda não conta.
  bool get temContaNoGateway =>
      gatewayAccountId != null && !gatewayAccountId!.startsWith('criando:');

  /// Mesma contagem da função `progresso_cadastro_pagamento` do 0003.
  ///
  /// Calculada aqui também para a barra reagir enquanto a pessoa digita,
  /// sem ida ao servidor. O banco continua sendo a verdade — é dele que
  /// vem o valor ao abrir a tela.
  int get passosFeitos =>
      (temDados ? 1 : 0) +
      (temEndereco ? 1 : 0) +
      (temDocumentos ? 1 : 0) +
      (aprovado ? 1 : 0);

  static const totalPassos = 4;

  String get situacao => switch (kycStatus) {
        'aprovado' => 'Aprovado',
        'em_analise' => 'Em análise',
        'recusado' => 'Recusado',
        _ => 'Cadastro incompleto',
      };

  static bool _cheio(String? v) => v != null && v.trim().isNotEmpty;

  factory PagamentoConta.doMapa(Map<String, dynamic> m) => PagamentoConta(
        id: m['id'] as String?,
        gateway: m['gateway'] as String? ?? 'asaas',
        modo: m['modo'] as String? ?? 'subconta',
        gatewayAccountId: m['gateway_account_id'] as String?,
        cpfCnpj: m['cpf_cnpj'] as String?,
        razaoSocial: m['razao_social'] as String?,
        nomeResponsavel: m['nome_responsavel'] as String?,
        dataNascimento: DateTime.tryParse(m['data_nascimento'] as String? ?? ''),
        tipoEmpresa: m['tipo_empresa'] as String?,
        rendaMensalCentavos: (m['renda_mensal_centavos'] as num?)?.toInt(),
        emailCobranca: m['email_cobranca'] as String?,
        telefoneCelular: m['telefone_celular'] as String?,
        cep: m['cep'] as String?,
        logradouro: m['logradouro'] as String?,
        numero: m['numero'] as String?,
        complemento: m['complemento'] as String?,
        bairro: m['bairro'] as String?,
        cidade: m['cidade'] as String?,
        uf: m['uf'] as String?,
        kycStatus: m['kyc_status'] as String? ?? 'pendente',
        kycPendencias: [
          for (final p in (m['kyc_pendencias'] as List? ?? const []))
            p.toString(),
        ],
        documentosEnviadosEm:
            DateTime.tryParse(m['documentos_enviados_em'] as String? ?? ''),
        aprovadoEm: DateTime.tryParse(m['aprovado_em'] as String? ?? ''),
        recusadoMotivo: m['recusado_motivo'] as String?,
        podeReceber: m['pode_receber'] as bool? ?? false,
        podeSacar: m['pode_sacar'] as bool? ?? false,
      );
}

/// O que o gateway diz da conta agora (função `asaas-subconta`).
class SituacaoGateway {
  const SituacaoGateway({
    required this.kycStatus,
    this.podeReceber = false,
    this.podeSacar = false,
    this.documentos = const [],
    this.aguardando = false,
  });

  final String kycStatus;
  final bool podeReceber;
  final bool podeSacar;

  /// Documentos que o gateway pede. `link` é a página do próprio gateway
  /// para enviar; quando vem, o envio é por lá e não pelo app.
  final List<({String titulo, String? descricao, String status, String? link})> documentos;

  /// A conta acabou de ser criada: o gateway leva alguns segundos para
  /// dizer o que falta.
  final bool aguardando;

  factory SituacaoGateway.doMapa(Map<String, dynamic> m) => SituacaoGateway(
        kycStatus: m['kyc_status'] as String? ?? 'pendente',
        podeReceber: m['pode_receber'] as bool? ?? false,
        podeSacar: m['pode_sacar'] as bool? ?? false,
        aguardando: m['aguardando'] as bool? ?? false,
        documentos: [
          for (final d in (m['documentos'] as List? ?? const []))
            if (d is Map)
              (
                titulo: d['titulo']?.toString() ?? 'Documento',
                descricao: d['descricao'] as String?,
                status: d['status']?.toString() ?? '',
                link: d['link'] as String?,
              ),
        ],
      );
}

/// Tipos de empresa que o gateway aceita, com o rótulo que a pessoa
/// entende. "LIMITED" sozinho numa lista não diz nada a um personal.
const tiposDeEmpresa = <({String valor, String rotulo, String ajuda})>[
  (valor: 'INDIVIDUAL', rotulo: 'Pessoa física', ajuda: 'Recebo no meu CPF'),
  (valor: 'MEI', rotulo: 'MEI', ajuda: 'Microempreendedor individual'),
  (valor: 'LIMITED', rotulo: 'Empresa', ajuda: 'Ltda, EIRELI ou similar'),
  (valor: 'ASSOCIATION', rotulo: 'Associação', ajuda: 'Entidade sem fins lucrativos'),
];
