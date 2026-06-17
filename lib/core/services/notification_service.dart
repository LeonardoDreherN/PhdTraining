// Usa implementação nativa (mobile) ou stub (web) em tempo de compilação
export 'notification_service_stub.dart'
    if (dart.library.io) 'notification_service_native.dart';
