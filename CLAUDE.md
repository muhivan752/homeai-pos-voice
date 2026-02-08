# CLAUDE.md

## Project Overview

**homeai_voice** is a voice-controlled Point of Sale (POS) proof-of-concept for a coffee shop. Staff (baristas) ring up sales and check out customers using voice commands. Spoken text is parsed into typed intents, validated against role-based access control, then executed against an ERPNext backend.

**Status:** Early-stage PoC. Only `sellItem` and `checkout` intents are implemented. The parser uses simple keyword matching (not NLP).

## Tech Stack

- **Language:** Dart (SDK >=3.0.0 <4.0.0)
- **Runtime:** Dart CLI (not Flutter)
- **External API:** ERPNext/Frappe REST API (HTTP, token auth)
- **Package manager:** `dart pub`
- **Dependencies:** `http` package (used in `erp_client.dart`, referenced via `package:http`)

## Project Structure

```
lib/
  main.dart                          # Entry point: wires up coordinator and runs a sample command
  core/
    auth_context .dart               # UserRole enum (barista, spv, owner) + AuthContext
    voice_command_coordinator.dart   # Orchestrator: parse -> validate -> execute
    role_gatekeeper.dart             # allowIntent(role, intent) -> bool
    erp_client.dart                  # HTTP client for ERPNext Sales Invoice API
    erp_sales_adapter.dart           # Stub adapter with print-based output
  intent/
    intent.dart                      # Intent data class (id, type, payload)
    intent_type.dart                 # IntentType enum: sellItem, checkout, unknown
    intent_payload.dart              # Sealed class: SellItemPayload, CheckoutPayload, UnknownPayload
    intent_parser.dart               # Keyword-based parser (jual -> sellItem, checkout/bayar -> checkout)
    intent_executor.dart             # Dispatches intent to IntentPort by type
    intent_port.dart                 # Abstract interface: sellItem(), checkout()
    intent_contract.dart             # Abstract IntentExecutor contract (canHandle + execute)
    mock_intent_port.dart            # Mock IntentPort that prints actions
  ui/
    post_screen.dart                 # UI integration point (initState + onMicPressed)
  voice/
    voice_input.dart                 # Callback-based voice input handler
bin/
  homeai_voice.dart                  # Legacy entry point (earlier iteration, has syntax issues)
```

**Note:** `lib/core/auth_context .dart` has a trailing space in the filename.

## Architecture

The system uses a **Ports and Adapters** (hexagonal) pattern:

```
Voice Input -> IntentParser -> Intent -> RoleGatekeeper -> IntentExecutor -> IntentPort (impl)
                                                                              |
                                                              ERPClient / MockIntentPort
```

1. **VoiceInput** captures spoken text via callback
2. **VoiceCommandCoordinator** orchestrates the full pipeline
3. **IntentParser** converts raw text to a typed `Intent` (keyword matching)
4. **RoleGatekeeper** checks if the user's role allows the intent
5. **IntentExecutor** dispatches to the appropriate `IntentPort` method
6. **IntentPort** is an abstract interface; implementations include `ERPClient` (real) and `MockIntentPort` (testing)

### Key Types

- `Intent` — immutable data class with `id`, `type`, `payload`
- `IntentPayload` — sealed class hierarchy (`SellItemPayload{item, qty}`, `CheckoutPayload`, `UnknownPayload`)
- `IntentType` — enum: `sellItem`, `checkout`, `unknown`
- `UserRole` — enum: `barista`, `spv`, `owner`

### Role Permissions

| Role    | Allowed Intents         |
|---------|------------------------|
| barista | AddItem, Checkout       |
| spv     | Stock, Closing          |
| owner   | ReadOnly                |

## Common Commands

```bash
# Get dependencies
dart pub get

# Run the app
dart run lib/main.dart

# Run from bin entry point (legacy, has issues)
dart run bin/homeai_voice.dart

# Analyze code
dart analyze
```

## Conventions

- **Language mixing:** Code identifiers and structure are in English. User-facing strings and some comments are in Indonesian (e.g., "jual" = sell, "bayar" = pay, "Berhasil" = success, "AKSES_DITOLAK" = access denied).
- **Commit style:** Conventional commits — `feat(scope):`, `refactor(scope):`, etc.
- **Dependency injection:** Constructor-based DI throughout (coordinator, executor, etc.).
- **Error signaling:** Errors thrown as `Exception` with prefixed codes (e.g., `ERP_SALES_INVOICE_FAILED`).
- **No tests yet:** No `test/` directory or test dependencies exist.
- **No linting config:** No `analysis_options.yaml` present.
- **No .gitignore:** No ignore file exists.
- **No environment files:** ERP credentials (`baseUrl`, `apiKey`, `apiSecret`) are passed via constructor, not loaded from env.

## ERP Integration

The `ERPClient` connects to an ERPNext instance:

- **Endpoint:** `POST {baseUrl}/api/resource/Sales Invoice`
- **Auth:** `Authorization: token {apiKey}:{apiSecret}`
- **Payload:** JSON with `customer`, `items[]` (item_code, qty), `payments[]` (mode_of_payment, amount)
- **Customer:** Hardcoded to "Walk-in Customer"
- **Pricing:** Auto-calculated by ERP (amount: 0)

## Known Limitations / Technical Debt

- `IntentParser` uses hardcoded keyword matching — no real NLP
- Item name ("kopi susu") and quantity are hardcoded in the parser
- Intent IDs are random integers (0-999999), not UUIDs
- `bin/homeai_voice.dart` has code outside `main()` (lines 16-19)
- `role_gatekeeper.dart` references types (`AddItemIntent`, `StockIntent`, etc.) that don't exist in the codebase — it won't compile as-is
- `IntentExecutor` exists as both a concrete class (`lib/intent/intent_executor.dart`) and an abstract contract (`lib/intent/intent_contract.dart`) with different signatures
- `VoiceCommandCoordinator` calls `parser.parseCommand()` but the method is named `parser.parse()`
- `ERPClient` does not implement `IntentPort` but is passed to `IntentExecutor` which expects an `IntentPort`
- The `http` package is imported but not declared in `pubspec.yaml` dependencies
- Auth context filename has a trailing space (`auth_context .dart`)
