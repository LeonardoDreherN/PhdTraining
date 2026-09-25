/// Credenciais do Supabase.
///
/// A anon key é feita para ficar no cliente — ela vai dentro do bundle e
/// qualquer pessoa consegue extraí-la do app ou do DevTools. O que protege
/// os dados não é escondê-la, é o RLS. Enquanto as policies de
/// `supabase/migrations/` estiverem aplicadas, essa chave sozinha não abre
/// nada que o usuário logado já não pudesse ver.
///
/// A `service_role` NUNCA entra aqui. Ela ignora RLS por definição e só
/// pertence a Edge Functions, onde o código não é servido ao cliente.
///
/// Os valores podem ser sobrescritos no build sem editar este arquivo:
///   flutter build web --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
abstract class SupabaseConfig {
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://vbfycvzmpfhgsmbfohqc.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZiZnljdnptcGZoZ3NtYmZvaHFjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MzAzMDEsImV4cCI6MjA5MDIwNjMwMX0.LvvKBqzPqML5AdgXmT4qN1Jkqvbhyt3uKwMPcVUh5YM',
  );
}
