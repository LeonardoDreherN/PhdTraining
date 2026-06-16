import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/ficha_service.dart';
import '../../../core/services/exercicio_service.dart';
import '../../../core/services/aluno_service.dart';

class FichaDetalheScreen extends StatefulWidget {
  final Map<String, dynamic> ficha;
  const FichaDetalheScreen({super.key, required this.ficha});

  @override
  State<FichaDetalheScreen> createState() => _FichaDetalheScreenState();
}

class _FichaDetalheScreenState extends State<FichaDetalheScreen> {
  List<Map<String, dynamic>> _exercicios = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    if (!mounted) return;
    setState(() => _carregando = true);
    try {
      final lista = await FichaService.listarExercicios(widget.ficha['id']);
      if (mounted) setState(() => _exercicios = lista);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.ficha['nome']),
        actions: [
          TextButton.icon(
            onPressed: _atribuirAluno,
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Atribuir'),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                Expanded(child: _exercicios.isEmpty ? _buildVazio() : _buildLista()),
                _buildBotaoAdicionar(),
              ],
            ),
    );
  }

  Widget _buildLista() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exercicios.length,
      onReorderItem: (oldIndex, newIndex) async {
        setState(() {
          final item = _exercicios.removeAt(oldIndex);
          _exercicios.insert(newIndex, item);
        });
        for (var i = 0; i < _exercicios.length; i++) {
          await FichaService.atualizarExercicio(_exercicios[i]['id'], {'ordem': i});
        }
      },
      itemBuilder: (_, i) => _buildCard(_exercicios[i], i),
    );
  }

  Widget _buildCard(Map<String, dynamic> item, int index) {
    final ex = item['exercicios'] as Map<String, dynamic>;
    return Container(
      key: ValueKey(item['id']),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha:0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ex['midia_url'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(ex['midia_url'], fit: BoxFit.cover),
                  )
                : const Icon(Icons.fitness_center, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ex['nome'], style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildChip('${item['series']}x', Icons.repeat),
                    const SizedBox(width: 6),
                    _buildChip(item['repeticoes'] ?? '-', Icons.numbers),
                    if (item['carga'] != null && item['carga'].toString().isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _buildChip('${item['carga']}kg', Icons.monitor_weight_outlined),
                    ],
                    if (item['descanso_segundos'] != null) ...[
                      const SizedBox(width: 6),
                      _buildChip('${item['descanso_segundos']}s', Icons.timer_outlined),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
            onPressed: () async {
              try {
                await FichaService.removerExercicio(item['id']);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erro ao remover: $e'), backgroundColor: AppColors.error),
                  );
                }
                return;
              }
              if (mounted) _carregar();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildVazio() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add, color: AppColors.textHint, size: 64),
          SizedBox(height: 16),
          Text('Nenhum exercício nesta ficha', style: TextStyle(color: AppColors.textSecondary)),
          SizedBox(height: 8),
          Text('Toque em "Adicionar Exercício" abaixo', style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBotaoAdicionar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: ElevatedButton.icon(
        onPressed: _adicionarExercicio,
        icon: const Icon(Icons.add),
        label: const Text('Adicionar Exercício'),
      ),
    );
  }

  Future<void> _adicionarExercicio() async {
    final exercicios = await ExercicioService.listar();
    if (!mounted) return;

    final selecionado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ExercicioPickerSheet(exercicios: exercicios),
    );

    if (selecionado == null || !mounted) return;

    await _showConfigExercicio(selecionado);
  }

  Future<void> _showConfigExercicio(Map<String, dynamic> exercicio) async {
    final seriesCtrl = TextEditingController(text: '3');
    final repsCtrl = TextEditingController(text: '12');
    final cargaCtrl = TextEditingController();
    final descansoCtrl = TextEditingController(text: '60');

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(exercicio['nome'], style: const TextStyle(color: AppColors.textPrimary, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(child: _dialogField(seriesCtrl, 'Séries', TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _dialogField(repsCtrl, 'Reps', TextInputType.text)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _dialogField(cargaCtrl, 'Carga (kg)', TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: _dialogField(descansoCtrl, 'Descanso (s)', TextInputType.number)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Adicionar', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      await FichaService.adicionarExercicio(
        fichaId: widget.ficha['id'],
        exercicioId: exercicio['id'],
        series: int.tryParse(seriesCtrl.text) ?? 3,
        repeticoes: repsCtrl.text,
        carga: cargaCtrl.text.isNotEmpty ? cargaCtrl.text : null,
        descansoSegundos: int.tryParse(descansoCtrl.text),
        ordem: _exercicios.length,
      );
      if (mounted) _carregar();
    }
  }

  Widget _dialogField(TextEditingController ctrl, String hint, TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(hintText: hint),
    );
  }

  Future<void> _atribuirAluno() async {
    final alunos = await AlunoService.listar(ativo: true);
    if (!mounted) return;

    final selecionado = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AlunoPickerSheet(alunos: alunos),
    );
    if (selecionado == null || !mounted) return;

    // Seleção de dias
    final dias = await showModalBottomSheet<List<int>>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _DiasSemanaPickerSheet(),
    );
    if (!mounted) return;

    await FichaService.atribuirAluno(
      alunoId: selecionado['id'],
      fichaId: widget.ficha['id'],
      diasSemana: dias ?? [],
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ficha atribuída para ${selecionado['nome']}!'),
          backgroundColor: AppColors.active,
        ),
      );
    }
  }
}

class _ExercicioPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> exercicios;
  const _ExercicioPickerSheet({required this.exercicios});

  @override
  State<_ExercicioPickerSheet> createState() => _ExercicioPickerSheetState();
}

class _ExercicioPickerSheetState extends State<_ExercicioPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _busca = '';
  String _grupo = 'Todos';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtrados {
    return widget.exercicios.where((ex) {
      final nomeOk = _busca.isEmpty ||
          (ex['nome'] as String).toLowerCase().contains(_busca.toLowerCase());
      final grupoOk = _grupo == 'Todos' || ex['grupo_muscular'] == _grupo;
      return nomeOk && grupoOk;
    }).toList();
  }

  List<String> get _grupos {
    final set = <String>{};
    for (final ex in widget.exercicios) {
      if (ex['grupo_muscular'] != null) set.add(ex['grupo_muscular'] as String);
    }
    final sorted = set.toList()..sort();
    return ['Todos', ...sorted];
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtrados;
    return Column(
      children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Título
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Text('Selecione um exercício',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
        ),
        // Campo de busca
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            autofocus: false,
            onChanged: (v) => setState(() => _busca = v),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Buscar exercício...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
              suffixIcon: _busca.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        setState(() => _busca = '');
                      },
                      child: const Icon(Icons.close, color: AppColors.textSecondary, size: 18),
                    )
                  : null,
            ),
          ),
        ),
        // Filtro por grupo
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _grupos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final g = _grupos[i];
              final sel = g == _grupo;
              return GestureDetector(
                onTap: () => setState(() => _grupo = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    g,
                    style: TextStyle(
                      color: sel ? Colors.black : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        const Divider(color: AppColors.divider, height: 1),
        // Lista
        Expanded(
          child: lista.isEmpty
              ? const Center(
                  child: Text('Nenhum exercício encontrado',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                )
              : ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(color: AppColors.divider, height: 1),
                  itemBuilder: (context, i) {
                    final ex = lista[i];
                    return ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ex['midia_url'] != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(ex['midia_url'], fit: BoxFit.cover),
                              )
                            : const Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
                      ),
                      title: Text(ex['nome'],
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                      subtitle: ex['grupo_muscular'] != null
                          ? Text(ex['grupo_muscular'],
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
                          : null,
                      onTap: () => Navigator.pop(context, ex),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _DiasSemanaPickerSheet extends StatefulWidget {
  const _DiasSemanaPickerSheet();

  @override
  State<_DiasSemanaPickerSheet> createState() => _DiasSemanaPickerSheetState();
}

class _DiasSemanaPickerSheetState extends State<_DiasSemanaPickerSheet> {
  final Set<int> _selecionados = {};

  static const _dias = [
    {'label': 'D', 'nome': 'Dom', 'value': 0},
    {'label': 'S', 'nome': 'Seg', 'value': 1},
    {'label': 'T', 'nome': 'Ter', 'value': 2},
    {'label': 'Q', 'nome': 'Qua', 'value': 3},
    {'label': 'Q', 'nome': 'Qui', 'value': 4},
    {'label': 'S', 'nome': 'Sex', 'value': 5},
    {'label': 'S', 'nome': 'Sáb', 'value': 6},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Dias da semana',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 18),
          ),
          const SizedBox(height: 6),
          const Text(
            'Em quais dias o aluno fará este treino?',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _dias.map((dia) {
              final val = dia['value'] as int;
              final selected = _selecionados.contains(val);
              return GestureDetector(
                onTap: () => setState(() {
                  selected ? _selecionados.remove(val) : _selecionados.add(val);
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.divider,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dia['label'] as String,
                        style: TextStyle(
                          color: selected ? Colors.black : AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _dias.map((dia) => SizedBox(
              width: 42,
              child: Text(
                dia['nome'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textHint, fontSize: 10),
              ),
            )).toList(),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _selecionados.toList()..sort()),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            child: const Text('Confirmar'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context, <int>[]),
            child: const Text('Pular', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _AlunoPickerSheet extends StatelessWidget {
  final List<Map<String, dynamic>> alunos;
  const _AlunoPickerSheet({required this.alunos});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Atribuir para qual aluno?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        const Divider(color: AppColors.divider, height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: alunos.length,
            separatorBuilder: (_, __) => const Divider(color: AppColors.divider, height: 1),
            itemBuilder: (context, i) {
              final aluno = alunos[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha:0.15),
                  child: Text(aluno['nome'].toString()[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
                title: Text(aluno['nome'], style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                subtitle: Text(aluno['grupo'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                onTap: () => Navigator.pop(context, aluno),
              );
            },
          ),
        ),
      ],
    );
  }
}
