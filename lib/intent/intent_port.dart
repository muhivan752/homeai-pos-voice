/// Re-export from domain layer for backward compatibility.
/// New code should import from 'package:homeai_pos_voice/domain/domain.dart'
export '../domain/ports/erp_port.dart';
export '../domain/entities/cart.dart';

// Alias for backward compatibility
import '../domain/ports/erp_port.dart';

/// @deprecated Use ERPPort instead
typedef IntentPort = ERPPort;
