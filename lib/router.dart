import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/ui/pages/boot.dart';
import 'package:proton_contact_bridge/ui/pages/contacts/detail.dart';
import 'package:proton_contact_bridge/ui/pages/contacts/edit.dart';
import 'package:proton_contact_bridge/ui/pages/contacts/list.dart';
import 'package:proton_contact_bridge/ui/pages/favorites/list.dart';
import 'package:proton_contact_bridge/ui/pages/groups/detail.dart';
import 'package:proton_contact_bridge/ui/pages/groups/edit.dart';
import 'package:proton_contact_bridge/ui/pages/groups/list.dart';
import 'package:proton_contact_bridge/ui/pages/login/human_verification.dart';
import 'package:proton_contact_bridge/ui/pages/login/login_credentials.dart';
import 'package:proton_contact_bridge/ui/pages/login/two_factor_auth.dart';
import 'package:proton_contact_bridge/ui/shells/login.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'router.g.dart';

class RouterRefreshNotifier extends ChangeNotifier {
  RouterRefreshNotifier(this.ref) {
    ref.listen(protonAuthProvider, (_, _) {
      notifyListeners();
    });
  }

  final Ref ref;
}

@riverpod
RouterRefreshNotifier routerRefreshNotifier(Ref ref) =>
    RouterRefreshNotifier(ref);

@riverpod
GoRouter router(Ref ref) => GoRouter(
  debugLogDiagnostics: kDebugMode,
  initialLocation: '/boot',
  refreshListenable: ref.watch(routerRefreshProvider),
  redirect: (context, state) {
    return null;
  },
  routes: [
    GoRoute(
      path: '/boot',
      builder: (context, state) => const BootPage(),
      redirect: (context, state) {
        final authState = ref.read(protonAuthProvider).value;

        switch (authState) {
          case Authenticated():
            return '/contacts';
          case Unknown():
            return '/login';
          default:
            return null;
        }
      },
    ),
    ShellRoute(
      builder: (context, state, child) => LoginShell(child: child),
      routes: [
        GoRoute(
          path: '/login',
          redirect: (context, state) {
            final authState = ref.read(protonAuthProvider).value;

            if (authState is Authenticated) {
              return '/contacts';
            }

            if (authState case RequireHumanVerification(:final url)) {
              return '/login/captcha#$url';
            }

            if (authState case RequireTwoFactor()) {
              return '/login/2fa';
            }

            if (authState == null || authState is Unknown) {
              if (state.uri.path == '/login') {
                return '/login/credentials';
              }
            }

            return null;
          },
          routes: [
            GoRoute(
              path: 'credentials',
              builder: (context, state) => LoginCredentialsPage(),
            ),
            GoRoute(
              path: 'captcha',
              builder: (context, state) =>
                  HumanVerificationPage(captchaUrl: state.uri.fragment),
            ),
            GoRoute(
              path: '2fa',
              builder: (context, state) => TwoFactorAuthPage(),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/',
      redirect: (context, state) {
        final authState = ref.read(protonAuthProvider).value;

        if (authState is! Authenticated) {
          return '/login';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/contacts',
          builder: (context, state) => ContactsPage(),
          routes: [
            GoRoute(
              path: ':contactId',
              builder: (context, state) => ContactDetailPage(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => ContactEditPage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/groups',
          builder: (context, state) => GroupsPage(),
          routes: [
            GoRoute(
              path: ':groupId',
              builder: (context, state) => GroupDetailPage(),
              routes: [
                GoRoute(
                  path: 'edit',
                  builder: (context, state) => GroupEditPage(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/favorites',
          builder: (context, state) => FavoritesPage(),
        ),
      ],
    ),
  ],
);
