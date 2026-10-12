import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/home/dashboard_screen.dart';
import '../screens/auth/role_login_screen.dart';
import '../screens/counter/counter_dashboard.dart';
import '../screens/counter/inventory_screen.dart';
import '../screens/counter/billing_screen.dart';
import '../screens/counter/shop_management_screen.dart';
import '../screens/counter/customers_screen.dart';
import '../screens/counter/history_screen.dart';
import '../screens/counter/accounts_screen.dart';
import '../screens/counter/upload_management_screen.dart';
import '../screens/counter/bill_customization_screen.dart';
import '../screens/counter/distributors_screen.dart';
import '../screens/counter/distributor_detail_screen.dart';
import '../screens/counter/add_purchase_bill_screen.dart';

import 'package:shared_preferences/shared_preferences.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);

final goRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/splash',
  redirect: (BuildContext context, GoRouterState state) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final isLoggedIn = token != null && token.isNotEmpty;
    
    final isLoginRoute = state.matchedLocation == '/role_login' || state.matchedLocation == '/splash' || state.matchedLocation == '/dashboard';

    // If not logged in and not on login/dashboard/splash, redirect to dashboard
    if (!isLoggedIn && !isLoginRoute) {
      return '/dashboard';
    }

    // If logged in and trying to access login/dashboard/splash, redirect to app
    if (isLoggedIn && isLoginRoute) {
      return '/counter/billing'; 
    }

    return null;
  },
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/role_login',
      builder: (context, state) {
        final Map<String, dynamic> extra = state.extra is Map<String, dynamic>
            ? state.extra as Map<String, dynamic>
            : {};
        return RoleLoginScreen(
          roleName: extra['roleName'] is String
              ? extra['roleName'] as String
              : 'Counter',
          themeColor: extra['themeColor'] is Color
              ? extra['themeColor'] as Color
              : Colors.green,
          nextRoute: extra['nextRoute'] is String
              ? extra['nextRoute'] as String
              : '/counter/billing',
        );
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return CounterDashboard(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/counter/billing',
              builder: (context, state) => const BillingScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/counter/inventory',
              builder: (context, state) => const InventoryScreen(),
              routes: [
                GoRoute(
                  path: 'upload',
                  builder: (context, state) => const UploadManagementScreen(),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/counter/shops',
              builder: (context, state) => const ShopManagementScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/counter/customers',
              builder: (context, state) => const CustomersScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/counter/accounts',
              builder: (context, state) => const AccountsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/counter/history',
              builder: (context, state) => const HistoryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/counter/settings',
              builder: (context, state) => const BillCustomizationScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/counter/distributors',
              builder: (context, state) => const DistributorsScreen(),
              routes: [
                GoRoute(
                  path: 'details',
                  builder: (context, state) => DistributorDetailScreen(distributor: state.extra as Map<String, dynamic>),
                ),
                GoRoute(
                  path: 'purchase',
                  builder: (context, state) => AddPurchaseBillScreen(distributor: state.extra as Map<String, dynamic>),
                ),
              ],
            ),
          ],
        ),
      ],
    ),

  ],
);
