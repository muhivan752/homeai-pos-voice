abstract class IntentExecutor {
  bool canHandle(Intent intent);
  Future<void> execute(Intent intent);
}