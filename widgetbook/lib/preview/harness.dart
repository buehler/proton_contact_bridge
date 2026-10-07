import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:proton_contact_bridge/providers/channels.dart';
import 'package:proton_contact_bridge/providers/contacts.dart';
import 'package:proton_contact_bridge/providers/groups.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/providers/settings.dart';
import 'package:proton_contact_bridge/providers/storage.dart';
import 'package:proton_contact_bridge/providers/sync.dart';
import 'package:proton_contact_bridge/providers/ui.dart';
import 'package:proton_contact_bridge/providers/user_info.dart';
import 'package:proton_contact_bridge/ui/foundation/theme.dart';
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
import 'package:proton_go_api_bridge/models/contacts/sync_progress.dart';
import 'package:proton_go_api_bridge/models/user/user_info.dart';
import 'package:widgetbook/widgetbook.dart';

import 'providers.dart';
import 'fixtures.dart';
import 'store.dart';
export 'store.dart' show PreviewState;

/// Shared by page use cases; fixture controls reset only this preview's scope.
Widget previewPage(
  BuildContext context, {
  required String location,
  PreviewState state = PreviewState.populated,
  AuthState auth = const AuthState.authenticated(),
  bool authenticationControls = false,
  bool contactControls = false,
  bool settingsControls = false,
  bool detailControls = false,
  bool groupControls = false,
  bool? startVerificationAutomatically,
}) {
  final favorite = detailControls
      ? context.knobs.boolean(label: 'Favorite', initialValue: true)
      : null;
  final groupName = groupControls
      ? context.knobs.string(
          label: 'Group name',
          initialValue: previewGroupName,
        )
      : previewGroupName;
  if (groupControls) location = '/groups/${Uri.encodeComponent(groupName)}';
  final reject =
      authenticationControls &&
      context.knobs.boolean(label: 'Reject submission');
  final sync = contactControls
      ? context.knobs.object.dropdown(
          label: 'Sync state',
          options: ContactSyncState.values,
          labelBuilder: (value) => value.name,
        )
      : ContactSyncState.idle;
  final sort = contactControls || settingsControls
      ? context.knobs.object.dropdown(
          label: 'Sort contacts by',
          options: ContactSortOrder.values,
          initialOption: ContactSortOrder.lastName,
          labelBuilder: (value) => value.name,
        )
      : ContactSortOrder.lastName;
  final display = contactControls || settingsControls
      ? context.knobs.object.dropdown(
          label: 'Display names',
          options: ContactDisplayOrder.values,
          labelBuilder: (value) => value.name,
        )
      : ContactDisplayOrder.firstNameFirst;
  final user = UserInfo(
    id: 'preview-user',
    username: 'preview',
    displayname: settingsControls
        ? context.knobs.string(label: 'Account name', initialValue: 'Maya Chen')
        : 'Maya Chen',
    email: settingsControls
        ? context.knobs.string(
            label: 'Account email',
            initialValue: 'maya@example.invalid',
          )
        : 'maya@example.invalid',
  );
  final configuration = (
    location,
    state,
    auth,
    reject,
    sync,
    sort,
    display,
    user,
    favorite,
    groupName,
    startVerificationAutomatically,
  );
  final host = context.findAncestorStateOfType<_PreviewHostState>();
  return PreviewHarness(
    key: host?.keyFor(configuration) ?? ValueKey(configuration),
    location: location,
    previewState: state,
    auth: auth,
    rejectSubmission: reject,
    syncState: sync,
    settings: ContactSettings(sortOrder: sort, displayOrder: display),
    user: user,
    settingsControls: settingsControls,
    favorite: favorite,
    groupName: groupName,
    startVerificationAutomatically: startVerificationAutomatically,
  );
}

/// Keeps the preview's state when Widgetbook rekeys the workbench for addons.
class PreviewHost extends StatefulWidget {
  const PreviewHost({super.key, required this.child});
  final Widget child;

  @override
  State<PreviewHost> createState() => _PreviewHostState();
}

class _PreviewHostState extends State<PreviewHost> {
  Object? configuration;
  GlobalKey previewKey = GlobalKey();

  GlobalKey keyFor(Object next) {
    if (configuration != next) {
      configuration = next;
      previewKey = GlobalKey();
    }
    return previewKey;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class PreviewHarness extends StatefulWidget {
  const PreviewHarness({
    super.key,
    required this.location,
    required this.previewState,
    required this.auth,
    required this.rejectSubmission,
    required this.syncState,
    required this.settings,
    required this.user,
    required this.settingsControls,
    required this.favorite,
    required this.groupName,
    this.startVerificationAutomatically,
  });

  final String location;
  final PreviewState previewState;
  final AuthState auth;
  final bool rejectSubmission;
  final ContactSyncState syncState;
  final ContactSettings settings;
  final UserInfo user;
  final bool settingsControls;
  final bool? favorite;
  final String groupName;
  final bool? startVerificationAutomatically;

  @override
  State<PreviewHarness> createState() => _PreviewHarnessState();
}

class _PreviewHarnessState extends State<PreviewHarness> {
  late final store = PreviewStore(
    widget.previewState,
    favorite: widget.favorite,
    groupName: widget.groupName,
  );
  late final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      if (widget.startVerificationAutomatically != null)
        humanVerificationUriProvider.overrideWith(
          (ref, rawUrl) => rawUrl == null || rawUrl.isEmpty
              ? null
              : Uri.https('www.google.com', '/'),
        ),
      protonApiProvider.overrideWith(
        (ref) =>
            throw StateError('API/database access is forbidden in Widgetbook'),
      ),
      nativePathChannelProvider.overrideWith(
        (ref) => throw StateError('Native paths are forbidden in Widgetbook'),
      ),
      sharedPreferencesProvider.overrideWithValue(store.preferences),
      contactProviderChannelProvider.overrideWith(
        (ref) => PreviewContactChannel(),
      ),
      groupMutationsProvider.overrideWithValue(store),
      allContactsProvider.overrideWith(
        (ref) => store.query([...store.contacts]),
      ),
      searchContactsProvider.overrideWith(
        (ref, query) => store.query(store.search(query)),
      ),
      contactProvider.overrideWith2((_) => PreviewContactNotifier(store)),
      allGroupsProvider.overrideWith((ref) => store.query(store.groups)),
      groupContactsProvider.overrideWith(
        (ref, args) => store.query(
          store.contacts
              .where(
                (contact) =>
                    contact.groups.contains(args.groupName ?? args.group?.name),
              )
              .toList(),
        ),
      ),
      protonAuthProvider.overrideWith(
        () =>
            PreviewAuth(widget.auth, rejectSubmission: widget.rejectSubmission),
      ),
      userInfoProvider.overrideWith(
        (ref) => Stream.fromFuture(
          widget.settingsControls
              ? store.query(widget.user)
              : Future.value(widget.user),
        ),
      ),
      settingsProvider.overrideWithBuild(
        (ref, notifier) => widget.settingsControls
            ? store.query(widget.settings)
            : Future.value(widget.settings),
      ),
      themeProvider.overrideWithBuild((ref, notifier) async {
        final mode = ThemeMode.values.byName(
          await store.preferences.getString(StorageKeys.themeMode.key) ??
              'light',
        );
        return widget.settingsControls ? store.query(mode) : mode;
      }),
      contactSyncStateProvider.overrideWith(
        (ref) => Stream.value(widget.syncState),
      ),
      contactSyncProgressProvider.overrideWith(
        (ref) => Stream.value(ContactSyncProgress(3, 10)),
      ),
      contactSyncStateWithProgressProvider.overrideWith(
        (ref) => Stream.value((widget.syncState, ContactSyncProgress(3, 10))),
      ),
      startContactSyncProvider.overrideWithValue(() async {
        store.changed();
      }),
      syncTriggerProvider.overrideWith((ref) {}),
    ],
  );
  final messengerKey = GlobalKey<ScaffoldMessengerState>();
  final rootKey = GlobalKey<NavigatorState>();
  late final router = _createRouter();
  Brightness? globalBrightness;

  @override
  void initState() {
    super.initState();
    store.changed = () {
      for (final provider in [
        allContactsProvider,
        searchContactsProvider,
        contactProvider,
        allGroupsProvider,
        groupContactsProvider,
      ]) {
        container.invalidate(provider);
      }
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = Theme.of(context).brightness;
    if (globalBrightness != brightness) {
      globalBrightness = brightness;
      store.preferences.setString(
        StorageKeys.themeMode.key,
        brightness == Brightness.dark ? 'dark' : 'light',
      );
      container.invalidate(themeProvider);
    }
  }

  @override
  void dispose() {
    router.dispose();
    container.dispose();
    super.dispose();
  }

  GoRouter _createRouter() => GoRouter(
    navigatorKey: rootKey,
    initialLocation: widget.location,
    routes: [
      GoRoute(path: '/boot', builder: (_, _) => const BootPage()),
      GoRoute(
        path: '/logs',
        redirect: (_, _) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              messengerKey.currentState?.showSnackBar(
                const SnackBar(
                  content: Text('Logs are excluded from Widgetbook.'),
                ),
              );
            }
          });
          return '/settings';
        },
      ),
      ShellRoute(
        builder: (_, _, child) => LoginShell(child: child),
        routes: [
          GoRoute(path: '/login', redirect: (_, _) => '/login/credentials'),
          GoRoute(
            path: '/login/credentials',
            builder: (_, _) => const LoginCredentialsPage(),
          ),
          GoRoute(
            path: '/login/2fa',
            builder: (_, _) => const TwoFactorAuthPage(),
          ),
          GoRoute(
            path: '/login/captcha',
            builder: (_, _) => HumanVerificationPage(
              startAutomatically:
                  widget.startVerificationAutomatically ?? false,
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, child) => MainShell(child: child),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/contacts',
                builder: (_, _) => const ContactsPage(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootKey,
                    builder: (_, _) => const ContactEditPage(),
                  ),
                  GoRoute(
                    path: ':contactId',
                    builder: (_, state) => ContactDetailPage(
                      contactId: state.pathParameters['contactId']!,
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootKey,
                        builder: (_, state) => ContactEditPage(
                          contactId: state.pathParameters['contactId']!,
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
                builder: (_, _) => const GroupsPage(),
                routes: [
                  GoRoute(
                    path: ':groupName',
                    builder: (_, state) => GroupDetailPage(
                      groupName: state.pathParameters['groupName']!,
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
                builder: (_, _) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          final mode =
              ref.watch(themeProvider).value ??
              (globalBrightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light);
          ref.listen(protonAuthProvider, (previous, next) {
            if (next.value is Authenticated &&
                previous?.hasValue == true &&
                previous?.value is! Authenticated) {
              router.go('/contacts');
            }
          });
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: messengerKey,
            routerConfig: router,
            themeMode: mode,
            theme: ThemeData(
              brightness: Brightness.light,
              extensions: [kinCryptLightTheme],
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              extensions: [kinCryptDarkTheme],
            ),
            builder: (_, child) => MediaQuery(data: mediaQuery, child: child!),
          );
        },
      ),
    );
  }
}
