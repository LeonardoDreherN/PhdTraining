import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/models/diario.dart';
import '../../../core/models/dieta.dart';
import '../../../core/models/perfil.dart';
import '../../../core/models/recursos_aluno.dart';
import '../../../core/services/diario_service.dart';
import '../../../core/services/dieta_service.dart';
import '../../../core/services/lembretes_service.dart';
import '../../../core/services/metas_service.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/dieta_calculos.dart';
import '../../../core/widgets/widgets.dart';
import '../../personal/dieta/plano_pdf.dart';
import 'cartao_agua.dart';
import 'folhas_registro.dart';
import 'lista_compras_screen.dart';
import 'receita_screen.dart';

/// A dieta do aluno: o que comer hoje, e o que ele já comeu.
///
/// O aluno marca a refeição quando faz. Daí sai o consumido do dia e a
/// adesão que o profissional vê — por isso marcar tem de ser um toque, sem
/// confirmação no caminho. Quem quer contar mais registra no diário: foto
/// do prato, "como foi?" e o que comeu fora do plano.
///
/// Água e diário funcionam mesmo sem plano: o aluno pode começar a
/// registrar antes de o profissional montar a dieta.
class AlunoDietaScreen extends StatefulWidget {
  const AlunoDietaScreen({super.key, required this.alunoId});

  final String alunoId;

  @override
  State<AlunoDietaScreen> createState() => _AlunoDietaScreenState();
}

class _AlunoDietaScreenState extends State<AlunoDietaScreen> {
  PlanoAlimentar? _plano;
  Set<String> _feitas = const {};
  List<RegistroDiario> _diario = const [];
  double? _peso;
  RecursosAluno _recursos = RecursosAluno.todos;
  bool _carregando = true;
  Object? _erro;

  /// Dia que está sendo visto. Começa hoje, mas dá para voltar: quem esqueceu
  /// de marcar o jantar ontem conseguir corrigir é o que mantém a adesão
  /// parecida com a realidade.
  late DateTime _dia = _soData(DateTime.now());

  /// Refeições cuja marcação está indo para o servidor. A linha fica
  /// marcada na hora e só desfaz se a gravação falhar.
  final _gravando = <String>{};

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  static DateTime _soData(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final (plano, feitas, diario, pesos, recursos) = await (
        DietaService.planoAtivo(widget.alunoId),
        DietaService.refeicoesFeitas(alunoId: widget.alunoId, dia: _dia),
        _talvez(
            DiarioService.listar(alunoId: widget.alunoId, de: _dia, ate: _dia)),
        _talvez(DiarioService.pesos(widget.alunoId, limite: 1)),
        MetasService.recursos(widget.alunoId),
      ).wait;
      if (!mounted) return;
      setState(() {
        _plano = plano;
        _feitas = feitas;
        _diario = diario ?? const [];
        _peso = pesos?.lastOrNull?.pesoKg;
        _recursos = recursos;
      });
      // Se o profissional mudou o horário de uma refeição, o lembrete
      // acompanha na próxima vez que o aluno abre a dieta.
      unawaited(LembretesService.aplicar(plano));
    } catch (e) {
      if (mounted) setState(() => _erro = e);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  /// O diário é complemento: se a tabela ainda não existe no banco (a
  /// migration não rodou), a dieta abre sem ele em vez de dar erro.
  static Future<T?> _talvez<T>(Future<T> f) async {
    try {
      return await f;
    } catch (_) {
      return null;
    }
  }

  Future<void> _trocarDia(DateTime novo) async {
    setState(() => _dia = _soData(novo));
    try {
      final (feitas, diario) = await (
        DietaService.refeicoesFeitas(alunoId: widget.alunoId, dia: _dia),
        _talvez(
            DiarioService.listar(alunoId: widget.alunoId, de: _dia, ate: _dia)),
      ).wait;
      if (mounted) {
        setState(() {
          _feitas = feitas;
          _diario = diario ?? const [];
        });
      }
    } catch (_) {
      if (mounted) setState(() => _feitas = const {});
    }
  }

  Future<void> _recarregarDiario() async {
    final d = await _talvez(
        DiarioService.listar(alunoId: widget.alunoId, de: _dia, ate: _dia));
    if (mounted && d != null) setState(() => _diario = d);
  }

  /// Registra no diário. Refeição do plano registrada como "segui" ou
  /// "parecido" também fica marcada como feita — é a mesma informação, e
  /// pedir os dois toques seria burocracia.
  Future<void> _registrar({Refeicao? refeicao}) async {
    final r = await registrarRefeicao(
      context,
      alunoId: widget.alunoId,
      dia: _dia,
      refeicaoId: refeicao?.id,
      titulo: refeicao?.nome,
    );
    if (r == null || !r.salvou || !mounted) return;
    if (refeicao != null &&
        r.aderencia != Aderencia.fora &&
        !_feitas.contains(refeicao.id)) {
      await _marcar(refeicao, true);
    }
    await _recarregarDiario();
  }

  Future<void> _excluirRegistro(RegistroDiario r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar do diário?'),
        content: Text('O registro "${r.titulo}" e a foto dele somem.',
            style: AppText.body(14)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Apagar',
                style: AppText.bodyStrong(14, color: AppColors.dangerText)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await DiarioService.excluir(r);
      await _recarregarDiario();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Não consegui apagar: $e', style: AppText.body(13.5))),
        );
      }
    }
  }

  /// O PDF leva a marca do personal do aluno, não a do aluno.
  Future<void> _pdf(PlanoAlimentar p) async {
    String nome = 'Aluno';
    Perfil? marca;
    try {
      final aluno = await Supabase.instance.client
          .from('alunos')
          .select('nome, personal_id')
          .eq('id', widget.alunoId)
          .maybeSingle();
      nome = aluno?['nome'] as String? ?? nome;
      final pid = aluno?['personal_id'] as String?;
      if (pid != null) {
        final m = await ProfileService.doPersonal(pid);
        if (m != null) {
          marca = Perfil.doMapa({...m, 'id': pid, 'role': 'personal'});
        }
      }
    } catch (_) {
      // Sem a marca o PDF sai do mesmo jeito, só sem logo.
    }
    if (!mounted) return;
    await compartilharPlanoPdf(context, p, alunoNome: nome, marca: marca);
  }

  Future<void> _abrirLembretes() async {
    final atual = await LembretesService.estado();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => _FolhaLembretes(inicial: atual, plano: _plano),
    );
  }

  Future<void> _marcar(Refeicao r, bool feita) async {
    // Marca na tela primeiro: esperar a ida ao servidor para o check
    // aparecer faz a pessoa tocar de novo achando que não pegou.
    setState(() {
      _gravando.add(r.id);
      _feitas = feita ? {..._feitas, r.id} : (_feitas.toSet()..remove(r.id));
    });

    try {
      await DietaService.marcarRefeicao(
        alunoId: widget.alunoId,
        refeicaoId: r.id,
        dia: _dia,
        feita: feita,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Desfaz: mostrar marcado o que não foi salvo seria mentir para os
        // dois lados — o aluno acha que registrou e o profissional não vê.
        _feitas = feita ? (_feitas.toSet()..remove(r.id)) : {..._feitas, r.id};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceHigh,
          content:
              Text('Não consegui registrar: $e', style: AppText.body(13.5)),
        ),
      );
    } finally {
      if (mounted) setState(() => _gravando.remove(r.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Minha dieta', style: AppText.title(16)),
        actions: [
          if (_plano != null && !_plano!.vazio) ...[
            if (_recursos.listaCompras)
              IconButton(
                tooltip: 'Lista de compras',
                icon: Icon(Icons.shopping_cart_outlined,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ListaComprasScreen(plano: _plano!)),
                ),
              ),
            IconButton(
              tooltip: 'Baixar o plano em PDF',
              icon: Icon(Icons.picture_as_pdf_outlined,
                  color: AppColors.textPrimary),
              onPressed: () => _pdf(_plano!),
            ),
          ],
          IconButton(
            tooltip: 'Lembretes',
            icon: Icon(Icons.notifications_none_rounded,
                color: AppColors.textPrimary),
            onPressed: _abrirLembretes,
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: _corpo(),
    );
  }

  Widget _corpo() {
    if (_carregando && _plano == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    if (_erro != null) {
      return PhdEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Não consegui carregar',
        message: '$_erro',
        actionLabel: 'Tentar de novo',
        onAction: _carregar,
      );
    }

    final p = _plano;
    final temPlano = p != null && !p.vazio;
    final extras = _diario.where((r) => r.foraDoPlano).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      backgroundColor: AppColors.surface,
      onRefresh: _carregar,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.md,
          AppSpacing.xl,
          AppSpacing.huge * 2,
        ),
        children: [
          _tiraDeDias(),
          const SizedBox(height: AppSpacing.lg),
          CartaoAgua(
            alunoId: widget.alunoId,
            dia: _dia,
            metaMl:
                DiarioService.metaAgua(metaDoPlano: p?.aguaMl, pesoKg: _peso),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!temPlano)
            PhdCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.restaurant_menu_rounded,
                      color: AppColors.textMuted),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Seu profissional ainda não montou sua dieta. Enquanto isso, '
                      'registre o que come: ajuda a montar um plano do seu jeito.',
                      style: AppText.body(13.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            _resumoDoDia(p),
            const SizedBox(height: AppSpacing.xl),
            const PhdSectionHeader(label: 'Refeições'),
            const SizedBox(height: AppSpacing.sm),
            for (final r in p.refeicoes)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _cartaoRefeicao(r),
              ),
          ],
          if (_recursos.diario) ...[
            const SizedBox(height: AppSpacing.lg),
            PhdSectionHeader(label: temPlano ? 'Fora do plano' : 'Diário'),
            const SizedBox(height: AppSpacing.sm),
            for (final r in extras)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: PhdCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: _linhaRegistro(r),
                ),
              ),
            PhdAddCard(
              label: temPlano
                  ? 'Registrar algo fora do plano'
                  : 'Registrar uma refeição',
              icon: Icons.add_a_photo_outlined,
              onTap: () => _registrar(),
            ),
          ],
          if (temPlano &&
              p.observacoes != null &&
              p.observacoes!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const PhdSectionHeader(label: 'Orientações'),
            const SizedBox(height: AppSpacing.sm),
            PhdCard(
              child: Text(
                p.observacoes!,
                style: AppText.body(13.5, color: AppColors.textSecondary),
              ),
            ),
          ],
          if (temPlano && p.assinado) ...[
            const SizedBox(height: AppSpacing.xl),
            _rodapeAssinatura(p),
          ],
        ],
      ),
    );
  }

  // ── Dias ────────────────────────────────────────────────────

  Widget _tiraDeDias() {
    final hoje = _soData(DateTime.now());
    // Sete dias, do mais antigo para hoje: a ordem do calendário, com hoje
    // na ponta onde o dedo já está.
    final dias = [
      for (var i = 6; i >= 0; i--) hoje.subtract(Duration(days: i)),
    ];

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        itemCount: dias.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final d = dias[dias.length - 1 - i];
          return _botaoDia(d, ehHoje: d == hoje);
        },
      ),
    );
  }

  Widget _botaoDia(DateTime d, {required bool ehHoje}) {
    final selecionado = d == _dia;
    return InkWell(
      borderRadius: AppRadius.rMd,
      onTap: selecionado ? null : () => _trocarDia(d),
      child: Container(
        width: 50,
        decoration: BoxDecoration(
          color: selecionado ? AppColors.accent : AppColors.surface,
          borderRadius: AppRadius.rMd,
          border: Border.all(
            color: selecionado ? AppColors.accent : AppColors.line,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _diaDaSemana(d),
              style: AppText.caption(
                10.5,
                color: selecionado ? AppColors.onAccent : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              ehHoje ? 'hoje' : d.day.toString(),
              style: AppText.number(
                ehHoje ? 12 : 15,
                color: selecionado ? AppColors.onAccent : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _diaDaSemana(DateTime d) => switch (d.weekday) {
        DateTime.monday => 'seg',
        DateTime.tuesday => 'ter',
        DateTime.wednesday => 'qua',
        DateTime.thursday => 'qui',
        DateTime.friday => 'sex',
        DateTime.saturday => 'sáb',
        _ => 'dom',
      };

  // ── Resumo ──────────────────────────────────────────────────

  /// Soma só as refeições marcadas: é o consumido, não o prescrito.
  ({
    double kcal,
    double proteina,
    double carboidrato,
    double gordura,
    double fibra
  }) _consumido(PlanoAlimentar p) {
    var kcal = 0.0, pr = 0.0, c = 0.0, g = 0.0, f = 0.0;
    for (final r in p.refeicoes) {
      if (!_feitas.contains(r.id)) continue;
      final t = r.total;
      kcal += t.kcal;
      pr += t.proteina;
      c += t.carboidrato;
      g += t.gordura;
      f += t.fibra;
    }
    return (kcal: kcal, proteina: pr, carboidrato: c, gordura: g, fibra: f);
  }

  Widget _resumoDoDia(PlanoAlimentar p) {
    if (!_recursos.nutricional) {
      final feitas = p.refeicoes.where((r) => _feitas.contains(r.id)).length;
      return PhdCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhdStat(
                label: 'Refeições de hoje',
                value: '$feitas de ${p.refeicoes.length}',
                valueSize: 30),
            const SizedBox(height: AppSpacing.md),
            PhdSegments(total: p.refeicoes.length, filled: feitas, height: 8),
          ],
        ),
      );
    }
    final consumido = _consumido(p);
    final meta = p.metaKcal;
    final feitas = p.refeicoes.where((r) => _feitas.contains(r.id)).length;

    return PhdCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: PhdStat(
                  label: 'Consumido',
                  value: '${consumido.kcal.round()}',
                  valueSize: 34,
                ),
              ),
              Expanded(
                child: PhdStat(
                  label: meta == null ? 'kcal' : 'Meta do dia',
                  value: meta == null ? 'kcal' : '${meta.round()} kcal',
                  valueSize: 15,
                  valueColor: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (meta != null) ...[
            const SizedBox(height: AppSpacing.md),
            PhdProgressBar(value: proporcao(consumido.kcal, meta), height: 9),
          ],
          const SizedBox(height: AppSpacing.lg),
          PhdSegments(total: p.refeicoes.length, filled: feitas),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$feitas de ${p.refeicoes.length} refeições marcadas',
            style: AppText.caption(11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: AppSpacing.lg),
          Divider(color: AppColors.line, height: 1),
          const SizedBox(height: AppSpacing.lg),
          _macro('Proteína', consumido.proteina, p.metaProteina),
          const SizedBox(height: AppSpacing.md),
          _macro('Carboidrato', consumido.carboidrato, p.metaCarboidrato),
          const SizedBox(height: AppSpacing.md),
          _macro('Gordura', consumido.gordura, p.metaGordura),
        ],
      ),
    );
  }

  Widget _macro(String nome, double consumido, double? meta) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(nome, style: AppText.caption(12))),
            Text(
              meta == null
                  ? '${consumido.round()} g'
                  : '${consumido.round()} / ${meta.round()} g',
              style: AppText.number(12.5, color: AppColors.textSecondary),
            ),
          ],
        ),
        if (meta != null) ...[
          const SizedBox(height: 5),
          PhdProgressBar(value: proporcao(consumido, meta)),
        ],
      ],
    );
  }

  // ── Refeição ────────────────────────────────────────────────

  Widget _cartaoRefeicao(Refeicao r) {
    final feita = _feitas.contains(r.id);
    final ocupada = _gravando.contains(r.id);
    final t = r.total;

    return PhdCard(
      accentBar: feita ? AppColors.success : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.nome, style: AppText.title(15.5)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (r.horarioTexto != null) r.horarioTexto!,
                        if (_recursos.nutricional) '${t.kcal.round()} kcal',
                      ].join('  ·  '),
                      style: AppText.caption(11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: ocupada ? null : () => _marcar(r, !feita),
                tooltip: feita
                    ? 'Desmarcar ${r.nome}'
                    : 'Marcar ${r.nome} como feita',
                icon: Icon(
                  feita
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 28,
                  color: feita ? AppColors.success : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._blocosDeItens(r),
          for (final rr in r.receitas) _linhaReceita(rr),
          if (_recursos.diario)
            for (final reg in _diario.where((d) => d.refeicaoId == r.id)) ...[
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: AppRadius.rMd,
                ),
                child: _linhaRegistro(reg),
              ),
            ],
          if (_recursos.diario) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _registrar(refeicao: r),
                icon: Icon(Icons.add_a_photo_outlined,
                    size: 17, color: AppColors.accent),
                label: Text('Registrar no diário',
                    style: AppText.bodyStrong(13, color: AppColors.accent)),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(0, 36),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Receita na refeição: toca e abre com os ingredientes na porção dele.
  Widget _linhaReceita(ReceitaNaRefeicao rr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: AppColors.tint(AppColors.accent),
        borderRadius: AppRadius.rMd,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
              builder: (_) => ReceitaScreen(
                receita: rr.receita,
                porcoes: rr.porcoes,
                mostrarNumeros: _recursos.nutricional,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            child: Row(
              children: [
                Icon(Icons.menu_book_rounded,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rr.receita.nome, style: AppText.bodyStrong(13.5)),
                      Text('Receita · ${rr.porcoesTextoCompleto}',
                          style: AppText.caption(11.5,
                              color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Text('Ver receita',
                    style: AppText.bodyStrong(12, color: AppColors.accent)),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Um registro do diário: foto, título, "como foi" e o texto.
  Widget _linhaRegistro(RegistroDiario r) {
    final (tom, rotulo) = switch (r.aderencia) {
      Aderencia.seguiu => (PhdTone.success, 'Seguiu'),
      Aderencia.parecido => (PhdTone.neutral, 'Parecido'),
      Aderencia.fora => (PhdTone.warning, 'Fugiu'),
      null => (PhdTone.neutral, null),
    };
    final hora = '${r.registradoEm.hour.toString().padLeft(2, '0')}:'
        '${r.registradoEm.minute.toString().padLeft(2, '0')}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: AppRadius.rMd,
          child: SizedBox.square(
            dimension: 56,
            child: r.fotoUrl == null
                ? ColoredBox(
                    color: AppColors.surface,
                    child:
                        Icon(Icons.notes_rounded, color: AppColors.textMuted),
                  )
                : GestureDetector(
                    onTap: () => _verFoto(r.fotoUrl!),
                    child: Image.network(
                      r.fotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: AppColors.surface,
                        child: Icon(Icons.image_not_supported_outlined,
                            color: AppColors.textMuted),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      r.foraDoPlano ? r.titulo : 'Registrado às $hora',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.bodyStrong(13),
                    ),
                  ),
                  if (rotulo != null) ...[
                    const SizedBox(width: 6),
                    PhdStatusChip(label: rotulo, tone: tom),
                  ],
                ],
              ),
              if (r.descricao != null) ...[
                const SizedBox(height: 2),
                Text(r.descricao!, maxLines: 3, style: AppText.caption(12)),
              ] else if (r.foraDoPlano)
                Text(hora,
                    style: AppText.caption(11.5, color: AppColors.textMuted)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Apagar do diário',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.delete_outline_rounded,
              size: 19, color: AppColors.textMuted),
          onPressed: () => _excluirRegistro(r),
        ),
      ],
    );
  }

  void _verFoto(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: SizedBox.expand(
            child: InteractiveViewer(
                child: Image.network(url, fit: BoxFit.contain)),
          ),
        ),
      ),
    );
  }

  /// Monta as linhas da refeição, com os substitutos juntos.
  ///
  /// Item solto é uma linha. Grupo de substitutos vira um bloco "escolha um",
  /// porque o aluno precisa entender que come **um** deles — listar os três
  /// em sequência faria ele comer os três.
  List<Widget> _blocosDeItens(Refeicao r) {
    final soltos = <ItemRefeicao>[];
    final grupos = <String, List<ItemRefeicao>>{};

    for (final i in r.itens) {
      final g = i.grupoSubstituicao;
      if (g == null) {
        soltos.add(i);
      } else {
        grupos.putIfAbsent(g, () => []).add(i);
      }
    }

    return [
      for (final i in soltos) _linhaItem(i),
      for (final itens in grupos.values)
        if (itens.length == 1)
          // Grupo que sobrou com um item só não é escolha: mostra como
          // item normal em vez de "escolha um" com uma opção.
          _linhaItem(itens.first)
        else
          _blocoSubstitutos(itens),
    ];
  }

  Widget _linhaItem(ItemRefeicao i) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: AppSpacing.sm),
            child: Icon(Icons.circle, size: 5, color: AppColors.textMuted),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(i.alimento.rotulo, style: AppText.body(14)),
                const SizedBox(height: 1),
                Text(
                  i.quantidadeTexto,
                  style: AppText.caption(11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          if (i.observacoes != null && i.observacoes!.trim().isNotEmpty)
            Tooltip(
              message: i.observacoes!,
              child: Icon(Icons.info_outline_rounded,
                  size: 15, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _blocoSubstitutos(List<ItemRefeicao> itens) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm + 2,
        AppSpacing.md,
        AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: AppRadius.rMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.swap_horiz_rounded, size: 15, color: AppColors.accent),
              const SizedBox(width: 5),
              Text(
                'Escolha um',
                style: AppText.caption(11, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (final i in itens)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(i.alimento.rotulo, style: AppText.body(13.5)),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    i.quantidadeTexto,
                    style:
                        AppText.caption(11.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _rodapeAssinatura(PlanoAlimentar p) {
    final em = p.assinadoEm!;
    return Row(
      children: [
        Icon(Icons.verified_rounded, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Plano prescrito por nutricionista · CRN ${p.crnAssinatura} · '
            '${em.day.toString().padLeft(2, '0')}/'
            '${em.month.toString().padLeft(2, '0')}/${em.year}',
            style: AppText.caption(11, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

/// Liga e desliga os lembretes da dieta.
class _FolhaLembretes extends StatefulWidget {
  const _FolhaLembretes({required this.inicial, this.plano});

  final ({bool refeicoes, bool agua}) inicial;
  final PlanoAlimentar? plano;

  @override
  State<_FolhaLembretes> createState() => _FolhaLembretesState();
}

class _FolhaLembretesState extends State<_FolhaLembretes> {
  late bool _refeicoes = widget.inicial.refeicoes;
  late bool _agua = widget.inicial.agua;

  static String _hhmm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final horarios = widget.plano == null
        ? const <({String nome, int hora, int minuto})>[]
        : LembretesService.horariosDoPlano(widget.plano!);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lembretes', style: AppText.title(19)),
          const SizedBox(height: 4),
          Text('Valem para este aparelho.', style: AppText.caption(13)),
          const SizedBox(height: AppSpacing.lg),
          _linha(
            icone: Icons.restaurant_rounded,
            titulo: 'Hora das refeições',
            apoio: horarios.isEmpty
                ? 'Aparece quando o plano tiver horários'
                : horarios.map((h) => _hhmm(h.hora, h.minuto)).join(' · '),
            valor: _refeicoes,
            onChanged: (v) {
              setState(() => _refeicoes = v);
              LembretesService.definir(refeicoes: v, plano: widget.plano);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          _linha(
            icone: Icons.water_drop_rounded,
            titulo: 'Beber água',
            apoio: 'De 2 em 2 horas, das 9h às 21h',
            valor: _agua,
            onChanged: (v) {
              setState(() => _agua = v);
              LembretesService.definir(agua: v, plano: widget.plano);
            },
          ),
        ],
      ),
    );
  }

  Widget _linha({
    required IconData icone,
    required String titulo,
    required String apoio,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    return PhdCard(
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icone, size: 20, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: AppText.bodyStrong(14)),
                Text(apoio, maxLines: 2, style: AppText.caption(11.5)),
              ],
            ),
          ),
          Switch(value: valor, onChanged: onChanged),
        ],
      ),
    );
  }
}
