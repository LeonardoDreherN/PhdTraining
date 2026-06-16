import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';

class FrequenciaScreen extends StatefulWidget {
  const FrequenciaScreen({super.key});

  @override
  State<FrequenciaScreen> createState() => _FrequenciaScreenState();
}

class _FrequenciaScreenState extends State<FrequenciaScreen>
    with SingleTickerProviderStateMixin {
  final _db = Supabase.instance.client;
  late TabController _tabs;

  List<_AlunoFreq> _todos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _carregar();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final user = _db.auth.currentUser!;

      final alunos = await _db
          .from('alunos')
          .select('id, nome, genero')
          .eq('personal_id', user.id)
          .eq('ativo', true)
          .order('nome');

      final execucoes = await _db
          .from('treino_execucoes')
          .select('aluno_id, executado_em')
          .eq('personal_id', user.id);

      final hoje = DateTime.now();
      final inicioHoje = DateTime(hoje.year, hoje.month, hoje.day);

      // Group executions by aluno_id
      final Map<String, List<DateTime>> porAluno = {};
      for (final ex in execucoes as List) {
        final id = ex['aluno_id'] as String?;
        if (id == null) continue;
        final dt = DateTime.tryParse(ex['executado_em']?.toString() ?? '');
        if (dt == null) continue;
        porAluno.putIfAbsent(id, () => []).add(dt.toLocal());
      }

      final lista = (alunos as List).map((a) {
        final id = a['id'] as String;
        final datas = porAluno[id] ?? [];
        datas.sort((a, b) => b.compareTo(a));

        final ultimo = datas.isNotEmpty ? datas.first : null;

        // count last 30 days
        final inicio30 = inicioHoje.subtract(const Duration(days: 29));
        final count30 = datas.where((d) => d.isAfter(inicio30)).length;

        // last 7 days: index 0 = 6 days ago, index 6 = today
        final ultimos7 = List.generate(7, (i) {
          final dia = inicioHoje.subtract(Duration(days: 6 - i));
          return datas.any((d) =>
              d.year == dia.year && d.month == dia.month && d.day == dia.day);
        });

        return _AlunoFreq(
          aluno: Map<String, dynamic>.from(a),
          ultimoTreino: ultimo,
          total30d: count30,
          ultimos7dias: ultimos7,
        );
      }).toList();

      // Sort: most recently trained first, then never-trained alphabetically
      lista.sort((a, b) {
        if (a.ultimoTreino == null && b.ultimoTreino == null) return 0;
        if (a.ultimoTreino == null) return 1;
        if (b.ultimoTreino == null) return -1;
        return b.ultimoTreino!.compareTo(a.ultimoTreino!);
      });

      setState(() => _todos = lista);
    } finally {
      setState(() => _carregando = false);
    }
  }

  List<_AlunoFreq> get _ativos =>
      _todos.where((a) => a.status == 'ativo').toList();
  List<_AlunoFreq> get _alerta =>
      _todos.where((a) => a.status == 'alerta').toList();
  List<_AlunoFreq> get _inativos =>
      _todos.where((a) => a.status == 'inativo').toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Frequência',
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        bottom: TabBar(
          controller: _tabs,
          labelStyle: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.montserrat(fontSize: 12),
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          dividerColor: AppColors.divider,
          tabs: [
            Tab(text: 'Todos (${_todos.length})'),
            Tab(text: 'Ativos (${_ativos.length})'),
            Tab(text: 'Alerta (${_alerta.length})'),
            Tab(text: 'Inativos (${_inativos.length})'),
          ],
        ),
      ),
      body: _carregando
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _carregar,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildLista(_todos),
                  _buildLista(_ativos),
                  _buildLista(_alerta),
                  _buildLista(_inativos),
                ],
              ),
            ),
    );
  }

  Widget _buildLista(List<_AlunoFreq> lista) {
    if (lista.isEmpty) {
      return Center(
        child: Text('Nenhum aluno nesta categoria',
            style: GoogleFonts.montserrat(
                color: AppColors.textSecondary, fontSize: 14)),
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: _buildResumo(lista),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) => _buildCard(lista[i]),
              childCount: lista.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumo(List<_AlunoFreq> lista) {
    if (lista == _todos && _todos.isEmpty) return const SizedBox();

    final ativos = lista.where((a) => a.status == 'ativo').length;
    final alerta = lista.where((a) => a.status == 'alerta').length;
    final inativos = lista.where((a) => a.status == 'inativo').length;
    final mediaMes = lista.isEmpty
        ? 0.0
        : lista.map((a) => a.total30d).reduce((a, b) => a + b) / lista.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          _statCol('$ativos', 'ativos', AppColors.active),
          _divider(),
          _statCol('$alerta', 'alerta', const Color(0xFFFFA726)),
          _divider(),
          _statCol('$inativos', 'inativos', AppColors.error),
          _divider(),
          _statCol(
              mediaMes.toStringAsFixed(1).replaceAll('.0', ''),
              'treinos/mês',
              AppColors.textPrimary),
        ],
      ),
    );
  }

  Widget _statCol(String valor, String label, Color cor) {
    return Expanded(
      child: Column(
        children: [
          Text(valor,
              style: GoogleFonts.montserrat(
                  color: cor, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                  color: AppColors.textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: AppColors.divider);

  Widget _buildCard(_AlunoFreq af) {
    final nome = af.aluno['nome'] as String? ?? 'Aluno';
    final inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';
    final status = af.status;
    final cor = _corStatus(status);
    final rotulo = _rotuloStatus(status);
    final ultimoLabel = _labelUltimo(af.ultimoTreino);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: status == 'ativo'
              ? AppColors.active.withValues(alpha: 0.3)
              : status == 'alerta'
                  ? const Color(0xFFFFA726).withValues(alpha: 0.25)
                  : AppColors.divider,
          width: 0.7,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cor.withValues(alpha: 0.12),
                  border: Border.all(color: cor.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(inicial,
                      style: GoogleFonts.montserrat(
                          color: cor,
                          fontWeight: FontWeight.w700,
                          fontSize: 17)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nome,
                        style: GoogleFonts.montserrat(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(ultimoLabel,
                        style: GoogleFonts.montserrat(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(rotulo,
                        style: GoogleFonts.montserrat(
                            color: cor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Text('${af.total30d} treinos/30d',
                      style: GoogleFonts.montserrat(
                          color: AppColors.textHint, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDots(af.ultimos7dias),
        ],
      ),
    );
  }

  Widget _buildDots(List<bool> dias) {
    final hoje = DateTime.now();
    final labels = List.generate(
        7,
        (i) =>
            _diaLabel(hoje.subtract(Duration(days: 6 - i)).weekday));

    return Row(
      children: List.generate(7, (i) {
        final treinou = dias[i];
        final isHoje = i == 6;
        return Expanded(
          child: Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: treinou
                      ? AppColors.active.withValues(alpha: 0.2)
                      : AppColors.background,
                  border: Border.all(
                    color: treinou
                        ? AppColors.active
                        : isHoje
                            ? AppColors.textHint
                            : AppColors.divider,
                    width: treinou ? 1.5 : isHoje ? 1.5 : 0.8,
                  ),
                ),
                child: treinou
                    ? const Icon(Icons.check_rounded,
                        color: AppColors.active, size: 14)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(labels[i],
                  style: GoogleFonts.montserrat(
                      color: isHoje
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                      fontSize: 9,
                      fontWeight: isHoje ? FontWeight.w700 : FontWeight.w400)),
            ],
          ),
        );
      }),
    );
  }

  String _diaLabel(int weekday) {
    const map = {1: 'SEG', 2: 'TER', 3: 'QUA', 4: 'QUI', 5: 'SEX', 6: 'SÁB', 7: 'DOM'};
    return map[weekday] ?? '';
  }

  Color _corStatus(String status) {
    if (status == 'ativo') return AppColors.active;
    if (status == 'alerta') return const Color(0xFFFFA726);
    return AppColors.error;
  }

  String _rotuloStatus(String status) {
    if (status == 'ativo') return 'ATIVO';
    if (status == 'alerta') return 'ALERTA';
    return 'INATIVO';
  }

  String _labelUltimo(DateTime? dt) {
    if (dt == null) return 'Nunca treinou';
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Último treino hoje';
    if (diff == 1) return 'Último treino ontem';
    return 'Último treino há $diff dias';
  }
}

class _AlunoFreq {
  final Map<String, dynamic> aluno;
  final DateTime? ultimoTreino;
  final int total30d;
  final List<bool> ultimos7dias;

  const _AlunoFreq({
    required this.aluno,
    required this.ultimoTreino,
    required this.total30d,
    required this.ultimos7dias,
  });

  String get status {
    if (ultimoTreino == null) return 'inativo';
    final diff = DateTime.now().difference(ultimoTreino!).inDays;
    if (diff <= 7) return 'ativo';
    if (diff <= 14) return 'alerta';
    return 'inativo';
  }
}
