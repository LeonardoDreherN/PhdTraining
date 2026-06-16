import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/aluno_service.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/services/progresso_service.dart';
import '../../../core/services/arquivo_service.dart';
import '../home/widgets/phd_logo.dart';

class AlunoPerfilScreen extends StatefulWidget {
  final Map<String, dynamic> aluno;
  const AlunoPerfilScreen({super.key, required this.aluno});

  @override
  State<AlunoPerfilScreen> createState() => _AlunoPerfilScreenState();
}

class _AlunoPerfilScreenState extends State<AlunoPerfilScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  late Map<String, dynamic> _aluno;

  // Início tab
  List<Map<String, dynamic>> _fichas = [];
  List<Map<String, dynamic>> _execucoes = [];
  List<Map<String, dynamic>> _fotos = [];
  List<Map<String, dynamic>> _arquivos = [];
  bool _carregando = true;

  // Anotações
  final _notasCtrl = TextEditingController();
  bool _salvandoNota = false;

  @override
  void initState() {
    super.initState();
    _aluno = Map<String, dynamic>.from(widget.aluno);
    _tab = TabController(length: 2, vsync: this);
    _notasCtrl.text = _aluno['notas'] ?? '';
    _carregar();
  }

  @override
  void dispose() {
    _tab.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() => _carregando = true);
    try {
      final alunoId = _aluno['id'].toString();
      final seteAtras = DateTime.now().subtract(const Duration(days: 6));

      final results = await Future.wait([
        FichaService.fichasDoAluno(alunoId),
        Supabase.instance.client
            .from('treino_execucoes')
            .select('executado_em')
            .eq('aluno_id', alunoId)
            .gte('executado_em', seteAtras.toIso8601String())
            .order('executado_em'),
        ProgressoService.listarFotos(alunoId),
        ArquivoService.listar(alunoId),
      ]);

      setState(() {
        _fichas = (results[0] as List).cast<Map<String, dynamic>>();
        _execucoes = (results[1] as List).cast<Map<String, dynamic>>();
        _fotos = (results[2] as List).cast<Map<String, dynamic>>();
        _arquivos = (results[3] as List).cast<Map<String, dynamic>>();
      });
    } finally {
      setState(() => _carregando = false);
    }
  }

  Future<void> _salvarNota() async {
    setState(() => _salvandoNota = true);
    try {
      await AlunoService.atualizar(_aluno['id'].toString(), {'notas': _notasCtrl.text.trim()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anotação salva!'), backgroundColor: AppColors.active),
        );
      }
    } finally {
      if (mounted) setState(() => _salvandoNota = false);
    }
  }

  Future<void> _toggleStatus() async {
    final novoStatus = !(_aluno['ativo'] as bool);
    await AlunoService.alterarStatus(_aluno['id'].toString(), novoStatus);
    setState(() => _aluno['ativo'] = novoStatus);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(novoStatus ? 'Aluno ativado' : 'Aluno inativado'),
          backgroundColor: novoStatus ? AppColors.active : AppColors.inactive,
        ),
      );
    }
  }

  Future<void> _excluir() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Excluir aluno', style: TextStyle(color: Colors.white)),
        content: Text('Deseja excluir ${_aluno['nome']}? Esta ação não pode ser desfeita.',
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Excluir', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await AlunoService.deletar(_aluno['id'].toString());
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Padding(
            padding: EdgeInsets.only(left: 12),
            child: Row(children: [
              Icon(Icons.chevron_left, color: AppColors.textSecondary, size: 18),
              Text('Voltar', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
        ),
        leadingWidth: 80,
        title: const PHDLogo(fontSize: 26),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _carregando
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : TabBarView(
                    controller: _tab,
                    children: [_buildInicio(), _buildOpcoes()],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final nome = _aluno['nome'] ?? '';
    final grupo = _aluno['grupo'] ?? '';
    final ativo = _aluno['ativo'] as bool? ?? true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
            ),
            child: Center(
              child: Text(
                nome.isNotEmpty ? nome[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary, fontSize: 26, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nome,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (grupo.isNotEmpty) _buildBadge(grupo, AppColors.primary),
                    const SizedBox(width: 6),
                    _buildBadge(
                      ativo ? 'Ativo' : 'Inativo',
                      ativo ? AppColors.active : AppColors.inactive,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: TabBar(
        controller: _tab,
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorWeight: 2.5,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w400, fontSize: 14),
        tabs: const [Tab(text: 'Início'), Tab(text: 'Opções')],
      ),
    );
  }

  // ──────────────────────────── ABA INÍCIO ────────────────────────────

  Widget _buildInicio() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFrequencia(),
          const SizedBox(height: 20),
          _buildMenu(),
          const SizedBox(height: 20),
          _buildAnotacoes(),
        ],
      ),
    );
  }

  Widget _buildFrequencia() {
    final hoje = DateTime.now();

    // Dias dos últimos 7 (incluindo hoje)
    final dias = List.generate(7, (i) {
      final d = hoje.subtract(Duration(days: 6 - i));
      return d;
    });

    // Datas em que houve execução
    final datasExec = _execucoes.map((e) {
      final dt = DateTime.parse(e['executado_em']).toLocal();
      return '${dt.year}-${dt.month}-${dt.day}';
    }).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Frequência de Treinos',
            style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (i) {
              final dia = dias[i];
              final chave = '${dia.year}-${dia.month}-${dia.day}';
              final feitoNoDia = datasExec.contains(chave);
              final ehHoje = i == 6;
              final ehFuturo = dia.isAfter(hoje);

              Color circleBg;
              Color circleBorder;
              Widget circleFill;

              if (feitoNoDia) {
                circleBg = AppColors.active.withValues(alpha: 0.15);
                circleBorder = AppColors.active;
                circleFill = const Icon(Icons.check_rounded, color: AppColors.active, size: 16);
              } else if (ehHoje) {
                circleBg = AppColors.primary.withValues(alpha: 0.1);
                circleBorder = AppColors.primary;
                circleFill = const Icon(Icons.circle, color: AppColors.primary, size: 8);
              } else if (!ehFuturo) {
                circleBg = AppColors.error.withValues(alpha: 0.08);
                circleBorder = AppColors.error.withValues(alpha: 0.4);
                circleFill = Icon(Icons.close_rounded,
                    color: AppColors.error.withValues(alpha: 0.6), size: 16);
              } else {
                circleBg = Colors.transparent;
                circleBorder = AppColors.divider;
                circleFill = const SizedBox();
              }

              // weekday: Mon=1..Sun=7 → map to D S T Q Q S S
              const semana = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
              final labelDia = semana[dia.weekday % 7];

              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: circleBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: circleBorder, width: 1.5),
                    ),
                    child: Center(child: circleFill),
                  ),
                  const SizedBox(height: 6),
                  Text(labelDia,
                      style: TextStyle(
                          color: feitoNoDia ? AppColors.active : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: feitoNoDia ? FontWeight.w700 : FontWeight.w400)),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMenu() {
    final itens = [
      _MenuItem(
        icon: Icons.fitness_center_rounded,
        label: 'Treinos',
        subtitulo: '${_fichas.length} ficha${_fichas.length != 1 ? 's' : ''} ativa${_fichas.length != 1 ? 's' : ''}',
        onTap: () => _verTreinos(),
      ),
      _MenuItem(
        icon: Icons.auto_graph_rounded,
        label: 'Progresso do aluno',
        subtitulo: '${_fotos.length} foto${_fotos.length != 1 ? 's' : ''} registrada${_fotos.length != 1 ? 's' : ''}',
        onTap: () => _verProgresso(),
      ),
      _MenuItem(
        icon: Icons.folder_outlined,
        label: 'Arquivos',
        subtitulo: '${_arquivos.length} arquivo${_arquivos.length != 1 ? 's' : ''}',
        onTap: () => _verArquivos(),
      ),
      _MenuItem(
        icon: Icons.assignment_outlined,
        label: 'Avaliações',
        subtitulo: 'Morfológica, Neuromotores, Postural, Anamnese',
        onTap: () => context.push('/alunos/avaliacao', extra: _aluno),
      ),
    ];

    return Column(
      children: itens.map((item) => _buildMenuItem(item)).toList(),
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    final disabled = item.onTap == null;
    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: disabled
                    ? AppColors.divider
                    : AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon,
                  color: disabled ? AppColors.textHint : AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label,
                      style: TextStyle(
                          color: disabled ? AppColors.textHint : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(item.subtitulo,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            if (!disabled)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAnotacoes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Anotações',
            style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: _notasCtrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText: 'Observações sobre o aluno, objetivos, restrições...',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _salvandoNota ? null : _salvarNota,
            child: _salvandoNota
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Salvar anotação'),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────── ABA OPÇÕES ────────────────────────────

  Widget _buildOpcoes() {
    final ativo = _aluno['ativo'] as bool? ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildOpcaoTile(
            icon: Icons.edit_outlined,
            label: 'Editar dados do aluno',
            color: AppColors.primary,
            onTap: () async {
              await context.push('/alunos/adicionar');
              _carregar();
            },
          ),
          const SizedBox(height: 10),
          _buildOpcaoTile(
            icon: ativo ? Icons.block_rounded : Icons.check_circle_outline_rounded,
            label: ativo ? 'Inativar aluno' : 'Reativar aluno',
            color: ativo ? AppColors.inactive : AppColors.active,
            onTap: _toggleStatus,
          ),
          const SizedBox(height: 10),
          _buildOpcaoTile(
            icon: Icons.delete_outline_rounded,
            label: 'Excluir aluno',
            color: AppColors.error,
            onTap: _excluir,
          ),
        ],
      ),
    );
  }

  Widget _buildOpcaoTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right, color: color.withValues(alpha: 0.6), size: 20),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────── NAVEGAÇÃO ────────────────────────────

  void _verTreinos() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _FichasSheet(fichas: _fichas),
    );
  }

  void _verArquivos() {
    context.push(
      '/alunos/arquivos',
      extra: {'alunoId': _aluno['id'].toString(), 'alunoNome': _aluno['nome'] ?? ''},
    );
  }

  void _verProgresso() {
    if (_fotos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este aluno ainda não tem fotos de progresso.'),
          backgroundColor: AppColors.surface,
        ),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProgressoSheet(fotos: _fotos),
    );
  }
}

// ──────────────────────────── HELPERS ────────────────────────────

class _MenuItem {
  final IconData icon;
  final String label;
  final String subtitulo;
  final VoidCallback? onTap;
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.subtitulo,
    required this.onTap,
  });
}

// Sheet de fichas do aluno
class _FichasSheet extends StatelessWidget {
  final List<Map<String, dynamic>> fichas;
  const _FichasSheet({required this.fichas});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Treinos do aluno',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: fichas.isEmpty
                  ? const Center(
                      child: Text('Nenhuma ficha atribuída.',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      controller: ctrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: fichas.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final f = fichas[i]['fichas'] as Map<String, dynamic>? ?? fichas[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.divider, width: 0.5),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.fitness_center_rounded,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f['nome'] ?? '',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14)),
                                    if (f['descricao'] != null &&
                                        (f['descricao'] as String).isNotEmpty)
                                      Text(f['descricao'],
                                          style: const TextStyle(
                                              color: AppColors.textSecondary,
                                              fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// Sheet de progresso do aluno (read-only)
class _ProgressoSheet extends StatelessWidget {
  final List<Map<String, dynamic>> fotos;
  const _ProgressoSheet({required this.fotos});

  static const _meses = [
    'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
    'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez',
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Progresso do aluno',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: fotos.length,
                itemBuilder: (_, i) {
                  final foto = fotos[i];
                  final dt = DateTime.parse(foto['registrado_em']).toLocal();
                  final data = '${dt.day} ${_meses[dt.month - 1]} ${dt.year}';
                  return GestureDetector(
                    onTap: () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.black,
                        insetPadding: EdgeInsets.zero,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: SizedBox.expand(
                            child: InteractiveViewer(
                              child: Image.network(foto['foto_url'],
                                  fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(foto['foto_url'], fit: BoxFit.cover),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.8),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                              child: Text(data,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
