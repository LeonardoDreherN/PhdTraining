import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/cupom.dart';

/// Bio pública e cupons do profissional (migração 0022).
class CupomService {
  static final _db = Supabase.instance.client;
  static String get _uid => _db.auth.currentUser!.id;

  // ── Perfil público ──────────────────────────────────────────

  /// `null` quando o aluno não tem motivo para ver esse profissional (não é
  /// o dele nem foi indicado num cupom do dele).
  static Future<PerfilPublico?> perfilPublico(String id) async {
    final r = await _db.rpc('perfil_publico', params: {'p_id': id});
    final linhas = List<Map<String, dynamic>>.from(r as List);
    return linhas.isEmpty ? null : PerfilPublico.doMapa(linhas.first);
  }

  static Future<void> salvarBio({required String? bio, required List<String> formacoes}) async {
    final b = bio?.trim();
    final linhas = await _db
        .from('profiles')
        .update({
          'bio': (b == null || b.isEmpty) ? null : b,
          'formacoes': [for (final f in formacoes) if (f.trim().isNotEmpty) f.trim()],
        })
        .eq('id', _uid)
        .select('id');
    // Mesmo motivo de `ProfileService.atualizar`: update barrado pelo RLS
    // volta sem erro.
    if (linhas.isEmpty) throw Exception('Seu perfil não foi encontrado para atualizar.');
  }

  /// Outro profissional do PHD, para indicar num cupom. Por e-mail exato:
  /// a busca aberta exporia todos os profissionais (ver 0022).
  static Future<PerfilPublico?> profissionalPorEmail(String email) async {
    final r = await _db.rpc('profissional_por_email', params: {'p_email': email});
    final linhas = List<Map<String, dynamic>>.from(r as List);
    return linhas.isEmpty ? null : PerfilPublico.doMapa(linhas.first);
  }

  // ── Cupons ──────────────────────────────────────────────────

  /// Os cupons do próprio profissional, inclusive vencidos e desligados.
  static Future<List<Cupom>> meus() async {
    final linhas = await _db
        .from('cupons')
        .select()
        .eq('profissional_id', _uid)
        .order('ordem')
        .order('criado_em');
    final cupons = List<Map<String, dynamic>>.from(linhas).map(Cupom.doMapa).toList();
    return _comNomes(cupons);
  }

  /// O que o aluno vê: o RLS já tira os vencidos e desligados.
  static Future<List<Cupom>> doProfissional(String profissionalId) async {
    final linhas = await _db
        .from('cupons')
        .select()
        .eq('profissional_id', profissionalId)
        .order('ordem')
        .order('criado_em');
    final cupons = List<Map<String, dynamic>>.from(linhas).map(Cupom.doMapa).toList();
    return _comNomes(cupons);
  }

  /// Põe o nome do indicado em cada cupom, pelo perfil público.
  static Future<List<Cupom>> _comNomes(List<Cupom> cupons) async {
    final ids = {for (final c in cupons) if (c.indicadoId != null) c.indicadoId!};
    if (ids.isEmpty) return cupons;
    final perfis = <String, PerfilPublico>{};
    for (final id in ids) {
      try {
        final p = await perfilPublico(id);
        if (p != null) perfis[id] = p;
      } catch (_) {
        // Sem o nome, o cupom continua aparecendo — só sem o "de quem".
      }
    }
    return [
      for (final c in cupons)
        Cupom(
          id: c.id,
          titulo: c.titulo,
          descricao: c.descricao,
          codigo: c.codigo,
          link: c.link,
          indicadoId: c.indicadoId,
          indicadoNome: perfis[c.indicadoId]?.nomeExibicao,
          validoAte: c.validoAte,
          ativo: c.ativo,
          ordem: c.ordem,
        ),
    ];
  }

  static Future<void> salvar(Cupom c) async {
    final dados = {...c.paraMapa(), 'profissional_id': _uid};
    if (c.id == null) {
      await _db.from('cupons').insert(dados);
    } else {
      await _db.from('cupons').update(dados).eq('id', c.id!);
    }
  }

  static Future<void> excluir(String id) async {
    await _db.from('cupons').delete().eq('id', id);
  }
}
