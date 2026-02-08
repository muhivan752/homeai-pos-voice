import 'package:flutter/material.dart';
import '../core/auth_context.dart';
import '../core/service_provider.dart';
import 'login_screen.dart';

class PosHomeScreen extends StatefulWidget {
  final AuthContext auth;

  const PosHomeScreen({super.key, required this.auth});

  @override
  State<PosHomeScreen> createState() => _PosHomeScreenState();
}

class _PosHomeScreenState extends State<PosHomeScreen> {
  final _voiceController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _isProcessing = false;

  ServiceProvider get sp => ServiceProvider();

  @override
  void initState() {
    super.initState();
    _addSystemMessage('Selamat datang, ${widget.auth.username} (${widget.auth.role.name})!');
    _addSystemMessage('Ketik atau ucapkan perintah. Contoh: "jual kopi susu 2"');
  }

  @override
  void dispose() {
    _voiceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addSystemMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendCommand(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isProcessing = true;
    });
    _voiceController.clear();
    _scrollToBottom();

    final response = await sp.coordinator.handleVoice(text);

    setState(() {
      _isProcessing = false;
      // Clean response prefix
      final clean = response.replaceFirst(RegExp(r'^\[(OK|ERROR)\] '), '');
      final isError = response.startsWith('[ERROR]');
      _messages.add(_ChatMessage(text: clean, isUser: false, isError: isError));
    });
    _scrollToBottom();
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Voice'),
        backgroundColor: const Color(0xFF2C5F7C),
        foregroundColor: Colors.white,
        actions: [
          // Cart badge
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                onPressed: () => _showCart(),
              ),
              if (sp.db.cart.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${sp.db.cart.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'sync':
                  _sendCommand('sync');
                case 'report':
                  _sendCommand('laporan');
                case 'stock':
                  _sendCommand('cek stok');
                case 'logout':
                  _logout();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'sync', child: ListTile(leading: Icon(Icons.sync), title: Text('Sync Manual'))),
              const PopupMenuItem(value: 'report', child: ListTile(leading: Icon(Icons.bar_chart), title: Text('Laporan'))),
              const PopupMenuItem(value: 'stock', child: ListTile(leading: Icon(Icons.inventory), title: Text('Cek Stok'))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: Colors.red), title: Text('Logout'))),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isProcessing ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Memproses...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                final msg = _messages[index];
                return _buildChatBubble(msg);
              },
            ),
          ),

          // Quick action chips
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _buildChip('Jual kopi susu', Icons.coffee),
                _buildChip('Jual americano', Icons.local_cafe),
                _buildChip('Bayar cash', Icons.payments),
                _buildChip('Bayar qris', Icons.qr_code),
                _buildChip('Batal', Icons.cancel_outlined),
                _buildChip('Cek stok', Icons.inventory_2),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Input field
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, -2)),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _voiceController,
                    decoration: InputDecoration(
                      hintText: 'Ketik perintah...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onSubmitted: _sendCommand,
                  ),
                ),
                const SizedBox(width: 8),
                // Mic button (placeholder)
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF2C5F7C),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.mic, color: Colors.white),
                    onPressed: () {
                      // TODO: Integrate speech_to_text
                      if (_voiceController.text.isNotEmpty) {
                        _sendCommand(_voiceController.text);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(_ChatMessage msg) {
    final isUser = msg.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF2C5F7C)
              : msg.isError
                  ? Colors.red[50]
                  : Colors.grey[200],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isUser ? const Radius.circular(4) : null,
            bottomLeft: !isUser ? const Radius.circular(4) : null,
          ),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : msg.isError
                    ? Colors.red[700]
                    : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        avatar: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        onPressed: () => _sendCommand(label.toLowerCase()),
      ),
    );
  }

  void _showCart() {
    final cart = sp.db.cart;
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Keranjang', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (cart.isEmpty)
              const Text('Keranjang kosong', style: TextStyle(color: Colors.grey))
            else ...[
              ...cart.map((item) => ListTile(
                    title: Text(item['item'] as String),
                    trailing: Text('x${item['qty']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  )),
              const Divider(),
              Text(
                'Total: ${cart.fold<int>(0, (sum, e) => sum + (e['qty'] as int))} item',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  _ChatMessage({required this.text, required this.isUser, this.isError = false});
}
