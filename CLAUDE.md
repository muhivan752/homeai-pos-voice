# CLAUDE.md

## Gambaran Proyek

**homeai_voice** adalah proof-of-concept (PoC) sistem Point of Sale (POS) berbasis suara untuk kedai kopi. Staf (barista) mencatat penjualan dan melakukan checkout menggunakan perintah suara. Teks yang diucapkan di-parse menjadi intent bertipe, divalidasi berdasarkan kontrol akses berbasis peran (role), lalu dieksekusi ke backend ERPNext.

**Status:** PoC tahap awal. Baru intent `sellItem` dan `checkout` yang diimplementasi. Parser menggunakan pencocokan kata kunci sederhana (belum NLP).

## Tech Stack

- **Bahasa:** Dart (SDK >=3.0.0 <4.0.0)
- **Runtime:** Dart CLI (bukan Flutter)
- **API Eksternal:** ERPNext/Frappe REST API (HTTP, token auth)
- **Package manager:** `dart pub`
- **Dependensi:** package `http` (digunakan di `erp_client.dart`, direferensikan via `package:http`)

## Struktur Proyek

```
lib/
  main.dart                          # Entry point: menyambungkan coordinator dan menjalankan contoh perintah
  core/
    auth_context .dart               # Enum UserRole (barista, spv, owner) + AuthContext
    voice_command_coordinator.dart   # Orkestrator: parse -> validasi -> eksekusi
    role_gatekeeper.dart             # allowIntent(role, intent) -> bool
    erp_client.dart                  # HTTP client untuk ERPNext Sales Invoice API
    erp_sales_adapter.dart           # Adapter stub dengan output berbasis print
  intent/
    intent.dart                      # Data class Intent (id, type, payload)
    intent_type.dart                 # Enum IntentType: sellItem, checkout, unknown
    intent_payload.dart              # Sealed class: SellItemPayload, CheckoutPayload, UnknownPayload
    intent_parser.dart               # Parser berbasis kata kunci (jual -> sellItem, checkout/bayar -> checkout)
    intent_executor.dart             # Mendispatch intent ke IntentPort berdasarkan tipe
    intent_port.dart                 # Interface abstrak: sellItem(), checkout()
    intent_contract.dart             # Kontrak abstrak IntentExecutor (canHandle + execute)
    mock_intent_port.dart            # Mock IntentPort yang mencetak aksi
  ui/
    post_screen.dart                 # Titik integrasi UI (initState + onMicPressed)
  voice/
    voice_input.dart                 # Handler input suara berbasis callback
bin/
  homeai_voice.dart                  # Entry point lama (iterasi sebelumnya, ada masalah sintaks)
```

**Catatan:** `lib/core/auth_context .dart` memiliki spasi di akhir nama file.

## Arsitektur

Sistem menggunakan pola **Ports and Adapters** (heksagonal):

```
Voice Input -> IntentParser -> Intent -> RoleGatekeeper -> IntentExecutor -> IntentPort (impl)
                                                                              |
                                                              ERPClient / MockIntentPort
```

1. **VoiceInput** menangkap teks suara melalui callback
2. **VoiceCommandCoordinator** mengorkestrasi seluruh pipeline
3. **IntentParser** mengubah teks mentah menjadi `Intent` bertipe (pencocokan kata kunci)
4. **RoleGatekeeper** memeriksa apakah peran pengguna mengizinkan intent tersebut
5. **IntentExecutor** mendispatch ke method `IntentPort` yang sesuai
6. **IntentPort** adalah interface abstrak; implementasinya termasuk `ERPClient` (produksi) dan `MockIntentPort` (testing)

### Tipe-Tipe Utama

- `Intent` — data class immutable dengan `id`, `type`, `payload`
- `IntentPayload` — hierarki sealed class (`SellItemPayload{item, qty}`, `CheckoutPayload`, `UnknownPayload`)
- `IntentType` — enum: `sellItem`, `checkout`, `unknown`
- `UserRole` — enum: `barista`, `spv`, `owner`

### Hak Akses Berdasarkan Peran

| Peran   | Intent yang Diizinkan   |
|---------|------------------------|
| barista | AddItem, Checkout       |
| spv     | Stock, Closing          |
| owner   | ReadOnly                |

## Perintah Umum

```bash
# Mengambil dependensi
dart pub get

# Menjalankan aplikasi
dart run lib/main.dart

# Menjalankan dari entry point bin (lama, ada masalah)
dart run bin/homeai_voice.dart

# Menganalisis kode
dart analyze
```

## Konvensi

- **Pencampuran bahasa:** Identifier dan struktur kode dalam bahasa Inggris. String yang ditampilkan ke pengguna dan beberapa komentar dalam bahasa Indonesia (contoh: "jual" = sell, "bayar" = pay, "Berhasil" = success, "AKSES_DITOLAK" = access denied).
- **Gaya commit:** Conventional commits — `feat(scope):`, `refactor(scope):`, dll.
- **Dependency injection:** DI berbasis constructor di seluruh kode (coordinator, executor, dll.).
- **Penandaan error:** Error dilempar sebagai `Exception` dengan kode berprefix (contoh: `ERP_SALES_INVOICE_FAILED`).
- **Belum ada test:** Belum ada direktori `test/` maupun dependensi testing.
- **Belum ada konfigurasi linting:** Belum ada `analysis_options.yaml`.
- **Belum ada .gitignore:** Belum ada file ignore.
- **Belum ada file environment:** Kredensial ERP (`baseUrl`, `apiKey`, `apiSecret`) dikirim via constructor, tidak dimuat dari env.

## Integrasi ERP

`ERPClient` terhubung ke instance ERPNext:

- **Endpoint:** `POST {baseUrl}/api/resource/Sales Invoice`
- **Auth:** `Authorization: token {apiKey}:{apiSecret}`
- **Payload:** JSON dengan `customer`, `items[]` (item_code, qty), `payments[]` (mode_of_payment, amount)
- **Customer:** Di-hardcode ke "Walk-in Customer"
- **Harga:** Dihitung otomatis oleh ERP (amount: 0)

## Keterbatasan / Utang Teknis

- `IntentParser` menggunakan pencocokan kata kunci yang di-hardcode — belum ada NLP
- Nama item ("kopi susu") dan kuantitas di-hardcode di parser
- ID Intent berupa integer acak (0-999999), bukan UUID
- `bin/homeai_voice.dart` memiliki kode di luar `main()` (baris 16-19)
- `role_gatekeeper.dart` mereferensikan tipe (`AddItemIntent`, `StockIntent`, dll.) yang tidak ada di codebase — tidak bisa dikompilasi
- `IntentExecutor` ada sebagai class konkret (`lib/intent/intent_executor.dart`) dan kontrak abstrak (`lib/intent/intent_contract.dart`) dengan signature yang berbeda
- `VoiceCommandCoordinator` memanggil `parser.parseCommand()` tapi nama method-nya `parser.parse()`
- `ERPClient` tidak mengimplementasi `IntentPort` tapi dikirim ke `IntentExecutor` yang mengharapkan `IntentPort`
- Package `http` di-import tapi tidak dideklarasikan di dependensi `pubspec.yaml`
- Nama file auth context memiliki spasi di akhir (`auth_context .dart`)
