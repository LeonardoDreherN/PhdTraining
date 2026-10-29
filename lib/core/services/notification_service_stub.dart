// Implementação vazia para web — flutter_local_notifications não suporta web
class NotificationService {
  static Future<void> init() async {}
  static Future<void> agendarTreinos(List<Map<String, dynamic>> fichas) async {}
  static Future<void> agendarRefeicoes(
      List<({String nome, int hora, int minuto})> refeicoes) async {}
  static Future<void> agendarAgua(List<int> horarios) async {}
  static Future<void> agendarConsultas(
      List<({String titulo, DateTime inicio})> consultas) async {}
  static Future<void> cancelarTodos() async {}
}
