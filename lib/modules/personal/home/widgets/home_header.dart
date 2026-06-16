import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/profile_service.dart';
import 'phd_logo.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key});

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  Map<String, dynamic>? _perfil;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await ProfileService.getPerfil();
    if (mounted) setState(() => _perfil = p);
  }

  String _saudacao() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom Dia';
    if (h < 18) return 'Boa Tarde';
    return 'Boa Noite';
  }

  @override
  Widget build(BuildContext context) {
    final nome = _perfil?['nome'] as String? ?? 'Pedro Henrique';
    final primeiroNome = nome.split(' ').first;
    final avatarUrl = _perfil?['avatar_url'] as String?;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _buildAvatar(nome.isNotEmpty ? nome[0].toUpperCase() : 'P', avatarUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${_saudacao()}, $primeiroNome',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const PHDLogo(fontSize: 28),
        ],
      ),
    );
  }

  Widget _buildAvatar(String inicial, String? url) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surface,
        border: Border.all(color: AppColors.divider, width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => _initials(inicial),
              errorWidget: (_, __, ___) => _initials(inicial),
            )
          : _initials(inicial),
    );
  }

  Widget _initials(String inicial) {
    return Center(
      child: Text(inicial,
          style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16)),
    );
  }
}
