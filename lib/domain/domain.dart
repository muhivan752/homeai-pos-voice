/// Domain Layer - Clean Architecture
///
/// Contains:
/// - Result type for error handling
/// - Entities (CartItem, CartTotal)
/// - Ports/Interfaces (ERPPort)
/// - Intent domain objects (Intent, IntentType, IntentPayload)
///
/// RULES:
/// - Domain layer has NO dependencies on infrastructure
/// - Domain layer defines interfaces (ports) that infrastructure implements
/// - All business rules live here

// Result type for error handling
export 'result.dart';

// Entities
export 'entities/cart.dart';

// Ports
export 'ports/erp_port.dart';

// Intent
export 'intent/intent.dart';
export 'intent/intent_type.dart';
export 'intent/intent_payload.dart';
