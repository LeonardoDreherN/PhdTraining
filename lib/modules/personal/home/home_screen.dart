import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import 'widgets/home_header.dart';
import 'widgets/alunos_section.dart';
import 'widgets/treinos_grid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInicioTab(),
          const Center(child: Text('Finanças — em breve', style: TextStyle(color: AppColors.textSecondary))),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(110),
      child: Container(
        color: AppColors.background,
        child: SafeArea(
          child: Column(
            children: [
              const HomeHeader(),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: AppStrings.inicio),
                  Tab(text: AppStrings.financas),
                ],
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w400),
                indicatorColor: AppColors.primary,
                indicatorWeight: 2.5,
                labelColor: AppColors.textPrimary,
                unselectedLabelColor: AppColors.textSecondary,
                dividerColor: AppColors.divider,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInicioTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildActionButtons(),
          const SizedBox(height: 24),
          const AlunosSection(),
          const SizedBox(height: 24),
          _buildTreinosSection(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => context.push('/alunos/adicionar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: const Text(AppStrings.cadastrarAluno),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.black,
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            child: const Text(AppStrings.linkDeCadastro),
          ),
        ),
      ],
    );
  }

  Widget _buildTreinosSection() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.treinos,
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12),
        TreinosGrid(),
      ],
    );
  }
}
