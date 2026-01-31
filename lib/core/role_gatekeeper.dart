bool allowIntent(UserRole role, Intent intent) {
  if (role == UserRole.barista) {
    return intent is AddItemIntent || intent is CheckoutIntent;
  }
  if (role == UserRole.spv) {
    return intent is StockIntent || intent is ClosingIntent;
  }
  if (role == UserRole.owner) {
    return intent is ReadOnlyIntent;
  }
  return false;
}