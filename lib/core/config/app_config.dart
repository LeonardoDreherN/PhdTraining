/// Endereços do próprio app.
///
/// Vem de `--dart-define` como as chaves do Supabase, com o endereço de
/// produção como padrão: build sem a variável continua gerando link que
/// funciona, em vez de mandar o aluno para `localhost`.
abstract class AppConfig {
  static const String url = String.fromEnvironment(
    'APP_URL',
    defaultValue: 'https://phd-training.vercel.app',
  );

  /// Onde o aluno entra. O link vai na mensagem de boas-vindas junto das
  /// credenciais — sem ele, a pessoa recebe login e senha e não tem onde
  /// usar.
  static String get login => '$url/login';
}
