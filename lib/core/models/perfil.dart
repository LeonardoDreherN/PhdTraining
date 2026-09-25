/// O perfil de quem está logado.
///
/// Primeiro model tipado do app. Até aqui tudo circulava como
/// `Map<String, dynamic>`, o que significa que um erro de digitação em
/// `perfil['avatr_url']` só aparecia como tela em branco em produção — e
/// nunca no `flutter analyze`.
class Perfil {
  const Perfil({
    required this.id,
    required this.role,
    this.nome,
    this.email,
    this.avatarUrl,
    this.whatsapp,
    this.cref,
    this.marcaNome,
    this.marcaLogoUrl,
    this.marcaCor = '#D7FF3E',
    this.onboardingEtapa = 'conta',
    this.isPlatformAdmin = false,
  });

  final String id;
  final String role;
  final String? nome;
  final String? email;
  final String? avatarUrl;
  final String? whatsapp;
  final String? cref;

  /// Marca que o ALUNO enxerga. O painel do personal usa sempre a da
  /// plataforma.
  final String? marcaNome;
  final String? marcaLogoUrl;
  final String marcaCor;

  final String onboardingEtapa;
  final bool isPlatformAdmin;

  bool get ehPersonal => role == 'personal';

  /// Primeiro nome, para a saudação. Cai em 'Treinador' em vez de string
  /// vazia porque o cadastro pelo painel do Supabase não preenche o nome.
  String get primeiroNome {
    final n = nome?.trim() ?? '';
    if (n.isEmpty) return 'Treinador';
    return n.split(RegExp(r'\s+')).first;
  }

  String get nomeExibicao {
    final n = nome?.trim() ?? '';
    return n.isEmpty ? (email ?? 'Sem nome') : n;
  }

  factory Perfil.doMapa(Map<String, dynamic> m) => Perfil(
        id: m['id'] as String,
        role: m['role'] as String? ?? 'personal',
        nome: m['nome'] as String?,
        email: m['email'] as String?,
        avatarUrl: m['avatar_url'] as String?,
        whatsapp: m['whatsapp'] as String?,
        cref: m['cref'] as String?,
        marcaNome: m['marca_nome'] as String?,
        marcaLogoUrl: m['marca_logo_url'] as String?,
        marcaCor: m['marca_cor'] as String? ?? '#D7FF3E',
        onboardingEtapa: m['onboarding_etapa'] as String? ?? 'conta',
        isPlatformAdmin: m['is_platform_admin'] as bool? ?? false,
      );
}
