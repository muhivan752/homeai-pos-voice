# CLAUDE.md

## Gambaran Proyek

**HomeAI POS Voice** adalah sistem Point of Sale (POS) berbasis suara bertenaga AI untuk kedai kopi. Seluruh interaksi utama dilakukan melalui voice command, dengan fallback touch/keyboard. Sistem ini dirancang **offline-first** — semua transaksi disimpan lokal dulu (SQLite), lalu di-sync ke backend untuk data collection & ML training.

**Status:** PoC lengkap — voice ordering, checkout, customer memory, laporan, tax, menu management.

**Visi:** Semua sistem kedepannya AI-based. Data transaksi dikumpulkan untuk training ML (smart upselling, prediksi stok, analisis pelanggan).

## Tech Stack

- **Bahasa:** Dart (SDK >=3.0.0 <4.0.0)
- **Framework:** Flutter (mobile app)
- **Database:** SQLite (via `sqflite`) — offline-first
- **Voice:** Google Speech-to-Text (via `speech_to_text`)
- **State Management:** Provider pattern
- **Package manager:** `flutter pub`
- **Key Dependencies:** `http`, `crypto`, `sqflite`, `path_provider`, `speech_to_text`, `provider`, `shared_preferences`, `mobile_scanner`, `intl`

## Arsitektur

### Arsitektur Saat Ini (v1 — Offline-First POS)

```
POS App (Flutter, offline-first)
        |
   SQLite (local storage)
        |
  [Sync Engine — currently targets ERPNext, akan diganti]
```

### Arsitektur Target (v2 — AI Data Pipeline)

```
  POS App (Flutter, offline-first, SQLite)
              |
        Background Sync
              |
        VPS (API sederhana)
              |
        Data Lake (untuk ML training)
```

**Perubahan kunci v1 → v2:**
- **Hapus ERPNext** — terlalu berat dan kompleks untuk kebutuhan ini
- **Sync ke VPS sendiri** — API REST sederhana di server sendiri
- **Tujuan sync** — kumpulkan data transaksi untuk training ML nanti
- **Data Lake** — penyimpanan jangka panjang untuk analisis & model training

### Alur Data

```
VoiceInput / TouchInput
        ↓
  SttCorrector (fix Google STT errors)
        ↓
  BaristaParser (NLP: keyword + fuzzy matching)
        ↓
  ParseResult (intent, product, qty, payment, customer)
        ↓
  VoiceProvider._executeBarista()
        ↓
  CartProvider / CustomerProvider (state update)
        ↓
  SQLite (persist transaction)
        ↓
  SyncEngine → VPS API (background, auto-retry)
```

## Struktur Proyek

```
lib/
  main.dart                              # Entry point: init services + MultiProvider setup
  app/
    pos_app.dart                         # MaterialApp root (routing: Login vs POS)
    │
    ├── models/
    │   ├── product.dart                 # Product entity + sample seed data
    │   ├── cart_item.dart               # Cart item (id, name, price, qty)
    │   └── customer.dart                # Customer entity + FavoriteItem
    │
    ├── providers/
    │   ├── cart_provider.dart            # Shopping cart state + checkout logic
    │   ├── voice_provider.dart           # Voice input lifecycle + intent execution
    │   ├── product_provider.dart         # Product CRUD + category filter
    │   ├── customer_provider.dart        # Customer memory ("POS yang kenal pelanggan")
    │   └── tax_provider.dart             # PB1 10% + PPN 11% tax calculation
    │
    ├── services/
    │   ├── auth_service.dart             # Login/logout, SHA-256 password, SharedPrefs
    │   ├── barista_parser.dart           # Local NLP: voice → ParseResult (intent+product+qty)
    │   ├── barista_response.dart         # Fun barista-style response generator (Indonesian)
    │   ├── stt_corrector.dart            # Post-processor fix STT errors (concatenation, EN→ID)
    │   ├── erp_service.dart              # [LEGACY] ERPNext HTTP client — akan diganti VPS API
    │   └── sync_service.dart             # [LEGACY] Offline sync ke ERPNext — akan diganti VPS sync
    │
    ├── screens/
    │   ├── login_screen.dart             # Username/password login
    │   ├── pos_screen.dart               # Main POS: ProductGrid + Cart + Voice + Status
    │   ├── payment_screen.dart           # Payment method + amount + change calculator
    │   ├── receipt_screen.dart           # Thermal-style digital receipt (struk)
    │   ├── history_screen.dart           # Transaction history + pending sync list
    │   ├── transaction_detail_screen.dart # Detail transaksi + retry sync
    │   ├── report_screen.dart            # Sales report + date filter + CSV export
    │   └── menu_management_screen.dart   # CRUD produk (admin)
    │
    ├── widgets/
    │   ├── voice_button.dart             # Mic button (idle/listening/processing) + text fallback
    │   ├── cart_list.dart                # Cart items list + swipe-to-delete + qty spinner
    │   ├── product_grid.dart             # Product grid (responsive: 2-3 cols)
    │   ├── product_search.dart           # Live search products by name/alias
    │   ├── status_display.dart           # Status bar (voice state, barista msg, customer badge)
    │   ├── sync_indicator.dart           # Sync status badge + manual sync
    │   └── barcode_scanner.dart          # Camera barcode/QR scanner
    │
    ├── database/
    │   └── database_helper.dart          # SQLite manager (schema v6, migrations, CRUD)
    │
    └── theme/
        └── app_theme.dart                # Material Design 3 (light + dark)

core/                                     # [LEGACY] Old non-Flutter implementation — tidak dipakai
bin/
  demo.dart                               # CLI demo mode (tanpa Flutter)
```

## Fitur Utama

### 1. Voice Ordering (Barista Parser)
- **Input:** Voice command dalam bahasa Indonesia
- **NLP:** Keyword matching + fuzzy product matching (Levenshtein distance)
- **STT Corrector:** Fix Google errors ("susudua" → "susu dua", "coffee" → "kopi")
- **Contoh:** "jual kopi susu 2", "tambah latte", "batal americano"

### 2. Customer Memory System ("POS yang kenal pelanggan")
- **Identifikasi:** "gw Andi" / "nama saya Budi" → recognize atau register customer baru
- **Yang biasa:** "yang biasa" → auto-add top favorite ke cart (produk yang dipesan 2+ kali)
- **Tracking:** Visit count, last visit, linked transactions
- **Badge:** Customer badge tampil di StatusDisplay saat aktif
- **Checkout:** Otomatis link transaksi ke active customer + record visit

### 3. Tax System (PB1 + PPN)
- **PB1:** Pajak Restoran/Hiburan 10%
- **PPN:** Pajak Pertambahan Nilai 11%
- **Configurable:** On/off per jenis pajak, rate bisa diubah
- **Persisted:** Settings disimpan di SQLite

### 4. Checkout & Payment
- **Methods:** Cash, QRIS, Transfer, Card
- **Cash:** Hitung kembalian otomatis, quick amount buttons
- **Receipt:** Thermal-style digital struk (print & share)
- **Voice:** "bayar qris" / "checkout" via voice command

### 5. Reporting & History
- **Laporan:** Sales report + date filter (hari ini/kemarin/minggu/bulan/custom)
- **Metrics:** Total sales, transaction count, top products, tax breakdown
- **Export:** CSV via Share
- **History:** All transactions + pending sync list

### 6. Menu Management
- **CRUD:** Add/edit/delete produk dari SQLite
- **Categories:** drink, food, snack, other
- **Fields:** Name, price, category, barcode, aliases (untuk voice matching)

## Database Schema (SQLite v6)

| Table | Purpose |
|-------|---------|
| `users` | Cashier login (username, password_hash, name, role, is_active) |
| `products` | Product catalog (item_code, name, price, category, aliases, barcode) |
| `categories` | Product categories (food, drink, snack, other) |
| `transactions` | Sales orders (subtotal, taxes, total, payment_method, customer_id, sync_status) |
| `transaction_items` | Order line items (product_id, quantity, price, subtotal) |
| `customers` | Customer memory (name, phone, visit_count, last_visit_at) |
| `sync_queue` | Failed sync retry queue |
| `settings` | Key-value config store |

## Voice Commands (BaristaParser Intents)

| Intent | Contoh Voice Command | Action |
|--------|---------------------|--------|
| `addItem` | "jual kopi susu 2", "tambah latte" | Add product to cart |
| `checkout` | "bayar qris", "checkout", "bayar cash" | Process payment |
| `removeItem` | "batal americano", "hapus latte" | Remove from cart |
| `clearCart` | "batal semua", "kosongkan" | Clear entire cart |
| `identifyCustomer` | "gw Andi", "nama saya Budi" | Recognize/register customer |
| `orderBiasa` | "yang biasa", "pesanan biasa" | Auto-add customer favorites |
| `greeting` | "halo", "pagi" | Fun barista response |

## Auth System

- Password di-hash dengan SHA-256 (`package:crypto`)
- Login via UI form — voice login deprecated untuk keamanan
- Session persist via SharedPreferences

### Default Users

| Username  | Password    | Role    |
|-----------|-------------|---------|
| admin     | admin123    | admin   |
| barista1  | barista123  | barista |
| spv       | spv123      | spv     |

## Perintah Umum

```bash
# Mengambil dependensi
flutter pub get

# Menjalankan aplikasi Flutter
flutter run

# Menjalankan di device tertentu
flutter run -d <device_id>

# Menganalisis kode
flutter analyze

# Build APK
flutter build apk --release
```

## Konvensi

- **Bahasa kode:** Identifier dalam bahasa Inggris, string user-facing dalam bahasa Indonesia
- **Gaya commit:** Conventional commits — `feat(scope):`, `fix(scope):`, `refactor(scope):`, dll.
- **State management:** Provider pattern (ChangeNotifier + Consumer/context.read)
- **DI:** Constructor-based + singleton services (AuthService, SyncService, ErpService)
- **Offline-first:** Semua transaksi masuk SQLite dulu, sync ke backend belakangan
- **Error handling:** Try-catch di provider level, user-facing messages via StatusDisplay

## Known Issues / Technical Debt

- `lib/core/` — old non-Flutter implementation, masih ada tapi tidak dipakai
- `erp_service.dart` + `sync_service.dart` — masih target ERPNext, perlu diganti ke VPS API
- Voice login dihapus dari UI tapi parser masih support — cleanup needed
- No test suite yet

## Roadmap

### Short-term (Segera)
- [ ] Ganti ERPNext sync → VPS API sederhana (REST)
- [ ] Design VPS API schema untuk data collection
- [ ] Cleanup legacy `lib/core/` folder
- [ ] Tambah test suite (unit + widget tests)
- [ ] Tambah `analysis_options.yaml` untuk linting

### Medium-term (Setelah VPS ready)
- [ ] Data Lake setup di VPS untuk ML training data
- [ ] Upgrade parser ke LLM-based (conversational, bukan keyword matching)
- [ ] Smart upselling (AI suggest berdasarkan history pelanggan)
- [ ] Prediksi stok berdasarkan pattern penjualan
- [ ] Multi-modal input (voice + touch lebih seamless)

### Long-term (AI-based everything)
- [ ] Full AI barista (conversational ordering via LLM)
- [ ] Customer behavior analysis (ML model dari data lake)
- [ ] Dynamic pricing suggestions
- [ ] Inventory auto-reorder
- [ ] Multi-outlet support + centralized analytics
