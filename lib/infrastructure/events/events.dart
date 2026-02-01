/// Event logging infrastructure for audit and future AI.
///
/// Usage:
/// ```dart
/// import 'package:homeai_voice/infrastructure/events/events.dart';
///
/// final logger = EventLogger(debugMode: true);
///
/// // Log intent execution
/// logger.log(PosEvent.fromIntent(
///   intent: intent,
///   role: UserRole.barista,
///   success: true,
///   message: 'Item added',
/// ));
///
/// // Get stats at end of session
/// final stats = logger.getSessionStats();
/// ```

export 'event_logger.dart';
export 'pos_event.dart';
