import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/auth_service.dart';

class AlunoPerfilConfigScreen extends StatefulWidget {
  const AlunoPerfilConfigScreen({super.key});

  @override
  State<AlunoPerfilConfigScreen> createState() =>
      _AlunoPerfilConfigScreenState();
}

class _AlunoPerfilConfigScreenState extends State<AlunoPerfilConfigScreen> {
  final _db = Supabase.instance.client;
  Map<String, dynamic>? _perfil;
  Map<String, dynamic>? _aluno;
  bool _carregando = true;
  bool _uploadando = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    final resultados = await Future.wait([
      ProfileService.getPerfil(),
      _db.from('alunos').select().eq('user_id', user.id).maybeSingle(),
    ]);
    if (mounted) {
      setState(() {
        _perfil = resultados[0];
        _aluno = resultados[1];
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
        // Espelha em `alunos.foto_url` para o personal ver na lista. Vai por
        // função porque a policy de escrita de `alunos` é só do personal: o
        // update direto era recusado sem erro, e a foto nunca chegava lá.
        await _db.rpc('definir_minha_foto', params: {'p_url': url});
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

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Meu Perfil',
            style: GoogleFonts.montserrat(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
      ),
      body: _carregando
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: _buildFoto()),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _aluno?['nome'] as String? ??
                          _perfil?['nome'] as String? ??
                          '—',
                      style: GoogleFonts.montserrat(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _db.auth.currentUser?.email ?? '—',
                      style: GoogleFonts.montserrat(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_aluno != null) ...[
                    _rotulo('INFORMAÇÕES'),
                    const SizedBox(height: 10),
                    if (_aluno!['data_nascimento'] != null)
                      _infoCard('Data de nascimento',
                          _fmtData(_aluno!['data_nascimento'] as String)),
                    if (_aluno!['genero'] != null) ...[
                      const SizedBox(height: 6),
                      _infoCard('Gênero', _aluno!['genero'] as String),
                    ],
                    if (_aluno!['whatsapp'] != null) ...[
                      const SizedBox(height: 6),
                      _infoCard('WhatsApp', _aluno!['whatsapp'] as String),
                    ],
                    const SizedBox(height: 28),
                  ],
                  _rotulo('APARÊNCIA'),
                  const SizedBox(height: 10),
                  const PhdSeletorTema(),
                  const SizedBox(height: 28),
                  _rotulo('CONTA'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: Icon(Icons.logout,
                          color: AppColors.error, size: 18),
                      label: Text('Sair',
                          style: GoogleFonts.montserrat(
                              color: AppColors.error,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.error.withValues(alpha: 0.3),
                            width: 0.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
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
            // `Image.network` em vez de `CachedNetworkImage`: no web o cache
            // dele busca por XHR e falhava na releitura, deixando a foto
            // "preta" (o placeholder escuro).
            child: url != null
                ? Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: 96,
                    height: 96,
                    loadingBuilder: (_, filho, progresso) =>
                        progresso == null ? filho : const _PlaceholderIcon(),
                    errorBuilder: (_, __, ___) => const _PlaceholderIcon(),
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
                ? Padding(
                    padding: const EdgeInsets.all(5),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.onAccent),
                  )
                : Icon(Icons.camera_alt, color: AppColors.onAccent, size: 15),
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

  Widget _infoCard(String label, String valor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.montserrat(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(valor,
              style: GoogleFonts.montserrat(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _fmtData(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _PlaceholderIcon extends StatelessWidget {
  const _PlaceholderIcon();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Icon(Icons.person, color: AppColors.textSecondary, size: 46),
    );
  }
}
