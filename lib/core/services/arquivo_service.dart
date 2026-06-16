import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ArquivoService {
  static final _db = Supabase.instance.client;
  static const _bucket = 'aluno-arquivos';

  static Future<List<Map<String, dynamic>>> listar(String alunoId) async {
    return await _db
        .from('aluno_arquivos')
        .select()
        .eq('aluno_id', alunoId)
        .order('criado_em', ascending: false);
  }

  static Future<void> adicionar({
    required String alunoId,
    required PlatformFile arquivo,
  }) async {
    final bytes = arquivo.bytes!;
    final ext = arquivo.extension ?? 'bin';
    final nome = arquivo.name;
    final fileName =
        '${alunoId}_${DateTime.now().millisecondsSinceEpoch}_$nome';

    await _db.storage.from(_bucket).uploadBinary(
      fileName,
      bytes,
      fileOptions: FileOptions(
        contentType: _contentType(ext),
        upsert: false,
      ),
    );

    final url = _db.storage.from(_bucket).getPublicUrl(fileName);

    await _db.from('aluno_arquivos').insert({
      'aluno_id': alunoId,
      'personal_id': _db.auth.currentUser!.id,
      'nome': nome,
      'arquivo_url': url,
      'tipo_mime': _contentType(ext),
      'tamanho_bytes': arquivo.size,
    });
  }

  static Future<void> deletar(String id, String arquivoUrl) async {
    // Extrai o nome do arquivo da URL para deletar do storage
    final uri = Uri.parse(arquivoUrl);
    final pathSegments = uri.pathSegments;
    // URL format: .../storage/v1/object/public/aluno-arquivos/<filename>
    final bucketIndex = pathSegments.indexOf(_bucket);
    if (bucketIndex != -1 && bucketIndex + 1 < pathSegments.length) {
      final fileName =
          pathSegments.sublist(bucketIndex + 1).join('/');
      await _db.storage.from(_bucket).remove([fileName]);
    }
    await _db.from('aluno_arquivos').delete().eq('id', id);
  }

  static String _contentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }
}
