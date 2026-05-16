import 'package:flutter/material.dart';
import 'auth_service.dart';

/// Route protection types
enum RouteProtection {
  public, // No authentication required
  authenticated, // Just needs to be logged in
  adminOnly, // Admin role required
  sellerOnly, // Seller role required
  buyerOnly, // Buyer role required
  riderOnly, // Rider role required
}

/// Protected route wrapper to enforce access control
class ProtectedRoute extends StatefulWidget {
  final Widget child;
  final RouteProtection protection;
  final String? fallbackRoute;

  const ProtectedRoute({
    required this.child,
    this.protection = RouteProtection.authenticated,
    this.fallbackRoute = '/',
    super.key,
  });

  @override
  State<ProtectedRoute> createState() => _ProtectedRouteState();
}

class _ProtectedRouteState extends State<ProtectedRoute> {
  late Future<bool> _accessCheckFuture;

  @override
  void initState() {
    super.initState();
    _accessCheckFuture = _checkAccess();
  }

  Future<bool> _checkAccess() async {
    final isAuthenticated = AuthService.isAuthenticated();

    switch (widget.protection) {
      case RouteProtection.public:
        return true;

      case RouteProtection.authenticated:
        if (!isAuthenticated) {
          _redirectToLogin();
          return false;
        }
        return true;

      case RouteProtection.adminOnly:
        if (!isAuthenticated) {
          _redirectToLogin();
          return false;
        }
        final hasAccess = await AuthService.verifyAdminAccess();
        if (!hasAccess) {
          AuthService.logSecurityEvent(
            'UNAUTHORIZED_ACCESS',
            'Attempted to access admin-only route without admin permissions',
          );
          _redirectToHome();
          return false;
        }
        return true;

      case RouteProtection.sellerOnly:
        if (!isAuthenticated) {
          _redirectToLogin();
          return false;
        }
        final hasAccess = await AuthService.verifySellerAccess();
        if (!hasAccess) {
          AuthService.logSecurityEvent(
            'UNAUTHORIZED_ACCESS',
            'Attempted to access seller-only route without seller permissions',
          );
          _redirectToHome();
          return false;
        }
        return true;

      case RouteProtection.buyerOnly:
        if (!isAuthenticated) {
          _redirectToLogin();
          return false;
        }
        final hasAccess = await AuthService.verifyBuyerAccess();
        if (!hasAccess) {
          AuthService.logSecurityEvent(
            'UNAUTHORIZED_ACCESS',
            'Attempted to access buyer-only route without buyer permissions',
          );
          _redirectToHome();
          return false;
        }
        return true;

      case RouteProtection.riderOnly:
        if (!isAuthenticated) {
          _redirectToLogin();
          return false;
        }
        final hasAccess = await AuthService.verifyRiderAccess();
        if (!hasAccess) {
          AuthService.logSecurityEvent(
            'UNAUTHORIZED_ACCESS',
            'Attempted to access rider-only route without rider permissions',
          );
          _redirectToHome();
          return false;
        }
        return true;
    }
  }

  void _redirectToLogin() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      });
    }
  }

  void _redirectToHome() {
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final accountType = await AuthService.getCurrentUserType();
        final route = switch (accountType?.toLowerCase()) {
          'admin' => '/admin-dashboard',
          'seller' => '/seller-dashboard',
          'rider' => '/rider-dashboard',
          'buyer' => '/buyer-dashboard',
          _ => widget.fallbackRoute ?? '/login',
        };

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You do not have permission to access this page'),
            backgroundColor: Colors.red,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _accessCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !(snapshot.data ?? false)) {
          return const Scaffold(
            body: Center(child: Text('Unauthorized Access')),
          );
        }

        return widget.child;
      },
    );
  }
}
