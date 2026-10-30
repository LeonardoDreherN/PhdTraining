import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/financeiro.dart';

/// O financeiro do personal.
///
/// Esta versão é controle manual: o personal recebe por fora (Pix,
/// dinheiro, maquininha) e marca aqui. Por isso toda cobrança criada daqui
/// nasce com `origem = 'manual'` — ela conta no relatório e na
/// inadimplência, mas nunca na carteira do gateway. Quando o Asaas entrar,
/// as cobranças dele nascem com `origem = 'gateway'` e as duas convivem.
class FinanceiroService {
  static final _db = Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Planos ──────────────────────────────────────────────────

  static Future<List<PlanoVenda>> planos({bool somenteAtivos = true}) async {
    var q = _db.from('personal_planos').select().eq('personal_id', _uid);
    if (somenteAtivos) q = q.eq('ativo', true);
    final linhas = await q.order('preco_centavos', ascending: true);
    return List<Map<String, dynamic>>.from(linhas)
        .map(PlanoVenda.doMapa)
        .toList();
  }

  static Future<void> salvarPlano(Map<String, dynamic> dados, {String? id}) async {
    if (id == null) {
      await _db.from('personal_planos').insert({...dados, 'personal_id': _uid});
    } else {
      await _db.from('personal_planos').update(dados).eq('id', id);
    }
  }

  // ── Assinaturas ─────────────────────────────────────────────

  static Future<List<Assinatura>> assinaturas() async {
    final linhas = await _db
        .from('aluno_assinaturas')
        .select('*, alunos(nome, foto_url, whatsapp), '
            'personal_planos(nome, preco_centavos)')
        .eq('personal_id', _uid)
        .order('criado_em', ascending: false);
    return List<Map<String, dynamic>>.from(linhas)
        .map(Assinatura.doMapa)
        .toList();
  }

  /// Assina um aluno num plano e já gera as cobranças do período.
  ///
  /// Gerar as cobranças aqui, e não depois, é o que faz a tela de
  /// inadimplência existir desde o primeiro dia: sem linha de cobrança não
  /// há o que atrasar, e o personal acabaria controlando no caderno.
  ///
  /// Devolve o id da assinatura.
  static Future<String> assinar({
    required String alunoId,
    required PlanoVenda plano,
    required DateTime primeiroVencimento,
    required int quantasCobrancas,
    int? valorCentavos,
  }) async {
    // Uma assinatura viva por aluno: encerra a anterior antes, senão o
    // aluno apareceria em dois planos e o recorrente contaria em dobro.
    await _db
        .from('aluno_assinaturas')
        .update({'status': 'encerrada', 'fim': _data(DateTime.now())})
        .eq('aluno_id', alunoId)
        .inFilter('status', ['ativa', 'inadimplente']);

    final assinatura = await _db
        .from('aluno_assinaturas')
        .insert({
          'personal_id': _uid,
          'aluno_id': alunoId,
          'plano_id': plano.id,
          'status': 'ativa',
          'dia_vencimento': primeiroVencimento.day,
          'inicio': _data(primeiroVencimento),
        })
        .select('id')
        .single();

    final assinaturaId = assinatura['id'] as String;
    final valor = valorCentavos ?? plano.precoCentavos;

    await _db.from('cobrancas').insert([
      for (var i = 0; i < quantasCobrancas; i++)
        {
          'personal_id': _uid,
          'aluno_id': alunoId,
          'assinatura_id': assinaturaId,
          'plano_id': plano.id,
          'descricao': plano.nome,
          'valor_centavos': valor,
          'parcelas': quantasCobrancas,
          'parcela_numero': i + 1,
          'status': 'pendente',
          'origem': 'manual',
          'vencimento': _data(_somaMeses(primeiroVencimento, i * plano.meses)),
        },
    ]);

    return assinaturaId;
  }

  static Future<void> mudarStatusAssinatura(String id, String status) async {
    await _db.from('aluno_assinaturas').update({
      'status': status,
      if (status == 'cancelada' || status == 'encerrada')
        'fim': _data(DateTime.now()),
    }).eq('id', id);
  }

  // ── Cobranças ───────────────────────────────────────────────

  static Future<List<Cobranca>> cobrancas({int meses = 6}) async {
    final de = _somaMeses(DateTime.now(), -meses);
    final linhas = await _db
        .from('cobrancas')
        .select('*, alunos(nome, whatsapp)')
        .eq('personal_id', _uid)
        .gte('vencimento', _data(de))
        .order('vencimento', ascending: false);
    return List<Map<String, dynamic>>.from(linhas)
        .map(Cobranca.doMapa)
        .toList();
  }

  /// Marca como paga. `metodo` é como o dinheiro entrou, para o relatório
  /// depois conseguir separar Pix de dinheiro.
  static Future<void> marcarPaga(String id, {String metodo = 'pix'}) async {
    await _db.from('cobrancas').update({
      'status': 'pago',
      'metodo': metodo,
      'pago_em': DateTime.now().toIso8601String(),
      'atualizado_em': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Desfaz a baixa. Existe porque marcar a linha errada é o erro mais
  /// comum numa lista de cobranças, e sem desfazer o número do mês fica
  /// errado para sempre.
  static Future<void> desmarcarPaga(String id) async {
    await _db.from('cobrancas').update({
      'status': 'pendente',
      'metodo': null,
      'pago_em': null,
      'atualizado_em': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> cancelarCobranca(String id) async {
    await _db.from('cobrancas').update({
      'status': 'cancelado',
      'atualizado_em': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  /// Cobrança solta, fora de plano: uma avaliação, um mês extra.
  static Future<void> criarCobrancaAvulsa({
    required String alunoId,
    required String descricao,
    required int valorCentavos,
    required DateTime vencimento,
  }) async {
    await _db.from('cobrancas').insert({
      'personal_id': _uid,
      'aluno_id': alunoId,
      'descricao': descricao,
      'valor_centavos': valorCentavos,
      'status': 'pendente',
      'origem': 'manual',
      'vencimento': _data(vencimento),
    });
  }

  // ── Resumo ──────────────────────────────────────────────────

  /// Os números do painel, numa consulta só sobre o que já foi carregado.
  ///
  /// Recebe as listas em vez de ir ao banco de novo: a tela já tem as duas
  /// em mãos, e uma terceira consulta só abriria espaço para o painel
  /// discordar da lista logo abaixo dele.
  static ResumoFinanceiro resumir(
    List<Cobranca> cobrancas,
    List<Assinatura> assinaturas,
  ) {
    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month);

    var recebido = 0, aReceber = 0, atrasado = 0;
    final emAtraso = <String>{};

    for (final c in cobrancas) {
      if (c.paga) {
        // Conta no mês em que o dinheiro entrou, não no do vencimento — é
        // o que o personal vê no extrato.
        final quando = c.pagoEm;
        if (quando != null && !quando.isBefore(inicioMes)) {
          recebido += c.valorCentavos;
        }
        continue;
      }
      if (c.status == 'cancelado' || c.status == 'estornado') continue;

      if (c.vencida) {
        atrasado += c.valorCentavos;
        if (c.alunoId != null) emAtraso.add(c.alunoId!);
      } else if (!c.vencimento.isBefore(inicioMes) &&
          c.vencimento.isBefore(DateTime(agora.year, agora.month + 1))) {
        aReceber += c.valorCentavos;
      }
    }

    final vivas = assinaturas.where((a) => a.viva).toList();

    return ResumoFinanceiro(
      recebidoCentavos: recebido,
      aReceberCentavos: aReceber,
      atrasadoCentavos: atrasado,
      assinaturasAtivas: vivas.length,
      alunosEmAtraso: emAtraso.length,
      recorrenteCentavos: vivas.fold(0, (s, a) => s + a.precoCentavos),
    );
  }

  // ── Auxiliares ──────────────────────────────────────────────

  /// Soma meses preservando o fim do mês.
  ///
  /// `DateTime(2026, 2, 31)` vira 3 de março sozinho, e uma mensalidade
  /// que vence dia 31 pularia fevereiro inteiro. Aqui ela cai no dia 28.
  static DateTime _somaMeses(DateTime d, int meses) {
    final ano = d.year + ((d.month - 1 + meses) ~/ 12);
    final mes = ((d.month - 1 + meses) % 12) + 1;
    final ultimoDia = DateTime(ano, mes + 1, 0).day;
    return DateTime(ano, mes, d.day > ultimoDia ? ultimoDia : d.day);
  }

  static String _data(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
