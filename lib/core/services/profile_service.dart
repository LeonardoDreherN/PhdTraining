import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileService {
  static final _db = Supabase.instance.client;

  static Future<Map<String, dynamic>?> getPerfil() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    return await _db.from('profiles').select().eq('id', user.id).maybeSingle();
  }

  static Future<String?> getRole() async {
    final perfil = await getPerfil();
    return perfil?['role'] as String?;
  }

  static Future<void> atualizar(Map<String, dynamic> dados) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db.from('profiles').update(dados).eq('id', user.id);
  }

  static Future<String?> uploadAvatar(String nomeArquivo, Uint8List bytes) async {
    final userId = _db.auth.currentUser!.id;
    final ext = nomeArquivo.contains('.') ? nomeArquivo.split('.').last.toLowerCase() : 'jpg';
    final filePath = '$userId/avatar.$ext';
    await _db.storage.from('avatars').uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'),
    );
    return _db.storage.from('avatars').getPublicUrl(filePath);
  }
}
