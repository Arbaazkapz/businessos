import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'providers/app_providers.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/screens/pin_screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: ShopHisabApp()));
}

class ShopHisabApp extends ConsumerStatefulWidget {
  const ShopHisabApp({super.key});
  @override
  ConsumerState<ShopHisabApp> createState() => _ShopHisabAppState();
}

class _ShopHisabAppState extends ConsumerState<ShopHisabApp>
    with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  DateTime? _backgroundAt;
  bool _locking = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _backgroundAt = DateTime.now();
    if (state == AppLifecycleState.resumed && _backgroundAt != null) {
      final duration = DateTime.now().difference(_backgroundAt!);
      _backgroundAt = null;
      if (duration.inSeconds >= 30) _relock();
    }
  }

  Future<void> _relock() async {
    if (_locking || ref.read(appLockedProvider)) return;
    _locking = true;
    try {
      if (await ref.read(authRepositoryProvider).hasPin() &&
          mounted &&
          _navigator.currentState != null) {
        ref.read(appLockedProvider.notifier).state = true;
        await _navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => const PinLockScreen(returnToPrevious: true),
          ),
        );
      }
    } finally {
      _locking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'ShopHisab',
      navigatorKey: _navigator,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
