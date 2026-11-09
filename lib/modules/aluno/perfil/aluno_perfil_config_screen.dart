import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/widgets.dart';
import '../../../core/services/profile_service.dart';
import '../../../core/services/auth_service.dart';

class AlunoPerfilConfigScreen extends StatefulWidget {
  const AlunoPerfilConfigScreen({super.key, this.emAba = false});

  /// Aberta como aba do menu do aluno: sem seta de voltar, porque não há
  /// para onde voltar — a navegação é pela barra de baixo.
  final bool emAba;

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
    final nome = _aluno?['nome'] as String? ?? _perfil?['nome'] as String? ?? '—';
    final email = _db.auth.currentUser?.email;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: widget.emAba
          ? null
          : AppBar(
              backgroundColor: AppColors.bg,
              surfaceTintColor: Colors.transparent,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
      body: SafeArea(
        child: _carregando
            ? Center(child: CircularProgressIndicator(color: AppColors.accent))
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.huge),
                children: [
                  Text('PERFIL', style: AppText.label()),
                  const SizedBox(height: AppSpacing.lg),
                  PhdCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        _buildFoto(),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nome, style: AppText.display(20)),
                              if (email != null) ...[
                                const SizedBox(height: 2),
                                Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(13)),
                              ],
                              const SizedBox(height: AppSpacing.sm),
                              GestureDetector(
                                onTap: _uploadando ? null : _uploadFoto,
                                child: Text(
                                  _uploadando ? 'Enviando foto…' : 'Trocar foto',
                                  style: AppText.bodyStrong(13, color: AppColors.accent),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_aluno != null) ...[
                    const SizedBox(height: AppSpacing.xxl),
                    const PhdSectionHeader(label: 'Seus dados'),
                    const SizedBox(height: AppSpacing.md),
                    PhdCard(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Column(
                        children: [
                          for (final (i, (rotulo, valor)) in [
                            if (_aluno!['data_nascimento'] != null)
                              ('Nascimento', _fmtData(_aluno!['data_nascimento'] as String)),
                            if (_aluno!['genero'] != null) ('Gênero', _aluno!['genero'] as String),
                            if (_aluno!['whatsapp'] != null) ('WhatsApp', _aluno!['whatsapp'] as String),
                          ].indexed) ...[
                            if (i > 0) Divider(height: 1, color: AppColors.line),
                            _infoLinha(rotulo, valor),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('Para mudar algum dado, fale com seu personal.', style: AppText.caption(12.5)),
                  ],
                  const SizedBox(height: AppSpacing.xxl),
                  const PhdSectionHeader(label: 'Aparência'),
                  const SizedBox(height: AppSpacing.md),
                  const PhdSeletorTema(),
                  const SizedBox(height: AppSpacing.xxl),
                  const PhdSectionHeader(label: 'Conta'),
                  const SizedBox(height: AppSpacing.md),
                  PhdButton(
                    label: 'Sair da conta',
                    icon: Icons.logout_rounded,
                    variant: PhdButtonVariant.ghost,
                    onPressed: _logout,
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
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent, width: 2),
            ),
            padding: const EdgeInsets.all(3),
            child: ClipOval(
              // `Image.network` em vez de `CachedNetworkImage`: no web o cache
              // dele busca por XHR e falhava na releitura, deixando a foto
              // "preta" (o placeholder escuro).
              child: url != null
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, filho, progresso) => progresso == null ? filho : const _PlaceholderIcon(),
                      errorBuilder: (_, __, ___) => const _PlaceholderIcon(),
                    )
                  : const _PlaceholderIcon(),
            ),
          ),
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 2),
            ),
            child: _uploadando
                ? Padding(
                    padding: const EdgeInsets.all(5),
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onAccent),
                  )
                : Icon(Icons.photo_camera_rounded, color: AppColors.onAccent, size: 13),
          ),
        ],
      ),
    );
  }

  Widget _infoLinha(String rotulo, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(child: Text(rotulo, style: AppText.body(14, color: AppColors.textSecondary))),
            Text(valor, style: AppText.bodyStrong(14)),
          ],
        ),
      );

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
      color: AppColors.surfaceHigh,
      child: Icon(Icons.person_rounded, color: AppColors.textMuted, size: 36),
    );
  }
}
