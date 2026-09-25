import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProgressoService {
  static final _db = Supabase.instance.client;
  static const _bucket = 'progresso-fotos';

  /// Validade da URL assinada. Uma hora cobre uma sessão de uso com folga;
  /// mais que isso só aumenta a janela de um link vazado.
  static const _validadeSegundos = 3600;

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

  /// Devolve as fotos com `foto_url` já pronta para exibir.
  ///
  /// O bucket é privado, então o banco guarda o CAMINHO do arquivo, não uma
  /// URL — URL assinada expira, e uma URL vencida gravada na linha seria
  /// inútil no dia seguinte. A assinatura acontece aqui, na leitura, e as
  /// telas continuam lendo `foto_url` sem saber da diferença.
  static Future<List<Map<String, dynamic>>> listarFotos(String alunoId) async {
    final linhas = await _db
        .from('fotos_progresso')
        .select()
        .eq('aluno_id', alunoId)
        .order('registrado_em', ascending: false);

    final fotos = List<Map<String, dynamic>>.from(linhas);
    if (fotos.isEmpty) return fotos;

    final caminhos = fotos
        .map((f) => f['foto_url'] as String?)
        .whereType<String>()
        .where((c) => c.isNotEmpty && !c.startsWith('http'))
        .toList();

    if (caminhos.isEmpty) return fotos;

    try {
      final assinadas = await _db.storage
          .from(_bucket)
          .createSignedUrls(caminhos, _validadeSegundos);

      final porCaminho = {for (final a in assinadas) a.path: a.signedUrl};

      for (final f in fotos) {
        final caminho = f['foto_url'] as String?;
        if (caminho != null && porCaminho.containsKey(caminho)) {
          f['foto_url'] = porCaminho[caminho];
        }
      }
    } catch (_) {
      // Assinar falhou: devolve as linhas mesmo assim, com o caminho cru.
      // A galeria mostra imagem quebrada, mas o peso e as observações —
      // que é o dado que importa — continuam aparecendo.
    }

    return fotos;
  }

  static Future<void> adicionarFoto({
    required String alunoId,
    required XFile foto,
    double? pesoKg,
    String? observacoes,
  }) async {
    final bytes = await foto.readAsBytes();
    // foto.name has the real filename on all platforms (web uses blob URLs in .path)
    final rawName = foto.name.isNotEmpty ? foto.name : foto.path;
    final ext = rawName.contains('.') ? rawName.split('.').last.toLowerCase() : 'jpg';
    final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';

    // A pasta É a permissão: a policy do bucket confere se o primeiro
    // segmento do caminho é um aluno que você pode ver. Nome achatado
    // (`alunoId_timestamp`) não dá para verificar.
    final caminho = '$alunoId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from(_bucket).uploadBinary(
      caminho,
      bytes,
      fileOptions: FileOptions(contentType: contentType, upsert: false),
    );

    await _db.from('fotos_progresso').insert({
      'aluno_id': alunoId,
      'foto_url': caminho,
      'peso_kg': pesoKg,
      'observacoes': observacoes,
    });
  }
}
