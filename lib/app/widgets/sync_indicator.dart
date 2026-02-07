import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';

class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, sync, _) {
        if (!sync.hasPending && sync.status == SyncStatus.idle) {
          return const SizedBox.shrink();
        }

        Color bgColor;
        Color iconColor;
        IconData icon;
        String text;

        switch (sync.status) {
          case SyncStatus.syncing:
            bgColor = Colors.blue.shade50;
            iconColor = Colors.blue;
            icon = Icons.sync;
            text = 'Sinkronisasi...';
            break;
          case SyncStatus.offline:
            bgColor = Colors.orange.shade50;
            iconColor = Colors.orange;
            icon = Icons.cloud_off;
            text = 'Offline - ${sync.pendingCount} transaksi pending';
            break;
          case SyncStatus.error:
            bgColor = Colors.red.shade50;
            iconColor = Colors.red;
            icon = Icons.error_outline;
            text = sync.lastError ?? 'Sync error';
            break;
          case SyncStatus.idle:
            if (sync.hasPending) {
              bgColor = Colors.amber.shade50;
              iconColor = Colors.amber.shade700;
              icon = Icons.pending;
              text = '${sync.pendingCount} transaksi belum sync';
            } else {
              return const SizedBox.shrink();
            }
            break;
        }

        return GestureDetector(
          onTap: () => _showSyncDialog(context, sync),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border(
                bottom: BorderSide(color: iconColor.withOpacity(0.3)),
              ),
            ),
            child: Row(
              children: [
                if (sync.status == SyncStatus.syncing)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: iconColor,
                    ),
                  )
                else
                  Icon(icon, size: 18, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (sync.status != SyncStatus.syncing)
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: iconColor,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSyncDialog(BuildContext context, SyncService sync) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              sync.isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: sync.isOnline ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Status Sinkronisasi'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusRow(
              label: 'Koneksi',
              value: sync.isOnline ? 'Online' : 'Offline',
              color: sync.isOnline ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 8),
            _StatusRow(
              label: 'Transaksi pending',
              value: '${sync.pendingCount}',
              color: sync.pendingCount > 0 ? Colors.amber.shade700 : Colors.green,
            ),
            if (sync.lastError != null) ...[
              const SizedBox(height: 8),
              _StatusRow(
                label: 'Error terakhir',
                value: sync.lastError!,
                color: Colors.red,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('TUTUP'),
          ),
          if (sync.pendingCount > 0)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                sync.syncNow();
              },
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('SYNC SEKARANG'),
            ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatusRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
