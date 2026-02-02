import '../../domain/domain.dart';
import '../auth/auth_context.dart';

/// Event types for POS audit trail.
enum EventType {
  // Intent events
  intentReceived,
  intentExecuted,
  intentFailed,
  intentDenied, // Role-based access denied

  // Session events
  sessionStarted,
  sessionEnded,

  // Voice events
  voiceInputStarted,
  voiceInputReceived,
  voiceInputFailed,
  voiceOutputSpoken,

  // UI events
  modeChanged, // Customer <-> Staff
}

/// A single event in the POS audit trail.
///
/// Designed for:
/// 1. Audit trail (compliance, debugging)
/// 2. Future AI training data
/// 3. Analytics and insights
class PosEvent {
  final String id;
  final DateTime timestamp;
  final EventType type;
  final UserRole? role;
  final String? userId;

  // Intent-related (if applicable)
  final IntentType? intentType;
  final String? intentId;
  final String? rawInput;

  // Result
  final bool? success;
  final String? message;
  final String? errorCode;

  // Context
  final Map<String, dynamic>? metadata;

  PosEvent({
    required this.id,
    required this.timestamp,
    required this.type,
    this.role,
    this.userId,
    this.intentType,
    this.intentId,
    this.rawInput,
    this.success,
    this.message,
    this.errorCode,
    this.metadata,
  });

  /// Create event from intent execution.
  factory PosEvent.fromIntent({
    required Intent intent,
    required UserRole role,
    required bool success,
    required String message,
    String? userId,
    String? rawInput,
    String? errorCode,
  }) {
    return PosEvent(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: success ? EventType.intentExecuted : EventType.intentFailed,
      role: role,
      userId: userId,
      intentType: intent.type,
      intentId: intent.id,
      rawInput: rawInput,
      success: success,
      message: message,
      errorCode: errorCode,
    );
  }

  /// Create event for access denied.
  factory PosEvent.accessDenied({
    required Intent intent,
    required UserRole role,
    String? userId,
    String? rawInput,
  }) {
    return PosEvent(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: EventType.intentDenied,
      role: role,
      userId: userId,
      intentType: intent.type,
      intentId: intent.id,
      rawInput: rawInput,
      success: false,
      message: 'Access denied for role: ${role.name}',
      errorCode: 'ACCESS_DENIED',
    );
  }

  /// Create event for voice input.
  factory PosEvent.voiceInput({
    required String rawInput,
    required bool success,
    UserRole? role,
    String? userId,
    String? errorCode,
  }) {
    return PosEvent(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: success ? EventType.voiceInputReceived : EventType.voiceInputFailed,
      role: role,
      userId: userId,
      rawInput: rawInput,
      success: success,
      errorCode: errorCode,
    );
  }

  /// Create event for mode change.
  factory PosEvent.modeChanged({
    required String fromMode,
    required String toMode,
    String? userId,
  }) {
    return PosEvent(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: EventType.modeChanged,
      userId: userId,
      success: true,
      metadata: {'fromMode': fromMode, 'toMode': toMode},
    );
  }

  /// Create event for session start.
  factory PosEvent.sessionStarted({
    required UserRole role,
    String? userId,
  }) {
    return PosEvent(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: EventType.sessionStarted,
      role: role,
      userId: userId,
      success: true,
    );
  }

  /// Create event for session end.
  factory PosEvent.sessionEnded({
    required UserRole role,
    String? userId,
    Map<String, dynamic>? sessionStats,
  }) {
    return PosEvent(
      id: _generateId(),
      timestamp: DateTime.now(),
      type: EventType.sessionEnded,
      role: role,
      userId: userId,
      success: true,
      metadata: sessionStats,
    );
  }

  /// Convert to JSON for storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'role': role?.name,
      'userId': userId,
      'intentType': intentType?.name,
      'intentId': intentId,
      'rawInput': rawInput,
      'success': success,
      'message': message,
      'errorCode': errorCode,
      'metadata': metadata,
    };
  }

  /// Create from JSON.
  factory PosEvent.fromJson(Map<String, dynamic> json) {
    return PosEvent(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: EventType.values.firstWhere((e) => e.name == json['type']),
      role: json['role'] != null
          ? UserRole.values.firstWhere((e) => e.name == json['role'])
          : null,
      userId: json['userId'] as String?,
      intentType: json['intentType'] != null
          ? IntentType.values.firstWhere((e) => e.name == json['intentType'])
          : null,
      intentId: json['intentId'] as String?,
      rawInput: json['rawInput'] as String?,
      success: json['success'] as bool?,
      message: json['message'] as String?,
      errorCode: json['errorCode'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    final parts = [
      timestamp.toIso8601String(),
      type.name,
      if (role != null) 'role=${role!.name}',
      if (intentType != null) 'intent=${intentType!.name}',
      if (success != null) success! ? 'OK' : 'FAIL',
      if (message != null) message,
    ];
    return '[EVENT] ${parts.join(' | ')}';
  }

  static int _idCounter = 0;
  static String _generateId() {
    _idCounter++;
    return 'evt_${DateTime.now().millisecondsSinceEpoch}_$_idCounter';
  }
}
