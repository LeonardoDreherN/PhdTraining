import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/resumo_home.dart';

/// Monta o resumo da home do personal.
///
/// São quatro consultas em paralelo em vez de uma view no banco: assim o
/// que cada número significa fica visível aqui no Dart, onde a regra muda
/// com frequência. Se virar gargalo, isso migra para uma função SQL — mas
/// otimizar antes de existir volume é escrever complexidade à toa.
class HomeService {
  static final _db = Supabase.instance.client;

  /// Quantos dias sem treinar até o aluno virar pendência.
  static const _diasSemTreinarLimite = 10;

  static Future<ResumoHome> carregar() async {
    final personalId = _db.auth.currentUser?.id;
    if (personalId == null) return ResumoHome.vazio;

    final agora = DateTime.now();
    final inicioMes = DateTime(agora.year, agora.month);
    final hoje = DateTime(agora.year, agora.month, agora.day);
    final corte = hoje.subtract(const Duration(days: _diasSemTreinarLimite));

    final resultados = await Future.wait([
      _db.from('alunos').select('id, nome, foto_url, ativo').eq('personal_id', personalId),
      _db.from('fichas').select('id').eq('personal_id', personalId).limit(1),
      _db
          .from('cobrancas')
          .select('status, valor_centavos, vencimento, pago_em, aluno_id')
          .eq('personal_id', personalId)
          .gte('vencimento', _data(DateTime(agora.year, agora.month - 3))),
      _db
          .from('treino_execucoes')
          .select('aluno_id')
          .eq('personal_id', personalId)
          .gte('executado_em', corte.toIso8601String()),
    ]);

    final alunos = List<Map<String, dynamic>>.from(resultados[0]);
    final temFicha = (resultados[1] as List).isNotEmpty;
    final cobrancas = List<Map<String, dynamic>>.from(resultados[2]);
    final execucoes = List<Map<String, dynamic>>.from(resultados[3]);

    final ativos = alunos.where((a) => a['ativo'] == true).toList();
    final porId = {for (final a in alunos) a['id'] as String: a};

    var recebido = 0;
    var aReceber = 0;
    var atrasado = 0;
    var qtdAtrasadas = 0;
    final pendencias = <Pendencia>[];

    for (final c in cobrancas) {
      final valor = (c['valor_centavos'] as num?)?.toInt() ?? 0;
      final status = c['status'] as String?;
      final venc = DateTime.tryParse(c['vencimento'] as String? ?? '');
      final pagoEm = DateTime.tryParse(c['pago_em'] as String? ?? '');

      if (status == 'pago') {
        // Só conta no mês em que o dinheiro entrou, não no do vencimento —
        // é o que o personal vê no extrato do banco.
        if (pagoEm != null && !pagoEm.isBefore(inicioMes)) recebido += valor;
        continue;
      }

      if (status != 'pendente' && status != 'atrasado') continue;

      final venceu = venc != null && venc.isBefore(hoje);
      if (venceu || status == 'atrasado') {
        atrasado += valor;
        qtdAtrasadas++;

        final aluno = porId[c['aluno_id']];
        if (aluno != null && venc != null) {
          final dias = hoje.difference(venc).inDays;
          pendencias.add(Pendencia(
            alunoId: aluno['id'] as String,
            alunoNome: aluno['nome'] as String? ?? 'Aluno',
            avatarUrl: aluno['foto_url'] as String?,
            tipo: TipoPendencia.mensalidadeAtrasada,
            detalhe: dias <= 0
                ? 'Vence hoje'
                : 'Vencida há $dias ${dias == 1 ? 'dia' : 'dias'}',
            valorCentavos: valor,
          ));
        }
      } else if (venc != null && !venc.isBefore(inicioMes)) {
        aReceber += valor;
      }
    }

    // Quem treinou recentemente sai da lista de sumidos.
    final treinaram = execucoes.map((e) => e['aluno_id'] as String?).whereType<String>().toSet();
    final jaListados = pendencias.map((p) => p.alunoId).toSet();

    for (final a in ativos) {
      final id = a['id'] as String;
      if (treinaram.contains(id) || jaListados.contains(id)) continue;
      pendencias.add(Pendencia(
        alunoId: id,
        alunoNome: a['nome'] as String? ?? 'Aluno',
        avatarUrl: a['foto_url'] as String?,
        tipo: TipoPendencia.semTreinar,
        detalhe: 'Sem treinar há mais de $_diasSemTreinarLimite dias',
      ));
    }

    // Dinheiro primeiro: é a pendência que some se ninguém agir.
    pendencias.sort((a, b) => a.tipo.index.compareTo(b.tipo.index));

    return ResumoHome(
      alunosAtivos: ativos.length,
      alunosInativos: alunos.length - ativos.length,
      temFicha: temFicha,
      recebidoCentavos: recebido,
      aReceberCentavos: aReceber,
      atrasadoCentavos: atrasado,
      cobrancasAtrasadas: qtdAtrasadas,
      pendencias: pendencias.take(4).toList(),
    );
  }

  static String _data(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
