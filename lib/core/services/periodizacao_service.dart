import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/periodizacao.dart';
import '../utils/datas.dart';

/// Etapas da periodização e as fichas programadas nelas (migração 0024).
class PeriodizacaoService {
  static final _db = Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  /// Faz a virada de etapa deste aluno agora, sem esperar o cron da
  /// madrugada. Sem a migração 0024 no banco, não faz nada.
  static Future<void> aplicar(String alunoId) async {
    try {
      await _db.rpc('aplicar_periodizacao_do_aluno', params: {'p_aluno_id': alunoId});
    } catch (_) {
      // Periodização é camada a mais: a tela de treinos abre sem ela.
    }
  }

  /// As etapas do aluno, da mais antiga à mais nova, com as fichas.
  static Future<List<EtapaPeriodizacao>> listar(String alunoId) async {
    await aplicar(alunoId);
    final linhas = await _db
        .from('periodizacao_etapas')
        .select('*, aluno_fichas(id, ficha_id, estado, dias_semana, fichas(id, nome))')
        .eq('aluno_id', alunoId)
        .order('data_inicio', ascending: true)
        .order('criado_em', ascending: true);
    return List<Map<String, dynamic>>.from(linhas).map(EtapaPeriodizacao.doMapa).toList();
  }

  /// Cria ou atualiza. Devolve o id. Mudar a data de início já aplica a
  /// virada: antecipar para hoje troca o treino do aluno na hora.
  static Future<String> salvar(EtapaPeriodizacao e) async {
    final dados = {
      ...e.paraMapa(),
      'personal_id': _uid,
      'atualizado_em': DateTime.now().toUtc().toIso8601String(),
    };
    final String id;
    if (e.id == null) {
      id = (await _db.from('periodizacao_etapas').insert(dados).select('id').single())['id'] as String;
    } else {
      await _db.from('periodizacao_etapas').update(dados).eq('id', e.id!);
      id = e.id!;
      // As fichas ainda programadas acompanham a nova data de início.
      await _db
          .from('aluno_fichas')
          .update({'data_inicio': Datas.iso(e.dataInicio)})
          .eq('etapa_id', id)
          .eq('estado', 'programada');
    }
    await aplicar(e.alunoId);
    return id;
  }

  /// Apaga a etapa. As fichas que ainda nem começaram saem junto; as que
  /// já valeram ficam como histórico avulso.
  static Future<void> excluir(EtapaPeriodizacao e) async {
    await _db.from('aluno_fichas').delete().eq('etapa_id', e.id!).eq('estado', 'programada');
    await _db.from('periodizacao_etapas').delete().eq('id', e.id!);
    await aplicar(e.alunoId);
  }

  /// Põe uma ficha na etapa. O índice único (aluno, ficha) do 0001 vale:
  /// uma ficha avulsa ou encerrada é trazida para a etapa; uma que está
  /// valendo ou programada em outra etapa é recusada com a explicação.
  static Future<void> adicionarFicha({
    required EtapaPeriodizacao etapa,
    required String fichaId,
    required List<int> diasSemana,
  }) async {
    final existente = await _db
        .from('aluno_fichas')
        .select('id, etapa_id, estado')
        .eq('aluno_id', etapa.alunoId)
        .eq('ficha_id', fichaId)
        .maybeSingle();

    final comecou = !etapa.dataInicio.isAfter(Datas.dia(DateTime.now()));
    final dados = {
      'etapa_id': etapa.id,
      'dias_semana': diasSemana,
      'data_inicio': Datas.iso(etapa.dataInicio),
      'data_fim': null,
      'estado': comecou ? 'vigente' : 'programada',
    };

    if (existente == null) {
      await _db.from('aluno_fichas').insert({...dados, 'aluno_id': etapa.alunoId, 'ficha_id': fichaId});
    } else {
      final outraEtapa = existente['etapa_id'] != null && existente['etapa_id'] != etapa.id;
      if (outraEtapa && existente['estado'] != 'encerrada') {
        throw Exception(
          'Essa ficha já está em outra etapa deste aluno. Duplique a ficha '
          'para usá-la de novo.',
        );
      }
      // Avulsa valendo hoje e etapa futura: ela continua valendo até a
      // etapa começar — mover agora tiraria o treino do aluno antes da hora.
      if (existente['etapa_id'] == null && existente['estado'] == 'vigente' && !comecou) {
        throw Exception(
          'Essa ficha está valendo agora para o aluno. Para programá-la numa '
          'etapa futura, duplique a ficha.',
        );
      }
      await _db.from('aluno_fichas').update(dados).eq('id', existente['id'] as String);
    }
    await aplicar(etapa.alunoId);
  }

  /// Tira a ficha da etapa: programada some; vigente vai para o histórico.
  static Future<void> removerFicha(EtapaPeriodizacao etapa, FichaDaEtapa f) async {
    if (f.estado == 'programada') {
      await _db.from('aluno_fichas').delete().eq('id', f.id);
    } else {
      await _db.from('aluno_fichas').update({
        'estado': 'encerrada',
        'data_fim': Datas.iso(DateTime.now()),
      }).eq('id', f.id);
    }
  }

  static Future<void> mudarDias(FichaDaEtapa f, List<int> dias) async {
    await _db.from('aluno_fichas').update({'dias_semana': dias}).eq('id', f.id);
  }
}
