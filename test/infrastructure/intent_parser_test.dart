import 'package:test/test.dart';
import '../../lib/infrastructure/intent_parser.dart';
import '../../lib/domain/domain.dart';

void main() {
  late IntentParser parser;

  setUp(() {
    parser = IntentParser();
  });

  group('IntentParser', () {
    group('addItem', () {
      test('parses "jual kopi susu 2"', () {
        final intent = parser.parse('jual kopi susu 2');
        expect(intent.type, equals(IntentType.addItem));

        final payload = intent.payload as AddItemPayload;
        expect(payload.item, equals('kopi susu'));
        expect(payload.qty, equals(2));
      });

      test('parses "tambah es teh" with default qty 1', () {
        final intent = parser.parse('tambah es teh');
        expect(intent.type, equals(IntentType.addItem));

        final payload = intent.payload as AddItemPayload;
        expect(payload.item, equals('es teh'));
        expect(payload.qty, equals(1));
      });

      test('parses "pesan americano 3"', () {
        final intent = parser.parse('pesan americano 3');
        expect(intent.type, equals(IntentType.addItem));

        final payload = intent.payload as AddItemPayload;
        expect(payload.qty, equals(3));
      });
    });

    group('removeItem', () {
      test('parses "batal kopi susu"', () {
        final intent = parser.parse('batal kopi susu');
        expect(intent.type, equals(IntentType.removeItem));

        final payload = intent.payload as RemoveItemPayload;
        expect(payload.item, equals('kopi susu'));
      });

      test('parses "hapus es teh"', () {
        final intent = parser.parse('hapus es teh');
        expect(intent.type, equals(IntentType.removeItem));
      });
    });

    group('changeQty', () {
      test('parses "kopi susu jadi 3"', () {
        final intent = parser.parse('kopi susu jadi 3');
        expect(intent.type, equals(IntentType.changeQty));

        final payload = intent.payload as ChangeQtyPayload;
        expect(payload.item, equals('kopi susu'));
        expect(payload.newQty, equals(3));
      });

      test('parses "ubah es teh 5"', () {
        final intent = parser.parse('ubah es teh 5');
        expect(intent.type, equals(IntentType.changeQty));
      });
    });

    group('clearCart', () {
      test('parses "kosongkan"', () {
        final intent = parser.parse('kosongkan');
        expect(intent.type, equals(IntentType.clearCart));
      });

      test('parses "hapus semua"', () {
        final intent = parser.parse('hapus semua');
        expect(intent.type, equals(IntentType.clearCart));
      });

      test('parses "batal semua"', () {
        final intent = parser.parse('batal semua');
        expect(intent.type, equals(IntentType.clearCart));
      });
    });

    group('undoLast', () {
      test('parses "undo"', () {
        final intent = parser.parse('undo');
        expect(intent.type, equals(IntentType.undoLast));
      });

      test('parses "batal tadi"', () {
        final intent = parser.parse('batal tadi');
        expect(intent.type, equals(IntentType.undoLast));
      });
    });

    group('checkout', () {
      test('parses "bayar"', () {
        final intent = parser.parse('bayar');
        expect(intent.type, equals(IntentType.checkout));
      });

      test('parses "checkout"', () {
        final intent = parser.parse('checkout');
        expect(intent.type, equals(IntentType.checkout));
      });

      test('parses "selesai"', () {
        final intent = parser.parse('selesai');
        expect(intent.type, equals(IntentType.checkout));
      });
    });

    group('readTotal', () {
      test('parses "total"', () {
        final intent = parser.parse('total');
        expect(intent.type, equals(IntentType.readTotal));
      });

      test('parses "berapa"', () {
        final intent = parser.parse('berapa');
        expect(intent.type, equals(IntentType.readTotal));
      });
    });

    group('readCart', () {
      test('parses "keranjang"', () {
        final intent = parser.parse('keranjang');
        expect(intent.type, equals(IntentType.readCart));
      });

      test('parses "isi keranjang"', () {
        final intent = parser.parse('isi keranjang');
        expect(intent.type, equals(IntentType.readCart));
      });
    });

    group('help', () {
      test('parses "bantuan"', () {
        final intent = parser.parse('bantuan');
        expect(intent.type, equals(IntentType.help));
      });

      test('parses "help"', () {
        final intent = parser.parse('help');
        expect(intent.type, equals(IntentType.help));
      });
    });

    group('unknown', () {
      test('returns unknown for unrecognized input', () {
        final intent = parser.parse('xyz abc 123');
        expect(intent.type, equals(IntentType.unknown));
      });
    });
  });
}
