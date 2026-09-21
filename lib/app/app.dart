import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/alarm/model/alarm_timer_controller.dart';
import '../features/calculator/model/calculator_controller.dart';
import '../features/expense/model/expense_controller.dart';
import '../features/schedule/model/schedule_controller.dart';
import '../pages/alarm/alarm_page.dart';
import '../pages/calculator/calculator_page.dart';
import '../pages/currency/currency_page.dart';
import '../pages/expense/expense_page.dart';
import '../pages/home/home_page.dart';
import '../pages/schedule/schedule_page.dart';
import '../pages/unit_converter/unit_converter_page.dart';
import '../pages/upload/upload_page.dart';
import '../pages/weather/weather_page.dart';
import '../shared/services/firestore_service.dart';
import '../shared/ui/layout/app_shell.dart';

/// Application DI + router wiring (app layer).
class AppBootstrap {
  AppBootstrap({required this.firebaseReady});

  final bool firebaseReady;

  FirestoreService? get firestore =>
      firebaseReady ? FirestoreService() : null;

  List<ChangeNotifierProvider> providers() => [
        ChangeNotifierProvider(
          create: (_) =>
              CalculatorController(firestore: firestore)..loadHistory(),
        ),
        ChangeNotifierProvider(create: (_) => AlarmTimerController()),
        ChangeNotifierProvider(
          create: (_) => ScheduleController(firestore: firestore)..load(),
        ),
        ChangeNotifierProvider(
          create: (_) => ExpenseController(firestore: firestore)..load(),
        ),
      ];

  GoRouter createRouter() {
    return GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppShell(child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const HomePage()),
            GoRoute(
              path: '/calculator',
              builder: (_, _) => const CalculatorPage(),
            ),
            GoRoute(
              path: '/currency',
              builder: (_, _) => const CurrencyPage(),
            ),
            GoRoute(
              path: '/weather',
              builder: (_, _) => const WeatherPage(),
            ),
            GoRoute(
              path: '/units',
              builder: (_, _) => const UnitConverterPage(),
            ),
            GoRoute(path: '/alarm', builder: (_, _) => const AlarmPage()),
            GoRoute(
              path: '/schedule',
              builder: (_, _) => const SchedulePage(),
            ),
            GoRoute(
              path: '/expense',
              builder: (_, _) => const ExpensePage(),
            ),
            GoRoute(
              path: '/upload',
              builder: (_, _) => UploadPage(firebaseReady: firebaseReady),
            ),
          ],
        ),
      ],
    );
  }
}
