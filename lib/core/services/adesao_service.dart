import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/adesao.dart';
import '../utils/datas.dart';

/// Monta o painel de adesão do profissional: todos os alunos com plano
/// ativo, classificados pelo que registraram na última semana.
///
/// Seis consultas para o painel inteiro, nenhuma por aluno: com 40 alunos,
/// uma por aluno seriam 240 idas ao servidor.
class AdesaoService {
  static final _db = Supabase.instance.client;

  /// Janela do painel.
  static const dias = 7;

  static Future<({List<AdesaoAluno> alunos, int semPlano})> painel() async {
    final personalId = _db.auth.currentUser!.id;
    final agora = DateTime.now();
    final hoje = Datas.dia(agora);
    final de = hoje.subtract(const Duration(days: dias - 1));

    final alunos = List<Map<String, dynamic>>.from(
      await _db.from('alunos').select().eq('personal_id', personalId).eq('ativo', true),
    );
    if (alunos.isEmpty) return (alunos: <AdesaoAluno>[], semPlano: 0);
    final ids = [for (final a in alunos) a['id'] as String];

    final planos = List<Map<String, dynamic>>.from(
      await _db
          .from('planos_alimentares')
          .select('id, aluno_id, data_inicio, agua_ml')
          .eq('ativo', true)
          .inFilter('aluno_id', ids),
    );
    if (planos.isEmpty) return (alunos: <AdesaoAluno>[], semPlano: alunos.length);

    final comPlano = {for (final p in planos) p['aluno_id'] as String: p};
    final idsComPlano = comPlano.keys.toList();

    final (refeicoes, marcadas, diario, agua) = await (
      _db
          .from('plano_refeicoes')
          .select('plano_id')
          .inFilter('plano_id', [for (final p in planos) p['id'] as String]),
      _db
          .from('refeicoes_registro')
          .select('aluno_id, feita, criado_em')
          .inFilter('aluno_id', idsComPlano)
          .gte('data', Datas.iso(de)),
      _talvez(_db
          .from('diario_registros')
          .select('aluno_id, aderencia, registrado_em')
          .inFilter('aluno_id', idsComPlano)
          .gte('data', Datas.iso(de))),
      _talvez(_db
          .from('agua_registros')
          .select('aluno_id, ml, data, registrado_em')
          .inFilter('aluno_id', idsComPlano)
          .gte('data', Datas.iso(de))),
    ).wait;

    // Refeições por plano. Conta a refeição mesmo vazia: é raro, e
    // descontar exigiria trazer os itens de todos os planos.
    final porPlano = <String, int>{};
    for (final r in List<Map<String, dynamic>>.from(refeicoes)) {
      final id = r['plano_id'] as String;
      porPlano[id] = (porPlano[id] ?? 0) + 1;
    }

    final feitas = <String, int>{};
    final fugas = <String, int>{};
    final ultimo = <String, DateTime>{};
    final aguaTotal = <String, int>{};
    final diasAgua = <String, Set<String>>{};

    void visto(String aluno, Object? quando) {
      final d = DateTime.tryParse(quando as String? ?? '')?.toLocal();
      if (d == null) return;
      final atual = ultimo[aluno];
      if (atual == null || d.isAfter(atual)) ultimo[aluno] = d;
    }

    for (final m in List<Map<String, dynamic>>.from(marcadas)) {
      final a = m['aluno_id'] as String;
      if (m['feita'] as bool? ?? false) feitas[a] = (feitas[a] ?? 0) + 1;
      visto(a, m['criado_em']);
    }
    for (final d in diario ?? const <Map<String, dynamic>>[]) {
      final a = d['aluno_id'] as String;
      if (d['aderencia'] == 'fora') fugas[a] = (fugas[a] ?? 0) + 1;
      visto(a, d['registrado_em']);
    }
    for (final g in agua ?? const <Map<String, dynamic>>[]) {
      final a = g['aluno_id'] as String;
      aguaTotal[a] = (aguaTotal[a] ?? 0) + (g['ml'] as num).toInt();
      diasAgua.putIfAbsent(a, () => {}).add(g['data'] as String);
      visto(a, g['registrado_em']);
    }

    final lista = <AdesaoAluno>[
      for (final a in alunos)
        if (comPlano[a['id']] case final plano?)
          calcularAdesao(
            aluno: a,
            refeicoesPorDia: porPlano[plano['id']] ?? 0,
            // Plano que começou no meio da semana só cobra os dias dele.
            dias: _diasDoPlano(plano['data_inicio'] as String?, de, hoje),
            feitas: feitas[a['id']] ?? 0,
            fugas: fugas[a['id']] ?? 0,
            agora: agora,
            ultimoRegistro: ultimo[a['id']],
            aguaTotalMl: aguaTotal[a['id']],
            diasComAgua: diasAgua[a['id']]?.length ?? 0,
            metaAguaMl: (plano['agua_ml'] as num?)?.round(),
          ),
    ]..sort((x, y) {
        final s = x.situacao.index.compareTo(y.situacao.index);
        if (s != 0) return s;
        return (x.percentual ?? 1).compareTo(y.percentual ?? 1);
      });

    return (alunos: lista, semPlano: alunos.length - comPlano.length);
  }

  static int _diasDoPlano(String? inicio, DateTime de, DateTime hoje) {
    final i = DateTime.tryParse(inicio ?? '');
    if (i == null || !Datas.dia(i).isAfter(de)) return dias;
    return hoje.difference(Datas.dia(i)).inDays + 1;
  }

  /// Diário e água vêm do 0014; sem ele, o painel funciona só com as
  /// refeições marcadas.
  static Future<List<Map<String, dynamic>>?> _talvez(Future<List<Map<String, dynamic>>> f) async {
    try {
      return await f;
    } on PostgrestException {
      return null;
    }
  }
}
