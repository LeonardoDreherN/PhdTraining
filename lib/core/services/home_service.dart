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
    final segunda = hoje.subtract(Duration(days: hoje.weekday - 1));
    // Seis meses de cobranças: é o que o gráfico de receita mostra.
    final inicioGrafico = DateTime(agora.year, agora.month - 5);

    final resultados = await Future.wait([
      // A linha inteira: ela vira o `extra` da tela de perfil do aluno.
      _db.from('alunos').select().eq('personal_id', personalId),
      _db.from('fichas').select('id').eq('personal_id', personalId).limit(1),
      _db
          .from('cobrancas')
          .select('status, valor_centavos, vencimento, pago_em, aluno_id')
          .eq('personal_id', personalId)
          // Vencimento **ou** pagamento dentro da janela. A receita é somada
          // por `pago_em`, então filtrar só por vencimento perdia a cobrança
          // que venceu antes da janela e foi paga agora — justo o atrasado
          // que acabou de entrar. Faltava no gráfico e no recebido do mês,
          // e é a diferença que apareceria contra o extrato do banco.
          .or('vencimento.gte.${_data(inicioGrafico)},'
              'pago_em.gte.${_data(inicioGrafico)}'),
      _db
          .from('treino_execucoes')
          .select('aluno_id, ficha_nome, executado_em, duracao_minutos')
          .eq('personal_id', personalId)
          .gte('executado_em', corte.toUtc().toIso8601String())
          .order('executado_em', ascending: false),
    ]);

    final alunos = List<Map<String, dynamic>>.from(resultados[0]);
    final temFicha = (resultados[1] as List).isNotEmpty;
    final cobrancas = List<Map<String, dynamic>>.from(resultados[2]);
    final execucoes = List<Map<String, dynamic>>.from(resultados[3]);

    final ativos = alunos.where((a) => a['ativo'] == true).toList();
    final porId = {for (final a in alunos) a['id'] as String: a};

    // Último treino de cada aluno, e a semana em números. `execucoes` vem
    // do mais recente para o mais antigo, então o primeiro de cada aluno é
    // o último treino dele.
    final ultimo = <String, DateTime>{};
    final porDia = List.filled(7, 0);
    final hojeIds = <String>{};
    final semanaIds = <String>{};
    for (final e in execucoes) {
      final id = e['aluno_id'] as String?;
      final quando = DateTime.tryParse(e['executado_em'] as String? ?? '')?.toLocal();
      if (id == null || quando == null) continue;
      ultimo.putIfAbsent(id, () => quando);
      if (!quando.isBefore(segunda)) porDia[quando.weekday - 1]++;
      if (!quando.isBefore(hoje)) hojeIds.add(id);
      if (!quando.isBefore(hoje.subtract(const Duration(days: 6)))) semanaIds.add(id);
    }

    AlunoResumo resumo(Map<String, dynamic> a) =>
        AlunoResumo(linha: a, ultimoTreino: ultimo[a['id']]);

    final recentes = <TreinoRecente>[
      for (final e in execucoes.take(5))
        if (porId[e['aluno_id']] case final a?)
          TreinoRecente(
            aluno: resumo(a),
            fichaNome: e['ficha_nome'] as String? ?? 'Treino',
            quando: DateTime.parse(e['executado_em'] as String).toLocal(),
            minutos: (e['duracao_minutos'] as num?)?.toInt(),
          ),
    ];

    final listaAtivos = ativos.map(resumo).toList()
      ..sort((a, b) {
        final x = a.ultimoTreino, y = b.ultimoTreino;
        if (x == null && y == null) return a.nome.compareTo(b.nome);
        if (x == null) return 1;
        if (y == null) return -1;
        return y.compareTo(x);
      });

    final aniversarios = <({AlunoResumo aluno, DateTime dia})>[];
    for (final a in ativos) {
      final nasc = DateTime.tryParse(a['data_nascimento'] as String? ?? '');
      if (nasc == null) continue;
      var dia = DateTime(hoje.year, nasc.month, nasc.day);
      if (dia.isBefore(hoje)) dia = DateTime(hoje.year + 1, nasc.month, nasc.day);
      if (dia.difference(hoje).inDays < 7) aniversarios.add((aluno: resumo(a), dia: dia));
    }
    aniversarios.sort((a, b) => a.dia.compareTo(b.dia));

    final novosNoMes = alunos.where((a) {
      final c = DateTime.tryParse(a['criado_em'] as String? ?? '')?.toLocal();
      return c != null && !c.isBefore(inicioMes);
    }).length;

    final receitaMeses = List.filled(6, 0);
    var recebido = 0;
    var aReceber = 0;
    var qtdAReceber = 0;
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
        if (pagoEm != null) {
          final i = 5 - ((agora.year - pagoEm.year) * 12 + agora.month - pagoEm.month);
          if (i >= 0 && i < 6) receitaMeses[i] += valor;
        }
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
            whatsapp: aluno['whatsapp'] as String?,
          ));
        }
      } else if (venc != null && !venc.isBefore(inicioMes)) {
        aReceber += valor;
        qtdAReceber++;
      }
    }

    // Quem treinou recentemente sai da lista de sumidos — e quem entrou há
    // menos de 10 dias ainda não teve tempo de sumir.
    final jaListados = pendencias.map((p) => p.alunoId).toSet();

    for (final a in ativos) {
      final id = a['id'] as String;
      if (ultimo.containsKey(id) || jaListados.contains(id)) continue;
      final criado = DateTime.tryParse(a['criado_em'] as String? ?? '')?.toLocal();
      if (criado != null && criado.isAfter(corte)) continue;
      pendencias.add(Pendencia(
        alunoId: id,
        alunoNome: a['nome'] as String? ?? 'Aluno',
        avatarUrl: a['foto_url'] as String?,
        tipo: TipoPendencia.semTreinar,
        detalhe: 'Sem treinar há mais de $_diasSemTreinarLimite dias',
        whatsapp: a['whatsapp'] as String?,
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
      cobrancasAReceber: qtdAReceber,
      pendencias: pendencias.take(4).toList(),
      receitaMeses: receitaMeses,
      treinosPorDia: porDia,
      adesaoSemana: ativos.isEmpty
          ? 0
          : ativos.where((a) => semanaIds.contains(a['id'])).length / ativos.length,
      novosNoMes: novosNoMes,
      treinaramHoje: [
        for (final id in hojeIds)
          if (porId[id] case final a?) resumo(a),
      ],
      recentes: recentes,
      alunos: listaAtivos,
      aniversarios: aniversarios,
    );
  }

  static String _data(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
