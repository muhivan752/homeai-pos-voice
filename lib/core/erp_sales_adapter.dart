class ErpSalesAdapter {
  void addItem({
    required String item,
    required int qty,
  }) {
    print('[ERP] add item: $item x $qty');
  }

  void checkout() {
    print('[ERP] checkout');
  }
}