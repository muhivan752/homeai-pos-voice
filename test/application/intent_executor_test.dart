import 'package:test/test.dart';
import '../../lib/application/intent_executor.dart';
import '../../lib/domain/domain.dart';
import '../mock_intent_port.dart';

void main() {
  late MockIntentPort mockPort;
  late IntentExecutor executor;

  setUp(() {
    mockPort = MockIntentPort();
    executor = IntentExecutor(mockPort);
  });

  tearDown(() {
    mockPort.reset();
  });

  group('IntentExecutor', () {
    group('addItem', () {
      test('executes addItem and returns success message', () async {
        final intent = Intent(
          id: '001',
          type: IntentType.addItem,
          payload: AddItemPayload(item: 'Kopi Susu', qty: 2),
        );

        final result = await executor.execute(intent);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('Kopi Susu'));
        expect(result.message, contains('x2'));
        expect(mockPort.logs, contains('addItem: Kopi Susu x2'));
      });

      test('returns error when port fails', () async {
        mockPort.shouldFail = true;
        mockPort.failMessage = 'Stock habis';

        final intent = Intent(
          id: '002',
          type: IntentType.addItem,
          payload: AddItemPayload(item: 'Latte', qty: 1),
        );

        expect(() => executor.execute(intent), throwsA(isA<MockPortError>()));
      });
    });

    group('removeItem', () {
      test('executes removeItem and returns success message', () async {
        final intent = Intent(
          id: '003',
          type: IntentType.removeItem,
          payload: RemoveItemPayload(item: 'Kopi Susu'),
        );

        final result = await executor.execute(intent);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('Kopi Susu'));
        expect(result.message, contains('dihapus'));
      });
    });

    group('changeQty', () {
      test('executes changeQty and returns success message', () async {
        final intent = Intent(
          id: '004',
          type: IntentType.changeQty,
          payload: ChangeQtyPayload(item: 'Es Teh', newQty: 5),
        );

        final result = await executor.execute(intent);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('Es Teh'));
        expect(result.message, contains('5'));
      });
    });

    group('clearCart', () {
      test('executes clearCart and returns success message', () async {
        final intent = Intent(
          id: '005',
          type: IntentType.clearCart,
          payload: ClearCartPayload(),
        );

        final result = await executor.execute(intent);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('dikosongkan'));
      });
    });

    group('undoLast', () {
      test('executes undoLast and returns success message', () async {
        final intent = Intent(
          id: '006',
          type: IntentType.undoLast,
          payload: UndoLastPayload(),
        );

        final result = await executor.execute(intent);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('Dibatalkan'));
      });
    });

    group('checkout', () {
      test('executes checkout and returns success message', () async {
        final intent = Intent(
          id: '007',
          type: IntentType.checkout,
          payload: CheckoutPayload(),
        );

        final result = await executor.execute(intent);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('berhasil'));
      });
    });

    group('readTotal', () {
      test('executes readTotal and returns formatted total', () async {
        final intent = Intent(
          id: '008',
          type: IntentType.readTotal,
          payload: ReadTotalPayload(),
        );

        final result = await executor.execute(intent);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('Total'));
        expect(result.message, contains('2 item'));
        expect(result.message, contains('Rp'));
      });
    });

    group('readCart', () {
      test('executes readCart and returns cart contents', () async {
        final intent = Intent(
          id: '009',
          type: IntentType.readCart,
          payload: ReadCartPayload(),
        );

        final result = await executor.execute(intent);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('Isi keranjang'));
        expect(result.message, contains('Kopi Susu'));
      });
    });

    group('help', () {
      test('returns help text', () async {
        final intent = Intent(
          id: '010',
          type: IntentType.help,
          payload: HelpPayload(),
        );

        final result = await executor.execute(intent);

        expect(result.isSuccess, isTrue);
        expect(result.message, contains('Perintah'));
        expect(result.message, contains('jual'));
        expect(result.message, contains('bayar'));
      });
    });

    group('unknown', () {
      test('returns error for unknown intent', () async {
        final intent = Intent(
          id: '011',
          type: IntentType.unknown,
          payload: UnknownPayload(),
        );

        final result = await executor.execute(intent);

        expect(result.isSuccess, isFalse);
        expect(result.message, contains('tidak paham'));
      });
    });
  });
}
