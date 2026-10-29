import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _inicializado = false;

  static const _channelId = 'treino_dia';
  static const _channelNome = 'Treino do dia';
  static const _canalRefeicao = 'refeicoes';
  static const _canalAgua = 'agua';

  // Cada tipo de lembrete tem sua faixa de ids. Antes havia um só tipo e
  // `agendarTreinos` começava com `cancelAll()` — o que, com os lembretes
  // de refeição, apagaria a dieta toda vez que a home recarregasse.
  static const _idsTreino = (0, 99);
  static const _idsRefeicao = (1000, 1099);
  static const _idsAgua = (2000, 2099);
  static const _idsConsulta = (3000, 3099);

  static final _mensagens = [
    'Hoje é dia de evoluir. Bora treinar! 🔥',
    'Seu futuro eu vai te agradecer por treinar hoje. 💪',
    'O único treino ruim é o que não foi feito. Vamos lá!',
    'Cada treino é um passo mais perto dos seus objetivos. 🏆',
    'Consistência é o segredo. Mais um dia, mais um treino.',
    'Hora de mostrar do que você é capaz! 💥',
    'Não quebre a sequência. Você consegue! 🎯',
  ];

  static Future<void> init() async {
    if (_inicializado) return;
    try {
      tz_data.initializeTimeZones();
      try {
        tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
      } catch (_) {}

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelNome,
              description: 'Lembrete diário de treino',
              importance: Importance.high,
            ),
          );

      final plataforma = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await plataforma?.createNotificationChannel(const AndroidNotificationChannel(
        _canalRefeicao,
        'Refeições',
        description: 'Lembrete na hora de cada refeição do plano',
        importance: Importance.high,
      ));
      await plataforma?.createNotificationChannel(const AndroidNotificationChannel(
        _canalAgua,
        'Água',
        description: 'Lembrete para beber água ao longo do dia',
        importance: Importance.defaultImportance,
      ));
      await plataforma?.requestNotificationsPermission();

      _inicializado = true;
    } catch (e) {
      debugPrint('NotificationService.init erro: $e');
    }
  }

  static Future<void> agendarTreinos(
      List<Map<String, dynamic>> fichas) async {
    if (!_inicializado) return;
    try {
      await _cancelarFaixa(_idsTreino);
      if (fichas.isEmpty) return;

      final Set<int> diasTreino = {};
      for (final f in fichas) {
        final dias = f['dias_semana'];
        if (dias is List) {
          for (final d in dias) {
            diasTreino.add(d as int);
          }
        }
      }
      if (diasTreino.isEmpty) return;

      final now = tz.TZDateTime.now(tz.local);
      const detalheNotif = NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelNome,
          channelDescription: 'Lembrete diário de treino',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

      int id = _idsTreino.$1;
      for (var i = 0; i < 14; i++) {
        final dia = now.add(Duration(days: i));
        final diaSemana = dia.weekday % 7;
        if (!diasTreino.contains(diaSemana)) continue;

        final agendado = tz.TZDateTime(
            tz.local, dia.year, dia.month, dia.day, 7, 0);
        if (agendado.isBefore(now)) continue;

        await _plugin.zonedSchedule(
          id++,
          'PHD — Dia de treino! 💪',
          _mensagens[Random().nextInt(_mensagens.length)],
          agendado,
          detalheNotif,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.agendarTreinos erro: $e');
    }
  }

  /// Um lembrete por refeição do plano, todo dia no horário dela.
  /// Lista vazia só cancela — é como se desliga.
  static Future<void> agendarRefeicoes(
      List<({String nome, int hora, int minuto})> refeicoes) async {
    if (!_inicializado) return;
    try {
      await _cancelarFaixa(_idsRefeicao);
      for (final (i, r) in refeicoes.take(_idsRefeicao.$2 - _idsRefeicao.$1).indexed) {
        await _plugin.zonedSchedule(
          _idsRefeicao.$1 + i,
          'Hora do ${r.nome.toLowerCase()} 🍽️',
          'Confira o que tem no seu plano e registre quando comer.',
          _proxima(r.hora, r.minuto),
          const NotificationDetails(
            android: AndroidNotificationDetails(_canalRefeicao, 'Refeições',
                importance: Importance.high, priority: Priority.high),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          // Repete todo dia no mesmo horário: agendar uma vez basta.
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.agendarRefeicoes erro: $e');
    }
  }

  /// Lembretes de água nos [horarios] (horas cheias), todo dia.
  static Future<void> agendarAgua(List<int> horarios) async {
    if (!_inicializado) return;
    try {
      await _cancelarFaixa(_idsAgua);
      for (final (i, h) in horarios.indexed) {
        await _plugin.zonedSchedule(
          _idsAgua.$1 + i,
          'Hora de beber água 💧',
          'Um copo agora e registre no app.',
          _proxima(h, 0),
          const NotificationDetails(
            android: AndroidNotificationDetails(_canalAgua, 'Água'),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (e) {
      debugPrint('NotificationService.agendarAgua erro: $e');
    }
  }

  /// Dois avisos por consulta: na véspera às 19h e duas horas antes.
  /// Reagendar cancela os anteriores — consulta remarcada não pode tocar
  /// no horário velho.
  static Future<void> agendarConsultas(List<({String titulo, DateTime inicio})> consultas) async {
    if (!_inicializado) return;
    try {
      await _cancelarFaixa(_idsConsulta);
      final agora = tz.TZDateTime.now(tz.local);
      var id = _idsConsulta.$1;
      for (final c in consultas) {
        final inicio = tz.TZDateTime.from(c.inicio, tz.local);
        final vespera = tz.TZDateTime(tz.local, inicio.year, inicio.month, inicio.day - 1, 19);
        final hora = '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')}';
        for (final (quando, corpo) in [
          (vespera, 'Amanhã às $hora: ${c.titulo}. Confirme pelo app.'),
          (inicio.subtract(const Duration(hours: 2)), 'Daqui a 2 horas: ${c.titulo}, às $hora.'),
        ]) {
          if (!quando.isAfter(agora) || id > _idsConsulta.$2) continue;
          await _plugin.zonedSchedule(
            id++,
            'Consulta 📅',
            corpo,
            quando,
            const NotificationDetails(
              android: AndroidNotificationDetails(_channelId, _channelNome,
                  importance: Importance.high, priority: Priority.high),
              iOS: DarwinNotificationDetails(),
            ),
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      }
    } catch (e) {
      debugPrint('NotificationService.agendarConsultas erro: $e');
    }
  }

  /// A próxima ocorrência de hh:mm — hoje, se ainda não passou.
  static tz.TZDateTime _proxima(int hora, int minuto) {
    final agora = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, agora.year, agora.month, agora.day, hora, minuto);
    if (!t.isAfter(agora)) t = t.add(const Duration(days: 1));
    return t;
  }

  static Future<void> _cancelarFaixa((int, int) faixa) async {
    final pendentes = await _plugin.pendingNotificationRequests();
    for (final p in pendentes) {
      if (p.id >= faixa.$1 && p.id <= faixa.$2) await _plugin.cancel(p.id);
    }
  }

  static Future<void> cancelarTodos() async {
    if (!_inicializado) return;
    await _plugin.cancelAll();
  }
}
