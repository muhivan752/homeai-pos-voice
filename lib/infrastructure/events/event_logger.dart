import 'dart:async';
import 'dart:convert';

import 'pos_event.dart';

/// Callback for event listeners.
typedef EventCallback = void Function(PosEvent event);

/// Event logger for audit trail and future AI.
///
/// Features:
/// - In-memory buffer for current session
/// - Stream for real-time listeners
/// - JSON export for persistence
/// - Statistics aggregation
///
/// Usage:
/// ```dart
/// final logger = EventLogger();
///
/// // Listen to events
/// logger.stream.listen((event) {
///   print(event);
/// });
///
/// // Log event
/// logger.log(PosEvent.sessionStarted(role: UserRole.barista));
///
/// // Get stats
/// final stats = logger.getSessionStats();
/// ```
class EventLogger {
  final List<PosEvent> _events = [];
  final _controller = StreamController<PosEvent>.broadcast();

  /// Maximum events to keep in memory.
  final int maxEvents;

  /// Enable console output for debugging.
  final bool debugMode;

  EventLogger({
    this.maxEvents = 10000,
    this.debugMode = false,
  });

  /// Stream of events for real-time listeners.
  Stream<PosEvent> get stream => _controller.stream;

  /// All events in current session.
  List<PosEvent> get events => List.unmodifiable(_events);

  /// Log a new event.
  void log(PosEvent event) {
    _events.add(event);

    // Emit to stream
    _controller.add(event);

    // Debug output
    if (debugMode) {
      print(event);
    }

    // Trim if over limit
    if (_events.length > maxEvents) {
      _events.removeAt(0);
    }
  }

  /// Get events by type.
  List<PosEvent> getByType(EventType type) {
    return _events.where((e) => e.type == type).toList();
  }

  /// Get events in time range.
  List<PosEvent> getInRange(DateTime start, DateTime end) {
    return _events.where((e) {
      return e.timestamp.isAfter(start) && e.timestamp.isBefore(end);
    }).toList();
  }

  /// Get session statistics.
  Map<String, dynamic> getSessionStats() {
    final intentEvents =
        _events.where((e) => e.intentType != null).toList();

    final successCount = intentEvents.where((e) => e.success == true).length;
    final failCount = intentEvents.where((e) => e.success == false).length;

    // Count by intent type
    final intentCounts = <String, int>{};
    for (final event in intentEvents) {
      final key = event.intentType!.name;
      intentCounts[key] = (intentCounts[key] ?? 0) + 1;
    }

    // Count by error code
    final errorCounts = <String, int>{};
    for (final event in intentEvents.where((e) => e.errorCode != null)) {
      final key = event.errorCode!;
      errorCounts[key] = (errorCounts[key] ?? 0) + 1;
    }

    return {
      'totalEvents': _events.length,
      'intentEvents': intentEvents.length,
      'successCount': successCount,
      'failCount': failCount,
      'successRate':
          intentEvents.isNotEmpty ? successCount / intentEvents.length : 0,
      'intentCounts': intentCounts,
      'errorCounts': errorCounts,
      'sessionStart':
          _events.isNotEmpty ? _events.first.timestamp.toIso8601String() : null,
      'sessionEnd':
          _events.isNotEmpty ? _events.last.timestamp.toIso8601String() : null,
    };
  }

  /// Export all events as JSON.
  String exportJson() {
    return jsonEncode(_events.map((e) => e.toJson()).toList());
  }

  /// Export events as newline-delimited JSON (for streaming/append).
  String exportNdjson() {
    return _events.map((e) => jsonEncode(e.toJson())).join('\n');
  }

  /// Import events from JSON.
  void importJson(String json) {
    final list = jsonDecode(json) as List;
    for (final item in list) {
      _events.add(PosEvent.fromJson(item as Map<String, dynamic>));
    }
  }

  /// Clear all events.
  void clear() {
    _events.clear();
  }

  /// Dispose resources.
  void dispose() {
    _controller.close();
  }
}
