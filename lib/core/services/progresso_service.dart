import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressoService {
  static final _db = Supabase.instance.client;

  static Future<String?> getAlunoId() async {
    final user = _db.auth.currentUser;
    if (user == null) return null;
    final aluno = await _db
        .from('alunos')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();
    return aluno?['id']?.toString();
  }

  static Future<List<Map<String, dynamic>>> listarFotos(String alunoId) async {
    return await _db
        .from('fotos_progresso')
        .select()
        .eq('aluno_id', alunoId)
        .order('registrado_em', ascending: false);
  }

  static Future<void> adicionarFoto({
    required String alunoId,
    required XFile foto,
    double? pesoKg,
    String? observacoes,
  }) async {
    final bytes = await foto.readAsBytes();
    final ext = foto.path.split('.').last.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
    final fileName = '${alunoId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from('progresso-fotos').uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );

    final url = _db.storage.from('progresso-fotos').getPublicUrl(fileName);

    await _db.from('fotos_progresso').insert({
      'aluno_id': alunoId,
      'foto_url': url,
      'peso_kg': pesoKg,
      'observacoes': observacoes,
    });
  }
}
