import 'package:flutter/material.dart';
import '../../infrastructure/auth/auth_context.dart';
import '../theme/pos_theme.dart';

/// Role selection screen - entry point for tablet POS.
///
/// Two modes:
/// - Customer: Large button, fast access to view cart
/// - Staff: Login with role selection
class RoleSelectionScreen extends StatelessWidget {
  final ValueChanged<AuthContext> onRoleSelected;

  const RoleSelectionScreen({
    super.key,
    required this.onRoleSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(PosTheme.paddingXLarge),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Title
                  const Icon(
                    Icons.point_of_sale,
                    size: 80,
                    color: PosTheme.primary,
                  ),
                  const SizedBox(height: PosTheme.paddingMedium),
                  Text(
                    'HomeAI POS',
                    style: PosTheme.displayMedium,
                  ),
                  const SizedBox(height: PosTheme.paddingSmall),
                  Text(
                    'Voice-Enabled Point of Sale',
                    style: PosTheme.bodyLarge.copyWith(
                      color: PosTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: PosTheme.paddingXLarge * 2),

                  // Mode selection
                  Row(
                    children: [
                      // Customer mode
                      Expanded(
                        child: _ModeCard(
                          title: 'Pelanggan',
                          subtitle: 'Lihat pesanan Anda',
                          icon: Icons.person,
                          color: PosTheme.customerAccent,
                          onTap: () => onRoleSelected(AuthContext.guest()),
                        ),
                      ),
                      const SizedBox(width: PosTheme.paddingLarge),

                      // Staff mode
                      Expanded(
                        child: _ModeCard(
                          title: 'Staff',
                          subtitle: 'Masuk sebagai staff',
                          icon: Icons.badge,
                          color: PosTheme.staffAccent,
                          onTap: () => _showStaffLogin(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showStaffLogin(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(PosTheme.radiusLarge),
        ),
      ),
      builder: (context) => _StaffLoginSheet(
        onLogin: (auth) {
          Navigator.of(context).pop();
          onRoleSelected(auth);
        },
      ),
    );
  }
}

/// Mode selection card.
class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
        child: Container(
          padding: const EdgeInsets.all(PosTheme.paddingXLarge),
          decoration: BoxDecoration(
            color: PosTheme.surface,
            borderRadius: BorderRadius.circular(PosTheme.radiusLarge),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 50, color: color),
              ),
              const SizedBox(height: PosTheme.paddingLarge),
              Text(
                title,
                style: PosTheme.headlineMedium.copyWith(color: color),
              ),
              const SizedBox(height: PosTheme.paddingSmall),
              Text(
                subtitle,
                style: PosTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Staff login bottom sheet.
class _StaffLoginSheet extends StatefulWidget {
  final ValueChanged<AuthContext> onLogin;

  const _StaffLoginSheet({required this.onLogin});

  @override
  State<_StaffLoginSheet> createState() => _StaffLoginSheetState();
}

class _StaffLoginSheetState extends State<_StaffLoginSheet> {
  UserRole _selectedRole = UserRole.barista;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: PosTheme.paddingLarge,
        right: PosTheme.paddingLarge,
        top: PosTheme.paddingLarge,
        bottom: MediaQuery.of(context).viewInsets.bottom + PosTheme.paddingLarge,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: PosTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: PosTheme.paddingLarge),

          // Title
          Text(
            'Masuk sebagai Staff',
            style: PosTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: PosTheme.paddingLarge),

          // Name input (optional, for demo)
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nama (opsional)',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: PosTheme.paddingMedium),

          // Role selection
          Text(
            'Pilih role:',
            style: PosTheme.labelLarge,
          ),
          const SizedBox(height: PosTheme.paddingSmall),
          Wrap(
            spacing: PosTheme.paddingSmall,
            children: [
              _RoleChip(
                role: UserRole.barista,
                selected: _selectedRole == UserRole.barista,
                onSelected: () => setState(() => _selectedRole = UserRole.barista),
              ),
              _RoleChip(
                role: UserRole.spv,
                selected: _selectedRole == UserRole.spv,
                onSelected: () => setState(() => _selectedRole = UserRole.spv),
              ),
              _RoleChip(
                role: UserRole.owner,
                selected: _selectedRole == UserRole.owner,
                onSelected: () => setState(() => _selectedRole = UserRole.owner),
              ),
            ],
          ),
          const SizedBox(height: PosTheme.paddingLarge),

          // Login button
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              widget.onLogin(AuthContext.staff(
                _selectedRole,
                userName: name.isNotEmpty ? name : null,
              ));
            },
            child: const Padding(
              padding: EdgeInsets.all(PosTheme.paddingSmall),
              child: Text('Masuk'),
            ),
          ),
          const SizedBox(height: PosTheme.paddingMedium),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final UserRole role;
  final bool selected;
  final VoidCallback onSelected;

  const _RoleChip({
    required this.role,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(role.displayName),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: PosTheme.primary.withOpacity(0.2),
      labelStyle: TextStyle(
        color: selected ? PosTheme.primary : PosTheme.textPrimary,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}
