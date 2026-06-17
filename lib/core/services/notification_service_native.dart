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

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      _inicializado = true;
    } catch (e) {
      debugPrint('NotificationService.init erro: $e');
    }
  }

  static Future<void> agendarTreinos(
      List<Map<String, dynamic>> fichas) async {
    if (!_inicializado) return;
    try {
      await _plugin.cancelAll();
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

      int id = 0;
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

  static Future<void> cancelarTodos() async {
    if (!_inicializado) return;
    await _plugin.cancelAll();
  }
}
