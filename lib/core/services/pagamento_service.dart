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
