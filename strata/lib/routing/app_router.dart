import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:strata/screens/loading_screen.dart';
import 'package:strata/screens/pairing_screen.dart';
import 'package:strata/screens/main_layout.dart';
import 'package:strata/screens/scan_flow_screen.dart';
import 'package:strata/database/database_service.dart';

// ── Route path constants ────────────────────────────────────────────────────
class AppRoutes {
  AppRoutes._();

  static const String loading = '/loading';
  static const String pairing = '/pairing';
  static const String scan    = '/scan';
  static const String main    = '/';
}

// ── Router definition ───────────────────────────────────────────────────────
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.main,
  debugLogDiagnostics: true,
  routes: [
    GoRoute(
      path: AppRoutes.loading,
      name: 'loading',
      pageBuilder: (context, state) => _fadeTransition(
        key: state.pageKey,
        child: const LoadingScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.pairing,
      name: 'pairing',
      pageBuilder: (context, state) => _fadeTransition(
        key: state.pageKey,
        child: const PairingScreen(),
      ),
    ),
    GoRoute(
      path: AppRoutes.main,
      name: 'main',
      pageBuilder: (context, state) => _fadeTransition(
        key: state.pageKey,
        child: const MainLayout(),
      ),
    ),
    GoRoute(
      path: AppRoutes.scan,
      name: 'scan',
      // Slide up transition for full screen modally-styled flow
      pageBuilder: (context, state) {
        // Evaluate route configurations for Rescan pre-filling logic or View-Only
        final extras = state.extra as Map<String, dynamic>?;
        final plotName = extras?['plotName'] as String?;
        final soilType = extras?['soilType'] as String?;
        final scanRecord = extras?['scanRecord'] as ScanRecord?;
        final updateId = extras?['updateId'] as int?;

        return CustomTransitionPage<void>(
          key: state.pageKey,
          child: ScanFlowScreen(
            initialPlotName: plotName,
            initialSoilType: soilType,
            viewOnlyRecord: scanRecord,
            updateId: updateId,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(position: animation.drive(tween), child: child);
          },
        );
      },
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text(
        'Page not found: ${state.error}',
        style: const TextStyle(color: Colors.red),
      ),
    ),
  ),
);

// ── Shared fade transition helper ───────────────────────────────────────────
CustomTransitionPage<void> _fadeTransition({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 500),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
