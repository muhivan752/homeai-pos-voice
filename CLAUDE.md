# CLAUDE.md

## Gambaran Proyek

**HomeAI POS Voice** adalah sistem Point of Sale (POS) berbasis suara bertenaga AI untuk kedai kopi. Seluruh interaksi dilakukan melalui voice command. Arsitektur menggunakan 3 layer: **POS (mulut & tangan)** -> **LocalDB (buffer offline)** -> **ERP (otak bisnis)**.

**Status:** PoC dengan fitur lengkap — sell, checkout, cancel, cek stok, laporan, sync, login.

## Tech Stack

- **Bahasa:** Dart (SDK >=3.0.0 <4.0.0)
- **Framework:** Flutter (mobile app)
- **API Eksternal:** ERPNext/Frappe REST API (HTTP, token auth)
- **Package manager:** `dart pub` / `flutter pub`
- **Dependensi:** `http`, `crypto`, `path`, `path_provider`, `speech_to_text`

## Arsitektur 3 Layer

```
  Layer 1: HomeAI POS (Voice Interface)
  Mulut & tangan — terima suara, tampilkan respons
            |
  Layer 2: LocalDB (Offline Buffer)
  Semua transaksi masuk sini dulu, jaga-jaga kalau ERP mati
            |
  Layer 3: ERP (Otak Bisnis)
  Source of truth — master data, harga, stok, laporan
```

### Alur Data

```
VoiceInput -> IntentParser -> Intent -> RoleGatekeeper -> IntentExecutor -> LocalIntentPort -> LocalDB
                                                                                                 |
                                                                               SyncEngine (auto/manual)
                                                                                                 |
                                                                                            ERPClient
```

## Struktur Proyek

```
lib/
  main.dart                          # Flutter entry point (MaterialApp)
  core/
    auth_context.dart                # UserRole enum, AuthContext, AuthService (login + password SHA-256)
    voice_command_coordinator.dart   # Orkestrator utama: login -> parse -> validate -> execute -> save
    role_gatekeeper.dart             # allowIntent(role, intent) berbasis IntentType
    erp_client.dart                  # HTTP client ke ERPNext (sales invoice, stok, health check)
    service_provider.dart            # Singleton service provider (inisialisasi semua service)
  intent/
    intent.dart                      # Data class Intent (id, type, payload, createdAt)
    intent_type.dart                 # IntentType enum (8 tipe)
    intent_payload.dart              # Sealed class hierarchy (7 payload types)
    intent_parser.dart               # Parser NL -> Intent (keyword matching + regex qty extraction)
    intent_executor.dart             # Dispatch intent ke IntentPort, return pesan respons
    intent_port.dart                 # Interface abstrak untuk eksekusi intent
    mock_intent_port.dart            # Mock implementation untuk testing
  db/
    local_db.dart                    # LocalDB: cart, transaksi, stok, laporan (JSON file-based)
    local_intent_port.dart           # IntentPort implementation berbasis LocalDB
  sync/
    sync_engine.dart                 # Auto-sync + manual sync ke ERP, status tracking
  ui/
    login_screen.dart                # Halaman login Flutter
    pos_home_screen.dart             # Halaman utama POS (chat-style voice interface)
    post_screen.dart                 # Re-export (backwards compat)
  voice/
    voice_input.dart                 # Handler input suara + callback respons
bin/
  demo.dart                          # CLI demo mode (tanpa Flutter)
```

## Intent Types

| IntentType   | Contoh Voice Command                | Role Minimum |
|-------------|-------------------------------------|-------------|
| `login`      | "login admin admin123"              | Semua       |
| `sellItem`   | "jual kopi susu 2", "tambah latte"  | barista     |
| `checkout`   | "bayar qris", "checkout"            | barista     |
| `cancelItem` | "batal americano", "cancel"         | barista     |
| `checkStock` | "cek stok", "stok matcha"           | spv         |
| `dailyReport`| "laporan", "rekap"                  | spv         |
| `syncManual` | "sync", "sinkron"                   | spv         |
| `unknown`    | (tidak dikenali)                    | -           |

## Hak Akses (Role-Based)

| Peran   | Akses                                          |
|---------|------------------------------------------------|
| barista | sellItem, checkout, cancelItem                  |
| spv     | semua barista + checkStock, dailyReport, sync   |
| owner   | full access                                     |
| admin   | full access                                     |

## Auth System

- Password di-hash dengan SHA-256 (`package:crypto`)
- Default admin: **username:** `admin`, **password:** `admin123`
- Login via UI form atau voice: `"login [username] [password]"`
- Semua perintah selain login butuh autentikasi

### Default Users

| Username  | Password    | Role    |
|-----------|-------------|---------|
| admin     | admin123    | admin   |
| barista1  | barista123  | barista |
| spv       | spv123      | spv     |

## LocalDB

- **Storage:** JSON file-based di folder `.homeai_db/`
- **Files:** `transactions.json`, `stock.json`
- **Cart:** In-memory, auto-merge item yang sama
- **Transaction status:** `pending` -> `synced` / `failed`
- **Offline-first:** Semua operasi simpan ke LocalDB dulu, sync ke ERP belakangan
- **Reset:** `LocalDB.reset()` untuk hapus semua data

## Sync Engine

- **Auto-sync:** Berjalan otomatis tiap 30 detik
- **Manual sync:** Via voice command `"sync"` atau `"sinkron"`
- **Retry:** Transaksi `failed` bisa di-sync ulang via `syncAll()`
- **Status:** `getStatus()` menunjukkan pending count, failed count, sync state

## Integrasi ERP

`ERPClient` terhubung ke instance ERPNext:

- **Sales Invoice:** `POST {baseUrl}/api/resource/Sales Invoice`
- **Stock:** `GET {baseUrl}/api/resource/Bin`
- **Health Check:** `GET {baseUrl}/api/method/frappe.auth.get_logged_user`
- **Auth:** `Authorization: token {apiKey}:{apiSecret}`
- **Env vars:** `ERP_BASE_URL`, `ERP_API_KEY`, `ERP_API_SECRET`

## Perintah Umum

```bash
# Mengambil dependensi
flutter pub get

# Menjalankan aplikasi Flutter
flutter run

# Menjalankan CLI demo (tanpa Flutter)
dart run bin/demo.dart

# Menganalisis kode
flutter analyze
```

## Konvensi

- **Bahasa kode:** Identifier dalam bahasa Inggris, string user-facing dalam bahasa Indonesia
- **Gaya commit:** Conventional commits — `feat(scope):`, `refactor(scope):`, dll.
- **DI:** Constructor-based dependency injection + ServiceProvider singleton
- **Error:** Exception dengan kode berprefix (contoh: `ERP_SALES_INVOICE_FAILED`)
- **Offline-first:** Semua transaksi masuk LocalDB dulu, baru sync ke ERP
- **Arsitektur:** Ports and Adapters (hexagonal) — IntentPort sebagai boundary

## Roadmap

- [ ] Upgrade parser ke LLM-based (conversational, bukan keyword matching)
- [x] Flutter UI (login + POS screen)
- [ ] Speech-to-text integration
- [ ] Tambah test suite
- [ ] Tambah `analysis_options.yaml` untuk linting
- [ ] Migrasi LocalDB ke SQLite/Isar untuk performa
- [ ] Smart upselling (AI suggest berdasarkan history)
- [ ] Multi-modal input (voice + touch)
