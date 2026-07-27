import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_providers.dart';
import 'business_setup_screen.dart';
import 'main_shell.dart';
import 'pin_screens.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final businessRepo = ref.read(businessRepositoryProvider);
    final authRepo = ref.read(authRepositoryProvider);

    final profile = await businessRepo.getProfile();
    if (!mounted) return;

    if (profile == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const BusinessSetupScreen()),
      );
      return;
    }

    final hasPin = await authRepo.hasPin();
    if (!mounted) return;

    if (hasPin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PinLockScreen()),
      );
    } else {
      ref.read(appLockedProvider.notifier).state = false;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'BusinessOS',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Your Shop. Your Data. Always Available.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
