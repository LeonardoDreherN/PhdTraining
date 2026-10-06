import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/midia.dart';

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
    // Sem o `select`, um update barrado pelo RLS (ou sem linha em profiles)
    // volta sem erro e sem alterar nada — a tela dizia "salvo" e não salvava.
    final linhas =
        await _db.from('profiles').update(dados).eq('id', user.id).select('id');
    if (linhas.isEmpty) {
      throw Exception('Seu perfil não foi encontrado para atualizar.');
    }
  }

  static Future<String?> uploadAvatar(String nomeArquivo, Uint8List bytes) async {
    final userId = _db.auth.currentUser!.id;
    final tipo = Midia.tipoDe(nomeArquivo);
    if (tipo == null || !tipo.startsWith('image/')) {
      throw Exception(Midia.recusa(nomeArquivo, video: false));
    }
    final ext = Midia.extensaoDe(nomeArquivo);
    final filePath = '$userId/avatar.$ext';
    await _db.storage.from('avatars').uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(upsert: true, contentType: tipo),
    );
    // O caminho é sempre o mesmo, então a URL também seria: o navegador, o
    // CachedNetworkImage e o CDN do Supabase continuavam mostrando a foto
    // antiga. O `v` muda a cada envio e força a imagem nova.
    final url = _db.storage.from('avatars').getPublicUrl(filePath);
    return '$url?v=${DateTime.now().millisecondsSinceEpoch}';
  }
}
