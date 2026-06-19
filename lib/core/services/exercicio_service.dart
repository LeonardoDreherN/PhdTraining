import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class ExercicioService {
  static final _db = Supabase.instance.client;
  static String get _personalId => _db.auth.currentUser!.id;

  static const List<String> grupos = [
    'Todos',
    'Peito',
    'Costas',
    'Ombro',
    'Bíceps',
    'Tríceps',
    'Pernas',
    'Glúteos',
    'Abdômen',
    'Cardio',
    'Funcional',
  ];

  static const List<Map<String, String>> _exerciciosPadrao = [
    // Peito
    {'nome': 'Supino Reto com Barra', 'grupo': 'Peito', 'descricao': 'Deite no banco, segure a barra na largura dos ombros, desça até o peito e empurre de volta.'},
    {'nome': 'Supino Inclinado com Barra', 'grupo': 'Peito', 'descricao': 'Banco a 30-45°, desça a barra até a parte superior do peito e empurre.'},
    {'nome': 'Supino Declinado com Barra', 'grupo': 'Peito', 'descricao': 'Banco declinado, enfatiza a parte inferior do peitoral.'},
    {'nome': 'Supino Reto com Halteres', 'grupo': 'Peito', 'descricao': 'Mesmo movimento do supino reto, permite maior amplitude de movimento.'},
    {'nome': 'Supino Inclinado com Halteres', 'grupo': 'Peito', 'descricao': 'Banco inclinado a 30-45°, trabalha a porção superior do peito.'},
    {'nome': 'Crucifixo Reto', 'grupo': 'Peito', 'descricao': 'Deite no banco, abra os braços com leve flexão e feche na linha do peito.'},
    {'nome': 'Crucifixo Inclinado', 'grupo': 'Peito', 'descricao': 'Banco inclinado, ênfase na porção superior do peitoral.'},
    {'nome': 'Crossover no Cabo', 'grupo': 'Peito', 'descricao': 'Puxe os cabos de cima para baixo e ao centro, contraindo o peitoral.'},
    {'nome': 'Peck Deck (Voador)', 'grupo': 'Peito', 'descricao': 'Máquina de peitoral. Feche os braços na frente do corpo contraindo o peito.'},
    {'nome': 'Flexão de Braço', 'grupo': 'Peito', 'descricao': 'Em posição de prancha, desça o peito ao chão e empurre de volta.'},
    {'nome': 'Pullover com Haltere', 'grupo': 'Peito', 'descricao': 'Deitado no banco, segure um haltere com as duas mãos e passe atrás da cabeça.'},
    // Costas
    {'nome': 'Puxada Frontal no Pulley', 'grupo': 'Costas', 'descricao': 'Puxe a barra até abaixo do queixo, cotovelos apontando para baixo.'},
    {'nome': 'Puxada Atrás no Pulley', 'grupo': 'Costas', 'descricao': 'Puxe a barra até a nuca, atenção para não forçar o pescoço.'},
    {'nome': 'Remada Curvada com Barra', 'grupo': 'Costas', 'descricao': 'Tronco inclinado a ~45°, puxe a barra até o abdômen contraindo o dorsal.'},
    {'nome': 'Remada Unilateral com Haltere', 'grupo': 'Costas', 'descricao': 'Apoie um joelho no banco, puxe o haltere até o quadril lateral.'},
    {'nome': 'Remada Sentada no Cabo', 'grupo': 'Costas', 'descricao': 'Sentado na polia baixa, puxe o triângulo até o abdômen mantendo o tronco ereto.'},
    {'nome': 'Levantamento Terra', 'grupo': 'Costas', 'descricao': 'Barra no chão, segure com pegada dupla pronada, levante mantendo a coluna reta.'},
    {'nome': 'Barra Fixa', 'grupo': 'Costas', 'descricao': 'Pegada supinada ou pronada, puxe o corpo até o queixo passar a barra.'},
    {'nome': 'Remada Alta com Barra', 'grupo': 'Costas', 'descricao': 'Pegada fechada, puxe a barra até a altura do queixo elevando os cotovelos.'},
    {'nome': 'Remada Fechada no Cabo', 'grupo': 'Costas', 'descricao': 'Polia baixa com triângulo, cotovelos colados ao corpo, contrai trapézio médio.'},
    {'nome': 'Hiperextensão Lombar', 'grupo': 'Costas', 'descricao': 'No banco romano, deça o tronco e suba até a posição neutra da coluna.'},
    // Ombro
    {'nome': 'Desenvolvimento com Barra', 'grupo': 'Ombro', 'descricao': 'Sentado ou em pé, empurre a barra do nível do queixo acima da cabeça.'},
    {'nome': 'Desenvolvimento com Halteres', 'grupo': 'Ombro', 'descricao': 'Halteres na altura dos ombros, empurre acima da cabeça.'},
    {'nome': 'Elevação Lateral com Halteres', 'grupo': 'Ombro', 'descricao': 'Eleve os halteres lateralmente até a altura dos ombros, leve flexão no cotovelo.'},
    {'nome': 'Elevação Frontal com Halteres', 'grupo': 'Ombro', 'descricao': 'Eleve os halteres à frente até a altura dos ombros, ação alternada ou simultânea.'},
    {'nome': 'Elevação Posterior com Halteres', 'grupo': 'Ombro', 'descricao': 'Inclinado, eleve os halteres para os lados trabalhando o deltóide posterior.'},
    {'nome': 'Desenvolvimento Arnold', 'grupo': 'Ombro', 'descricao': 'Inicia com palmas para dentro, rotaciona ao empurrar. Trabalha todos os feixes.'},
    {'nome': 'Encolhimento com Barra', 'grupo': 'Ombro', 'descricao': 'Eleve os ombros em direção às orelhas com a barra nas mãos. Trabalha trapézio.'},
    {'nome': 'Encolhimento com Halteres', 'grupo': 'Ombro', 'descricao': 'Mesmo movimento do encolhimento, usando halteres nas laterais.'},
    {'nome': 'Face Pull no Cabo', 'grupo': 'Ombro', 'descricao': 'Puxe a corda até o rosto com cotovelos altos. Deltóide posterior e manguito.'},
    // Bíceps
    {'nome': 'Rosca Direta com Barra', 'grupo': 'Bíceps', 'descricao': 'Em pé, cotovelos fixos ao lado do corpo, flexione os antebraços.'},
    {'nome': 'Rosca Alternada com Halteres', 'grupo': 'Bíceps', 'descricao': 'Flexione um braço de cada vez, mantendo o cotovelo imóvel.'},
    {'nome': 'Rosca Concentrada', 'grupo': 'Bíceps', 'descricao': 'Sentado, cotovelo apoiado na coxa interna, suba o haltere até o ombro.'},
    {'nome': 'Rosca Martelo', 'grupo': 'Bíceps', 'descricao': 'Pegada neutra (palma para dentro), trabalha braquial e braquiorradial.'},
    {'nome': 'Rosca no Cabo', 'grupo': 'Bíceps', 'descricao': 'Polia baixa, flexione o antebraço mantendo tensão constante no bíceps.'},
    {'nome': 'Rosca Scott', 'grupo': 'Bíceps', 'descricao': 'Braços apoiados no banco Scott, elimina o impulso. Barra reta ou W.'},
    {'nome': 'Rosca Inversa', 'grupo': 'Bíceps', 'descricao': 'Pegada pronada (palma para baixo), trabalha braquiorradial e antebraço.'},
    // Tríceps
    {'nome': 'Tríceps Pulley com Corda', 'grupo': 'Tríceps', 'descricao': 'Puxe a corda de cima para baixo até a extensão total, abrindo as pontas.'},
    {'nome': 'Tríceps Testa com Barra', 'grupo': 'Tríceps', 'descricao': 'Deitado no banco, desça a barra até a testa flexionando só o cotovelo.'},
    {'nome': 'Tríceps Francês com Haltere', 'grupo': 'Tríceps', 'descricao': 'Em pé ou sentado, segure haltere atrás da cabeça e estenda os cotovelos.'},
    {'nome': 'Mergulho entre Bancos', 'grupo': 'Tríceps', 'descricao': 'Mãos em um banco atrás, pés em outro, desça e suba flexionando os cotovelos.'},
    {'nome': 'Tríceps na Polia Alta (Barra)', 'grupo': 'Tríceps', 'descricao': 'Polia alta com barra reta, empurre de cima para baixo estendendo o cotovelo.'},
    {'nome': 'Kickback com Haltere', 'grupo': 'Tríceps', 'descricao': 'Inclinado, cotovelo paralelo ao tronco, estenda o antebraço para trás.'},
    {'nome': 'Mergulho na Paralela', 'grupo': 'Tríceps', 'descricao': 'Nas barras paralelas, desça o corpo e empurre de volta com os tríceps.'},
    // Pernas
    {'nome': 'Agachamento Livre com Barra', 'grupo': 'Pernas', 'descricao': 'Barra nas costas, desça até as coxas paralelas ao chão mantendo o tronco ereto.'},
    {'nome': 'Agachamento Hack', 'grupo': 'Pernas', 'descricao': 'Na máquina hack squat, pés na plataforma, desça com controle.'},
    {'nome': 'Leg Press 45°', 'grupo': 'Pernas', 'descricao': 'Pés na plataforma inclinada, empurre até quase estender os joelhos.'},
    {'nome': 'Leg Press Horizontal', 'grupo': 'Pernas', 'descricao': 'Sentado na máquina, empurre a plataforma horizontalmente.'},
    {'nome': 'Extensão de Perna na Cadeira', 'grupo': 'Pernas', 'descricao': 'Estenda os joelhos na cadeira extensora. Isola o quadríceps.'},
    {'nome': 'Flexão de Perna na Mesa', 'grupo': 'Pernas', 'descricao': 'Deitado na mesa flexora, flexione os joelhos até ~90°. Isola os isquiotibiais.'},
    {'nome': 'Stiff com Barra', 'grupo': 'Pernas', 'descricao': 'Joelhos levemente flexionados, desça a barra pelas pernas sentindo o isquiotibial.'},
    {'nome': 'Avanço com Halteres', 'grupo': 'Pernas', 'descricao': 'Passo à frente, desça o joelho traseiro até perto do chão, volte e troque.'},
    {'nome': 'Cadeira Adutora', 'grupo': 'Pernas', 'descricao': 'Feche as pernas contra a resistência. Trabalha a face interna da coxa.'},
    {'nome': 'Cadeira Abdutora', 'grupo': 'Pernas', 'descricao': 'Abra as pernas contra a resistência. Trabalha a face lateral da coxa.'},
    {'nome': 'Panturrilha em Pé na Máquina', 'grupo': 'Pernas', 'descricao': 'Em pé na máquina, eleve os calcanhares usando o gastrocnêmio.'},
    {'nome': 'Panturrilha Sentada', 'grupo': 'Pernas', 'descricao': 'Sentado na máquina, eleve os calcanhares. Ênfase no sóleo.'},
    {'nome': 'Agachamento Sumô', 'grupo': 'Pernas', 'descricao': 'Pés mais abertos e apontados para fora. Ênfase em adutores e glúteos.'},
    {'nome': 'Passada (Lunges)', 'grupo': 'Pernas', 'descricao': 'Passos à frente alternados, mantendo o tronco ereto. Barra ou halteres.'},
    // Glúteos
    {'nome': 'Hip Thrust com Barra', 'grupo': 'Glúteos', 'descricao': 'Ombros no banco, barra no quadril, empurre o quadril para cima contraindo o glúteo.'},
    {'nome': 'Elevação Pélvica', 'grupo': 'Glúteos', 'descricao': 'Deitado no chão, pés apoiados, suba o quadril contraindo o glúteo no topo.'},
    {'nome': 'Kickback no Cabo', 'grupo': 'Glúteos', 'descricao': 'Tornozeleira no cabo baixo, chute para trás estendendo o quadril.'},
    {'nome': 'Glúteo 4 Apoios', 'grupo': 'Glúteos', 'descricao': 'De quatro apoios, estenda uma perna para cima com joelho flexionado.'},
    {'nome': 'Abdução de Quadril no Cabo', 'grupo': 'Glúteos', 'descricao': 'Tornozeleira no cabo, abra a perna lateralmente contraindo o glúteo médio.'},
    {'nome': 'Agachamento Sumô com Haltere', 'grupo': 'Glúteos', 'descricao': 'Segure um haltere entre as pernas, pés afastados, desça com ênfase no glúteo.'},
    {'nome': 'Stiff com Halteres (foco glúteo)', 'grupo': 'Glúteos', 'descricao': 'Halteres à frente das coxas, incline o tronco sentindo o alongamento do glúteo.'},
    {'nome': 'Afundo Reverso', 'grupo': 'Glúteos', 'descricao': 'Passo para trás, joelho traseiro desce ao chão. Mais ênfase no glúteo que o avanço frontal.'},
    // Abdômen
    {'nome': 'Abdominal Supra', 'grupo': 'Abdômen', 'descricao': 'Deitado, joelhos flexionados, suba o tronco contraindo o abdômen superior.'},
    {'nome': 'Abdominal Infra', 'grupo': 'Abdômen', 'descricao': 'Deitado, eleve as pernas semiflexionadas contraindo o abdômen inferior.'},
    {'nome': 'Prancha Isométrica', 'grupo': 'Abdômen', 'descricao': 'Apoio nos antebraços e pontas dos pés, mantenha o core contraído e o corpo reto.'},
    {'nome': 'Abdominal Oblíquo', 'grupo': 'Abdômen', 'descricao': 'Suba o tronco rotacionando, cotovelo em direção ao joelho oposto.'},
    {'nome': 'Crunch na Máquina', 'grupo': 'Abdômen', 'descricao': 'Sentado na máquina, contraia o abdômen puxando o tronco para baixo.'},
    {'nome': 'Abdominal com Roda', 'grupo': 'Abdômen', 'descricao': 'De joelhos, role a roda à frente e volte usando o core para controlar.'},
    {'nome': 'Elevação de Pernas', 'grupo': 'Abdômen', 'descricao': 'Suspenso nas barras ou deitado, eleve as pernas retas até 90°.'},
    {'nome': 'Bicicleta Abdominal', 'grupo': 'Abdômen', 'descricao': 'Alterne cotovelo e joelho oposto em movimento de pedalada, sem apoiar a cabeça.'},
    {'nome': 'Russian Twist', 'grupo': 'Abdômen', 'descricao': 'Sentado com tronco inclinado, gire o tronco de um lado ao outro com ou sem peso.'},
    // Cardio
    {'nome': 'Esteira (Caminhada)', 'grupo': 'Cardio', 'descricao': 'Caminhada em ritmo moderado. Ótimo para aquecimento ou cardio leve.'},
    {'nome': 'Esteira (Corrida)', 'grupo': 'Cardio', 'descricao': 'Corrida em velocidade moderada a alta para condicionamento cardiovascular.'},
    {'nome': 'Bicicleta Ergométrica', 'grupo': 'Cardio', 'descricao': 'Pedale em ritmo constante ou com variação de intensidade.'},
    {'nome': 'Elíptico', 'grupo': 'Cardio', 'descricao': 'Movimento elíptico que simula corrida sem impacto nas articulações.'},
    {'nome': 'Corda Naval', 'grupo': 'Cardio', 'descricao': 'Ondule as cordas pesadas em padrões alternados ou simultâneos.'},
    {'nome': 'Pular Corda', 'grupo': 'Cardio', 'descricao': 'Pulo contínuo com corda. Excelente para condicionamento e coordenação.'},
    {'nome': 'HIIT', 'grupo': 'Cardio', 'descricao': 'Intervalos de alta intensidade alternados com recuperação. Ex: 40s sprint / 20s descanso.'},
    {'nome': 'Remo Ergométrico', 'grupo': 'Cardio', 'descricao': 'Movimento de remo na máquina, trabalha cardio e força de costas e pernas.'},
    // Funcional
    {'nome': 'Burpee', 'grupo': 'Funcional', 'descricao': 'Flexão + salto. Agache, vá ao chão, faça a flexão, pule e aplauda no topo.'},
    {'nome': 'Agachamento com Salto', 'grupo': 'Funcional', 'descricao': 'Agache e salte explosivamente. Aterrisse suavemente e repita.'},
    {'nome': 'Prancha com Rotação', 'grupo': 'Funcional', 'descricao': 'Da posição de prancha, abra um braço para o teto rotacionando o tronco.'},
    {'nome': 'Mountain Climber', 'grupo': 'Funcional', 'descricao': 'Em posição de flexão, alterne os joelhos em direção ao peito rapidamente.'},
    {'nome': 'Swing com Kettlebell', 'grupo': 'Funcional', 'descricao': 'Impulsione o kettlebell à frente com o movimento de quadril, não dos braços.'},
    {'nome': 'Box Jump', 'grupo': 'Funcional', 'descricao': 'Salto explosivo para cima de uma caixa. Desça com controle.'},
    {'nome': 'Farmer\'s Walk', 'grupo': 'Funcional', 'descricao': 'Caminhe carregando halteres ou kettlebells pesados ao lado do corpo.'},
    {'nome': 'Afundo com Salto', 'grupo': 'Funcional', 'descricao': 'Alterne as pernas em salto a partir da posição de avanço.'},
    {'nome': 'Bear Crawl', 'grupo': 'Funcional', 'descricao': 'De quatro apoios com os joelhos levemente elevados, avance alternando braço e perna.'},
    {'nome': 'Turkish Get-Up', 'grupo': 'Funcional', 'descricao': 'Do chão até em pé segurando kettlebell acima, em sequência controlada de movimentos.'},
  ];

  static Future<int> importarPadrao() async {
    final existentes = await _db
        .from('exercicios')
        .select('nome')
        .eq('personal_id', _personalId);
    final nomesExistentes = (existentes as List)
        .map((e) => (e['nome'] as String).toLowerCase())
        .toSet();

    final novos = _exerciciosPadrao
        .where((e) => !nomesExistentes.contains(e['nome']!.toLowerCase()))
        .map((e) => {
              'personal_id': _personalId,
              'nome': e['nome'],
              'grupo_muscular': e['grupo'],
              'descricao': e['descricao'],
            })
        .toList();

    if (novos.isEmpty) return 0;
    await _db.from('exercicios').insert(novos);
    return novos.length;
  }

  static Future<List<Map<String, dynamic>>> listar({String? grupo}) async {
    var query = _db
        .from('exercicios')
        .select()
        .eq('personal_id', _personalId);

    if (grupo != null && grupo != 'Todos') {
      query = query.eq('grupo_muscular', grupo);
    }

    return await query.order('nome');
  }

  static Future<Map<String, dynamic>> cadastrar({
    required String nome,
    required String grupoMuscular,
    String? descricao,
    String? midiaUrl,
    String? videoUrl,
  }) async {
    return await _db.from('exercicios').insert({
      'personal_id': _personalId,
      'nome': nome,
      'grupo_muscular': grupoMuscular,
      'descricao': descricao,
      'midia_url': midiaUrl,
      'video_url': videoUrl,
    }).select().single();
  }

  static Future<void> atualizar(String id, Map<String, dynamic> dados) async {
    await _db.from('exercicios').update(dados).eq('id', id);
  }

  static Future<void> deletar(String id) async {
    await _db.from('exercicios').delete().eq('id', id).eq('personal_id', _personalId);
  }

  static Future<String?> uploadImagem(String nome, List<int> bytes) async {
    final ext = nome.contains('.') ? nome.split('.').last.toLowerCase() : 'jpg';
    final fileName = '${_personalId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('exercicios-midia').uploadBinary(
      fileName, bytes as Uint8List,
      fileOptions: FileOptions(contentType: 'image/$ext', upsert: false),
    );
    return _db.storage.from('exercicios-midia').getPublicUrl(fileName);
  }

  static Future<String?> uploadVideo(String nome, Uint8List bytes) async {
    final ext = nome.contains('.') ? nome.split('.').last.toLowerCase() : 'mp4';
    final fileName = 'vid_${_personalId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from('exercicios-midia').uploadBinary(
      fileName, bytes,
      fileOptions: FileOptions(contentType: 'video/$ext', upsert: false),
    );
    return _db.storage.from('exercicios-midia').getPublicUrl(fileName);
  }
}
