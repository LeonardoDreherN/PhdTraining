import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/avaliacao.dart';
import '../models/conversa.dart';
import '../models/diario.dart';
import '../models/dieta.dart';
import 'agenda_service.dart';
import 'arquivo_service.dart';
import 'avaliacao_service.dart';
import 'chat_service.dart';
import 'diario_service.dart';
import 'dieta_service.dart';
import 'ficha_service.dart';
import 'progresso_service.dart';

/// Tudo o que o perfil do aluno mostra, carregado de uma vez.
class DetalheAluno {
  const DetalheAluno({
    this.fichas = const [],
    this.treinos = const [],
    this.fotos = const [],
    this.arquivos = 0,
    this.avaliacoes = const [],
    this.pesos = const [],
    this.plano,
    this.consultas = const [],
    this.cobrancas = const [],
    this.naoLidas = 0,
  });

  /// Linhas de `aluno_fichas` com a ficha embutida e os totais de
  /// `FichaService.fichasDoAluno`.
  final List<Map<String, dynamic>> fichas;

  /// Quando treinou, nos últimos 35 dias (a grade de frequência).
  final List<DateTime> treinos;
  final List<Map<String, dynamic>> fotos;
  final int arquivos;
  final List<ResumoSessao> avaliacoes;
  final List<RegistroPeso> pesos;
  final PlanoAlimentar? plano;
  final List<Consulta> consultas;

  /// As mensalidades mais recentes, da mais nova para a mais antiga.
  final List<Map<String, dynamic>> cobrancas;
  final int naoLidas;

  /// Dias de treino por semana pedidos pelas fichas. Ficha sem dia fixo
  /// conta 3, o mínimo que dá resultado — mesmo critério da home.
  int get diasPorSemana {
    var total = 0;
    for (final f in fichas) {
      final d = (f['dias_semana'] as List?)?.length ?? 0;
      total += d == 0 ? 3 : d;
    }
    return total.clamp(0, 7);
  }

  /// 0 a 1 nos últimos 30 dias; nulo sem ficha (não há o que cumprir).
  double? get adesao {
    final porSemana = diasPorSemana;
    if (porSemana == 0) return null;
    final limite = DateTime.now().subtract(const Duration(days: 30));
    final feitos = treinos.where((t) => t.isAfter(limite)).length;
    return (feitos / (porSemana * 30 / 7)).clamp(0.0, 1.0);
  }

  DateTime? get ultimoTreino => treinos.isEmpty ? null : treinos.reduce((a, b) => a.isAfter(b) ? a : b);

  /// O peso mais recente entre avaliações e pesagens de casa.
  ({DateTime data, double peso})? get pesoAtual {
    final todos = [
      for (final s in avaliacoes)
        if (s.peso != null) (data: s.sessao.data, peso: s.peso!),
      for (final p in pesos) (data: p.data, peso: p.pesoKg),
    ]..sort((a, b) => a.data.compareTo(b.data));
    return todos.isEmpty ? null : todos.last;
  }

  Consulta? get proximaConsulta =>
      consultas.where((c) => c.ativa && !c.passou && c.status != StatusConsulta.realizada).firstOrNull;
}

class AlunoDetalheService {
  static final _db = Supabase.instance.client;

  /// Cada parte que falha (tabela de uma migration ainda não aplicada, por
  /// exemplo) vira vazia: o perfil abre com o que tiver.
  static Future<T?> _talvez<T>(Future<T> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }

  static Future<DetalheAluno> carregar(String alunoId) async {
    final desde = DateTime.now().subtract(const Duration(days: 35));

    // Dois grupos em paralelo: o `wait` de records vai até nove futuros.
    final extras = (
      _talvez(AgendaService.doAluno(alunoId)),
      _talvez(_db
          .from('cobrancas')
          .select('status, valor_centavos, vencimento, pago_em')
          .eq('aluno_id', alunoId)
          .order('vencimento', ascending: false)
          .limit(3)),
      _talvez(ChatService.naoLidas()),
    ).wait;
    final (fichas, execucoes, fotos, arquivos, avaliacoes, pesos, plano) = await (
      _talvez(FichaService.fichasDoAluno(alunoId)),
      _talvez(_db
          .from('treino_execucoes')
          .select('executado_em')
          .eq('aluno_id', alunoId)
          .gte('executado_em', desde.toUtc().toIso8601String())),
      _talvez(ProgressoService.listarFotos(alunoId)),
      _talvez(ArquivoService.listar(alunoId)),
      _talvez(AvaliacaoService.listar(alunoId)),
      _talvez(DiarioService.pesos(alunoId, limite: 20)),
      _talvez(DietaService.planoAtivo(alunoId)),
    ).wait;
    final (consultas, cobrancas, naoLidas) = await extras;

    return DetalheAluno(
      fichas: fichas ?? const [],
      treinos: [
        for (final e in List<Map<String, dynamic>>.from(execucoes ?? const []))
          if (DateTime.tryParse(e['executado_em'] as String? ?? '') case final d?) d.toLocal(),
      ],
      fotos: fotos ?? const [],
      arquivos: (arquivos as List?)?.length ?? 0,
      avaliacoes: avaliacoes ?? const [],
      pesos: pesos ?? const [],
      plano: plano,
      consultas: consultas ?? const [],
      cobrancas: List<Map<String, dynamic>>.from(cobrancas ?? const []),
      naoLidas: naoLidas?[alunoId] ?? 0,
    );
  }
}
