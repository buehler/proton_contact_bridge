import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:proton_contact_bridge/logger.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/ui/pages/boot.dart';
import 'package:proton_contact_bridge/ui/pages/contacts/detail.dart';
import 'package:proton_contact_bridge/ui/pages/contacts/edit.dart';
import 'package:proton_contact_bridge/ui/pages/contacts/list.dart';
import 'package:proton_contact_bridge/ui/pages/groups/detail.dart';
import 'package:proton_contact_bridge/ui/pages/groups/list.dart';
import 'package:proton_contact_bridge/ui/pages/login/human_verification.dart';
import 'package:proton_contact_bridge/ui/pages/login/login_credentials.dart';
import 'package:proton_contact_bridge/ui/pages/login/two_factor_auth.dart';
import 'package:proton_contact_bridge/ui/pages/settings.dart';
import 'package:proton_contact_bridge/ui/shells/login.dart';
import 'package:proton_contact_bridge/ui/shells/main.dart';
import 'package:proton_go_api_bridge/models/auth/auth_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:talker_flutter/talker_flutter.dart';

part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this.ref) {
    ref.listen(protonAuthProvider, (_, _) {
      notifyListeners();
    }, fireImmediately: true);
  }

  final Ref ref;
}

@riverpod
RouterRefreshNotifier routerRefreshNotifier(Ref ref) =>
    RouterRefreshNotifier(ref);

@riverpod
GoRouter router(Ref ref) => GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/boot',
  observers: [TalkerRouteObserver(talkerInstance)],
  refreshListenable: ref.watch(routerRefreshProvider),
  routes: [
    GoRoute(
      path: '/logs',
      builder: (_, _) => TalkerScreen(talker: talkerInstance),
    ),
    GoRoute(
      path: '/boot',
      builder: (context, state) => const BootPage(),
      redirect: (context, state) {
        final auth = ref.read(protonAuthProvider);

        if (auth.isLoading) {
          return null;
        }

        if (auth.hasError) {
          return '/login';
        }

        switch (auth.value) {
          case Authenticated():
            return '/contacts';
          case Unauthenticated():
          case Error():
            return '/login';
          default:
            return null;
        }
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainShell(child: navigationShell),
      redirect: (context, state) {
        final authState = ref.read(protonAuthProvider).value;

        if (authState is! Authenticated) {
          return '/login';
        }

        return null;
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/contacts',
              pageBuilder: (context, state) =>
                  NoTransitionPage(child: ContactsPage()),
              routes: [
                GoRoute(
                  path: 'new',
                  parentNavigatorKey: _rootNavigatorKey,
                  pageBuilder: (context, state) => MaterialPage<void>(
                    key: state.pageKey,
                    child: ContactEditPage(),
                  ),
                ),
                GoRoute(
                  path: ':contactId',
                  pageBuilder: (context, state) => MaterialPage<void>(
                    key: state.pageKey,
                    child: ContactDetailPage(
                      contactId: state.pathParameters['contactId'] ?? 'N/A',
                    ),
                  ),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      parentNavigatorKey: _rootNavigatorKey,
                      pageBuilder: (context, state) => MaterialPage<void>(
                        key: state.pageKey,
                        child: ContactEditPage(
                          contactId: state.pathParameters['contactId'] ?? 'N/A',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/groups',
              pageBuilder: (context, state) =>
                  NoTransitionPage(child: GroupsPage()),
              routes: [
                GoRoute(
                  path: ':groupName',
                  pageBuilder: (context, state) => MaterialPage<void>(
                    key: state.pageKey,
                    child: GroupDetailPage(
                      groupName: state.pathParameters['groupName'] ?? 'N/A',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
    ShellRoute(
      builder: (context, state, child) => LoginShell(child: child),
      routes: [
        GoRoute(
          path: '/login',
          redirect: (context, state) {
            final auth = ref.read(protonAuthProvider);
            final currentLocation = state.matchedLocation;
            final isLoginStage =
                currentLocation == '/login/credentials' ||
                currentLocation == '/login/captcha' ||
                currentLocation == '/login/2fa';

            if (auth.isLoading) return '/boot';
            if (auth.hasError) {
              return isLoginStage ? null : '/login/credentials';
            }

            final target = switch (auth.value) {
              Authenticated() => '/contacts',
              RequireHumanVerification() => '/login/captcha',
              RequireTwoFactor() => '/login/2fa',
              Unauthenticated() => '/login/credentials',
              Error() => isLoginStage ? currentLocation : '/login/credentials',
              _ => '/boot',
            };

            return currentLocation == target ? null : target;
          },
          routes: [
            GoRoute(
              path: 'credentials',
              builder: (context, state) => const LoginCredentialsPage(),
            ),
            GoRoute(
              path: 'captcha',
              builder: (context, state) => const HumanVerificationPage(),
            ),
            GoRoute(
              path: '2fa',
              builder: (context, state) => const TwoFactorAuthPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
