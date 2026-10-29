import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversa.dart';

/// Uma linha da caixa de mensagens do profissional.
typedef ConversaResumo = ({Map<String, dynamic> aluno, Mensagem? ultima, int naoLidas});

/// Chat aluno ↔ profissional. A conversa é o `aluno_id` (ver 0017).
class ChatService {
  static final _db = Supabase.instance.client;

  static String get _eu => _db.auth.currentUser!.id;

  /// As últimas [limite] mensagens, da mais antiga para a mais nova — a
  /// ordem em que a tela desenha.
  static Future<List<Mensagem>> mensagens(String alunoId, {int limite = 200}) async {
    final linhas = await _db
        .from('mensagens')
        .select()
        .eq('aluno_id', alunoId)
        .order('criado_em', ascending: false)
        .limit(limite);
    return List<Map<String, dynamic>>.from(linhas).map(Mensagem.doMapa).toList().reversed.toList();
  }

  static Future<Mensagem> enviar(String alunoId, String texto) async {
    final linha = await _db
        .from('mensagens')
        .insert({'aluno_id': alunoId, 'autor_id': _eu, 'texto': texto.trim()})
        .select()
        .single();
    return Mensagem.doMapa(linha);
  }

  static Future<void> marcarLidas(String alunoId) async {
    try {
      await _db.rpc('marcar_mensagens_lidas', params: {'p_aluno_id': alunoId});
    } catch (_) {
      // Marcar como lida é cortesia: falhar não pode atrapalhar a conversa.
    }
  }

  /// Avisa cada mensagem nova da conversa, das duas pontas. Devolve o canal
  /// para a tela fechar ao sair.
  static RealtimeChannel ouvir(String alunoId, void Function(Mensagem) aoChegar) {
    return _db
        .channel('mensagens:$alunoId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'mensagens',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'aluno_id',
            value: alunoId,
          ),
          callback: (p) => aoChegar(Mensagem.doMapa(p.newRecord)),
        )
        .subscribe();
  }

  static Future<void> pararDeOuvir(RealtimeChannel canal) => _db.removeChannel(canal);

  /// Não lidas por conversa, para o selo do ícone. O RLS já limita às
  /// conversas de quem pergunta.
  static Future<Map<String, int>> naoLidas() async {
    try {
      final linhas = await _db
          .from('mensagens')
          .select('aluno_id')
          .isFilter('lida_em', null)
          .neq('autor_id', _eu);
      final r = <String, int>{};
      for (final l in List<Map<String, dynamic>>.from(linhas)) {
        final a = l['aluno_id'] as String;
        r[a] = (r[a] ?? 0) + 1;
      }
      return r;
    } on PostgrestException {
      return const {};
    }
  }

  /// A caixa do profissional: todos os alunos ativos, quem mandou mensagem
  /// por último em cima.
  static Future<List<ConversaResumo>> caixa() async {
    final alunos = List<Map<String, dynamic>>.from(
      await _db.from('alunos').select().eq('personal_id', _eu).eq('ativo', true),
    );
    final recentes = List<Map<String, dynamic>>.from(
      await _db.from('mensagens').select().order('criado_em', ascending: false).limit(500),
    );
    final ultima = <String, Mensagem>{};
    final naoLidas = <String, int>{};
    for (final l in recentes) {
      final m = Mensagem.doMapa(l);
      ultima.putIfAbsent(m.alunoId, () => m);
      if (m.lidaEm == null && m.autorId != _eu) {
        naoLidas[m.alunoId] = (naoLidas[m.alunoId] ?? 0) + 1;
      }
    }

    final lista = [
      for (final a in alunos)
        (aluno: a, ultima: ultima[a['id']], naoLidas: naoLidas[a['id']] ?? 0),
    ]..sort((x, y) {
        final dx = x.ultima?.criadoEm, dy = y.ultima?.criadoEm;
        if (dx == null && dy == null) {
          return (x.aluno['nome'] as String? ?? '').compareTo(y.aluno['nome'] as String? ?? '');
        }
        if (dx == null) return 1;
        if (dy == null) return -1;
        return dy.compareTo(dx);
      });
    return lista;
  }
}
