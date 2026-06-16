import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/auth_service.dart';

class PersonalPerfilScreen extends StatefulWidget {
  const PersonalPerfilScreen({super.key});

  @override
  State<PersonalPerfilScreen> createState() => _PersonalPerfilScreenState();
}

class _PersonalPerfilScreenState extends State<PersonalPerfilScreen> {
  final _nomeCtrl = TextEditingController();
  Map<String, dynamic>? _perfil;
  bool _carregando = true;
  bool _uploadando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    final p = await ProfileService.getPerfil();
    if (mounted) {
      setState(() {
        _perfil = p;
        _nomeCtrl.text = p?['nome'] as String? ?? '';
        _carregando = false;
      });
    }
  }

  Future<void> _uploadFoto() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 75, maxWidth: 512);
    if (img == null) return;
    setState(() => _uploadando = true);
    try {
      final bytes = await img.readAsBytes();
      final url = await ProfileService.uploadAvatar(img.name, bytes);
      if (url != null) {
        await ProfileService.atualizar({'avatar_url': url});
        await _carregar();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao enviar foto: $e')),
        );
      }
    }
    if (mounted) setState(() => _uploadando = false);
  }

  Future<void> _salvarNome() async {
    final nome = _nomeCtrl.text.trim();
    if (nome.isEmpty) return;
    await ProfileService.atualizar({'nome': nome});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome atualizado!')),
      );
    }
  }

  Future<void> _alterarSenha() async {
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';
    if (email.isEmpty) return;
    await AuthService.resetPassword(email);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de redefinição de senha enviado!')),
      );
    }
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _carregando
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: AppColors.background,
                  surfaceTintColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  title: Image.asset('assets/images/logo_white.png',
                      height: 34, fit: BoxFit.contain),
                  centerTitle: true,
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(child: _buildFoto()),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            _perfil?['nome'] as String? ?? '',
                            style: GoogleFonts.montserrat(
                                color: AppColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            Supabase.instance.client.auth.currentUser?.email ?? '',
                            style: GoogleFonts.montserrat(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 36),
                        _rotulo('DADOS PESSOAIS'),
                        const SizedBox(height: 10),
                        _buildCampo(_nomeCtrl, 'Nome'),
                        const SizedBox(height: 8),
                        _buildBotaoPrimario('Salvar nome', _salvarNome),
                        const SizedBox(height: 28),
                        _rotulo('CONTA'),
                        const SizedBox(height: 10),
                        _buildBotaoOutline(
                            'Alterar senha', Icons.lock_outline, _alterarSenha),
                        const SizedBox(height: 8),
                        _buildBotaoOutline(
                            'Sair', Icons.logout, _logout, danger: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFoto() {
    final url = _perfil?['avatar_url'] as String?;
    return GestureDetector(
      onTap: _uploadando ? null : _uploadFoto,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider, width: 1.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: url != null
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const _PlaceholderIcon(),
                    errorWidget: (_, __, ___) => const _PlaceholderIcon(),
                  )
                : const _PlaceholderIcon(),
          ),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.background, width: 2),
            ),
            child: _uploadando
                ? const Padding(
                    padding: EdgeInsets.all(5),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.camera_alt, color: Colors.black, size: 15),
          ),
        ],
      ),
    );
  }

  Widget _rotulo(String texto) {
    return Text(texto,
        style: GoogleFonts.montserrat(
            color: AppColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2));
  }

  Widget _buildCampo(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: GoogleFonts.montserrat(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            GoogleFonts.montserrat(color: AppColors.textSecondary, fontSize: 12),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.divider, width: 0.5)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildBotaoPrimario(String texto, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.black,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: Text(texto,
            style: GoogleFonts.montserrat(
                fontSize: 14, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBotaoOutline(String texto, IconData icon, VoidCallback onTap,
      {bool danger = false}) {
    final cor = danger ? AppColors.error : AppColors.textPrimary;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: cor, size: 18),
        label: Text(texto,
            style: GoogleFonts.montserrat(
                color: cor, fontSize: 14, fontWeight: FontWeight.w500)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: danger
                  ? AppColors.error.withValues(alpha: 0.3)
                  : AppColors.divider,
              width: 0.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: const Icon(Icons.person, color: AppColors.textSecondary, size: 46),
    );
  }
}
