import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';

class ApplicationStatusPage extends StatefulWidget {
  final String role;

  const ApplicationStatusPage({required this.role, super.key});

  @override
  State<ApplicationStatusPage> createState() => _ApplicationStatusPageState();
}

class _ApplicationStatusPageState extends State<ApplicationStatusPage> {
  Map<String, dynamic>? _account;
  Map<String, dynamic>? _application;
  bool _isLoading = true;

  bool get _isSeller => widget.role.toLowerCase() == 'seller';

  @override
  void initState() {
    super.initState();
    _loadApplication();
  }

  Future<void> _loadApplication() async {
    final account = await DatabaseService.getCurrentAccount();
    final accountId = account?['account_id'] as String?;
    final application = accountId == null
        ? null
        : _isSeller
        ? await DatabaseService.getSellerApplicationByAccountId(accountId)
        : await DatabaseService.getRiderApplicationByAccountId(accountId);

    if (mounted) {
      setState(() {
        _account = account;
        _application = application;
        _isLoading = false;
      });
    }
  }

  Future<void> _logout() async {
    await AuthService.clearLoginSession();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  void _resubmit() {
    Navigator.pushNamed(
      context,
      _isSeller ? '/seller-registration' : '/rider-registration',
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isSeller ? 'Seller Application' : 'Rider Application';
    final status = _application?['status']?.toString() ?? 'Pending Review';
    final isRejected = status == 'Rejected';
    final isMissingApplication = _application == null;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F3),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        isRejected
                            ? Icons.cancel_outlined
                            : Icons.pending_actions,
                        color: isRejected
                            ? Colors.red
                            : const Color(0xFF2d8f4e),
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isMissingApplication
                            ? 'Your account is logged in, but your application details were not submitted yet.'
                            : isRejected
                            ? 'Your application was denied. Please resend your application for review.'
                            : 'Your application is waiting for admin approval.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      const SizedBox(height: 24),
                      _row(
                        'Name',
                        '${_account?['firstname'] ?? ''} ${_account?['surname'] ?? ''}'
                            .trim(),
                      ),
                      _row(
                        'Email',
                        Supabase.instance.client.auth.currentUser?.email ?? '',
                      ),
                      if (_isSeller && !isMissingApplication) ...[
                        _row('Shop', _application?['store_name'] ?? ''),
                        _row('Phone', _application?['contact_phone'] ?? ''),
                        _row('Location', _sellerLocation()),
                      ] else if (!_isSeller && !isMissingApplication) ...[
                        _row('License', _application?['license_number'] ?? ''),
                        _row('Vehicle', _application?['vehicle_type'] ?? ''),
                        _row('Plate', _application?['plate_number'] ?? ''),
                      ],
                      _row('Status', status),
                      if ((_application?['review_notes']
                              ?.toString()
                              .isNotEmpty ??
                          false))
                        _row(
                          isRejected ? 'Reason' : 'Admin Notes',
                          _application!['review_notes'].toString(),
                        ),
                      const SizedBox(height: 24),
                      if (isRejected || isMissingApplication)
                        ElevatedButton(
                          onPressed: _resubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2d8f4e),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(
                            isMissingApplication
                                ? 'Complete Application'
                                : 'Resubmit Application',
                          ),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _logout,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Log Out'),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    final display = value.trim().isEmpty ? 'N/A' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(display)),
        ],
      ),
    );
  }

  String _sellerLocation() {
    final parts =
        [
              _application?['house_number'],
              _application?['street'],
      _application?['barangay'],
      _application?['city'],
      _application?['province'],
      _application?['zip_code'],
    ]
            .whereType<String>()
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

    return parts.join(', ');
  }
}
