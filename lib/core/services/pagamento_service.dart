import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pagamento_conta.dart';

/// O cadastro do personal no gateway.
///
/// Só escreve o que o próprio personal preenche. Criar a subconta no
/// Asaas, enviar documentos e aprovar são operações de servidor — a chave
/// de API não pode passar pelo app, e a policy do 0003 impede que esta
/// camada ligue `pode_receber` ou `pode_sacar` mesmo que tentasse.
class PagamentoService {
  static final _db = Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  /// O cadastro de quem está logado, ou `null` se ainda não começou.
  static Future<PagamentoConta?> minhaConta() async {
    final linha = await _db
        .from('pagamento_contas')
        .select()
        .eq('personal_id', _uid)
        .maybeSingle();
    return linha == null ? null : PagamentoConta.doMapa(linha);
  }

  // ── Gateway (Edge Functions asaas-*) ───────────────────────

  /// Chama uma Edge Function e devolve o corpo. O erro que ela manda em
  /// `{ erro }` já é a frase para a tela.
  static Future<Map<String, dynamic>> _funcao(String nome, Map<String, dynamic> corpo) async {
    try {
      final r = await _db.functions.invoke(nome, body: corpo);
      return Map<String, dynamic>.from(r.data as Map);
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map && d['erro'] is String ? d['erro'] as String : 'O servidor recusou (${e.status}).';
      throw Exception(msg);
    }
  }

  /// Cria a subconta no gateway com os dados já salvos.
  static Future<SituacaoGateway> enviarParaAnalise() async =>
      SituacaoGateway.doMapa(await _funcao('asaas-subconta', {'acao': 'criar'}));

  /// Situação no gateway e documentos pendentes. Também atualiza o banco.
  static Future<SituacaoGateway> situacao() async =>
      SituacaoGateway.doMapa(await _funcao('asaas-subconta', {'acao': 'status'}));

  /// Gera a cobrança no gateway e devolve o link da fatura. Sem CPF do
  /// aluno devolve `precisaCpf`, e a tela pergunta.
  static Future<({String? link, bool precisaCpf})> linkDeCobranca(String cobrancaId, {String? cpf}) async {
    final r = await _funcao('asaas-cobranca', {
      'acao': 'gerar',
      'cobranca_id': cobrancaId,
      if (cpf != null) 'cpf': cpf,
    });
    return (link: r['link'] as String?, precisaCpf: r['precisa_cpf'] == true);
  }

  static Future<void> cancelarCobranca(String cobrancaId) =>
      _funcao('asaas-cobranca', {'acao': 'cancelar', 'cobranca_id': cobrancaId});

  /// Saldo disponível para saque, lido do gateway.
  static Future<int> saldoCentavos() async =>
      ((await _funcao('asaas-saque', {'acao': 'saldo'}))['saldo_centavos'] as num).toInt();

  static Future<void> sacar({
    required int valorCentavos,
    required String chavePix,
    required String tipoChave,
    required String idempotencia,
  }) =>
      _funcao('asaas-saque', {
        'acao': 'sacar',
        'valor_centavos': valorCentavos,
        'pix_chave': chavePix,
        'pix_tipo': tipoChave,
        'idempotency_key': idempotencia,
      });

  /// Os saques do personal, do mais recente ao mais antigo.
  static Future<List<Map<String, dynamic>>> saques() async {
    final linhas = await _db
        .from('saques')
        .select()
        .eq('personal_id', _uid)
        .order('solicitado_em', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(linhas);
  }

  /// Quantos dos 4 passos estão completos, segundo o banco.
  ///
  /// A tela também sabe calcular isso, para a barra reagir enquanto a
  /// pessoa digita. Esta é a versão que vale: se as duas discordarem, é
  /// porque algo foi gravado fora do app.
  static Future<int> progresso() async {
    final r = await _db.rpc(
      'progresso_cadastro_pagamento',
      params: {'p_personal_id': _uid},
    );
    return (r as num?)?.toInt() ?? 0;
  }

  /// Grava os dados que o personal preencheu, criando a linha na primeira
  /// vez. Devolve o cadastro já relido do banco.
  ///
  /// Não envia `kyc_status`, `pode_receber` nem `pode_sacar`: a policy
  /// recusaria, e mandar campo que vai ser recusado só produz erro
  /// confuso na tela.
  static Future<PagamentoConta> salvar(Map<String, dynamic> dados) async {
    final limpo = Map<String, dynamic>.from(dados)
      ..removeWhere((k, v) =>
          const {
            'kyc_status',
            'pode_receber',
            'pode_sacar',
            'gateway_account_id',
            'api_key_ref',
            'aprovado_em',
            'documentos_enviados_em',
          }.contains(k) ||
          (v is String && v.trim().isEmpty));

    final existente = await minhaConta();

    if (existente == null) {
      final linha = await _db
          .from('pagamento_contas')
          .insert({...limpo, 'personal_id': _uid})
          .select()
          .single();
      return PagamentoConta.doMapa(linha);
    }

    // `select()` depois do update: sem ele, um update barrado pela policy
    // volta sem erro e sem alterar nada, e a tela diria "salvo" tendo
    // perdido o que a pessoa digitou.
    final linhas = await _db
        .from('pagamento_contas')
        .update({...limpo, 'atualizado_em': DateTime.now().toIso8601String()})
        .eq('personal_id', _uid)
        .select();

    if (linhas.isEmpty) {
      throw Exception(
        'O cadastro não pôde ser alterado. Depois de aprovado pelo gateway, '
        'mudanças de dados passam por eles.',
      );
    }
    return PagamentoConta.doMapa(linhas.first);
  }
}
