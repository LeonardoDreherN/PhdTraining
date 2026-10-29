import 'package:shared_preferences/shared_preferences.dart';
import '../models/dieta.dart';
import 'notification_service.dart';

/// Liga e desliga os lembretes da dieta, e reagenda a partir do plano.
///
/// A escolha fica no aparelho, como o tema: é sobre o celular tocar, não
/// sobre a conta. Refeições vêm ligadas (é o que o aluno espera de um app
/// de dieta); água vem desligada — sete toques por dia sem pedir incomoda.
class LembretesService {
  static const _chaveRefeicoes = 'lembrete_refeicoes';
  static const _chaveAgua = 'lembrete_agua';

  /// De duas em duas horas, das 9h às 21h.
  static const horariosAgua = [9, 11, 13, 15, 17, 19, 21];

  static Future<({bool refeicoes, bool agua})> estado() async {
    final p = await SharedPreferences.getInstance();
    return (
      refeicoes: p.getBool(_chaveRefeicoes) ?? true,
      agua: p.getBool(_chaveAgua) ?? false,
    );
  }

  static Future<void> definir({bool? refeicoes, bool? agua, PlanoAlimentar? plano}) async {
    final p = await SharedPreferences.getInstance();
    if (refeicoes != null) await p.setBool(_chaveRefeicoes, refeicoes);
    if (agua != null) await p.setBool(_chaveAgua, agua);
    await aplicar(plano);
  }

  /// Reagenda tudo conforme as escolhas. Chamado ao abrir a home e a dieta:
  /// se o profissional mudou o horário do almoço, o lembrete acompanha.
  static Future<void> aplicar(PlanoAlimentar? plano) async {
    final e = await estado();
    await NotificationService.agendarRefeicoes(
      e.refeicoes && plano != null ? horariosDoPlano(plano) : const [],
    );
    await NotificationService.agendarAgua(e.agua ? horariosAgua : const []);
  }

  static List<({String nome, int hora, int minuto})> horariosDoPlano(PlanoAlimentar plano) => [
        for (final r in plano.refeicoes)
          if (!r.vazia)
            if (r.horarioTexto?.split(':') case [final h, final m])
              if ((int.tryParse(h), int.tryParse(m)) case (final hora?, final minuto?))
                (nome: r.nome, hora: hora, minuto: minuto),
      ];
}
