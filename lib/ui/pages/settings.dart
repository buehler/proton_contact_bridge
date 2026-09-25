import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proton_contact_bridge/providers/channels.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/providers/settings.dart';
import 'package:proton_contact_bridge/providers/ui.dart';
import 'package:proton_contact_bridge/providers/user_info.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/components/bottomsheets.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/choice_control.dart';
import 'package:proton_contact_bridge/ui/components/list_row.dart';
import 'package:proton_contact_bridge/ui/components/safe_area.dart';
import 'package:proton_contact_bridge/ui/components/section.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_go_api_bridge/models/user/user_info.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  var _savingSortOrder = false;
  var _savingDisplayOrder = false;
  var _savingTheme = false;
  var _loggingOut = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userInfoProvider);
    final settings = ref.watch(settingsProvider);
    final themeMode = ref.watch(themeProvider);

    return KinCryptSafeArea(
      child: ListView(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.theme.spaceLg),
            child: const KinCryptText(
              'Settings',
              variant: KinCryptTextVariant.screenTitle,
            ),
          ),
          KinCryptSection(
            title: 'Account',
            children: user.when(
              data: (user) => [
                _AccountIdentity(user: user),
                Align(
                  alignment: Alignment.centerLeft,
                  child: KinCryptTextButton(
                    label: 'Log out',
                    icon: LucideIcons.logOut,
                    color: context.theme.danger,
                    enabled: !_loggingOut,
                    onPressed: _logout,
                  ),
                ),
              ],
              loading: () => const [_SettingsLoading(label: 'Loading account')],
              error: (_, _) => [
                _SettingsLoadError(
                  message: 'Could not load user info',
                  onRetry: () => ref.invalidate(userInfoProvider),
                ),
              ],
            ),
          ),
          KinCryptSection(
            title: 'Contacts',
            children: settings.when(
              data: (settings) => [
                _ChoiceSetting<ContactSortOrder>(
                  label: 'Sort contacts by',
                  description: 'Controls alphabetical grouping and list order.',
                  value: settings.sortOrder,
                  enabled: !_savingSortOrder,
                  choices: const [
                    KinCryptChoice(
                      value: ContactSortOrder.firstName,
                      label: 'First name',
                    ),
                    KinCryptChoice(
                      value: ContactSortOrder.lastName,
                      label: 'Last name',
                    ),
                  ],
                  onChanged: _setSortOrder,
                ),
                _ChoiceSetting<ContactDisplayOrder>(
                  label: 'Display names',
                  description: 'Controls how first and last names are shown.',
                  value: settings.displayOrder,
                  enabled: !_savingDisplayOrder,
                  choices: const [
                    KinCryptChoice(
                      value: ContactDisplayOrder.firstNameFirst,
                      label: 'First name first',
                    ),
                    KinCryptChoice(
                      value: ContactDisplayOrder.lastNameFirst,
                      label: 'Last name first',
                    ),
                  ],
                  onChanged: _setDisplayOrder,
                  footer: _ContactOrderPreview(settings: settings),
                ),
              ],
              loading: () => const [
                _SettingsLoading(label: 'Loading contact settings'),
              ],
              error: (_, _) => [
                _SettingsLoadError(
                  message: 'Could not load contact settings',
                  onRetry: () => ref.invalidate(settingsProvider),
                ),
              ],
            ),
          ),
          KinCryptSection(
            title: 'Theme',
            children: themeMode.when(
              data: (themeMode) => [
                KinCryptChoiceControl<ThemeMode>(
                  semanticLabel: 'Theme',
                  value: themeMode,
                  enabled: !_savingTheme,
                  choices: const [
                    KinCryptChoice(value: ThemeMode.light, label: 'Light'),
                    KinCryptChoice(value: ThemeMode.dark, label: 'Dark'),
                    KinCryptChoice(value: ThemeMode.system, label: 'System'),
                  ],
                  onChanged: _setThemeMode,
                ),
              ],
              loading: () => const [_SettingsLoading(label: 'Loading theme')],
              error: (_, _) => [
                _SettingsLoadError(
                  message: 'Could not load theme',
                  onRetry: () => ref.invalidate(themeProvider),
                ),
              ],
            ),
          ),
          if (Platform.isIOS)
            KinCryptSection(
              title: 'Contact Provider',
              children: [
                KinCryptButton(
                  label: 'Force provider sync',
                  style: KinCryptButtonStyle.secondary,
                  onPressed: () {
                    ref
                        .read(contactProviderChannelProvider)
                        .performLocalContactSync(true);
                  },
                ),
                KinCryptButton(
                  label: 'Reset contact provider',
                  style: KinCryptButtonStyle.dangerSoft,
                  onPressed: () {
                    ref
                        .read(contactProviderChannelProvider)
                        .resetContactProvider();
                  },
                ),
              ],
            ),
          KinCryptSection(
            title: 'Diagnostics',
            children: [
              KinCryptListRow(
                title: 'Logs',
                subtitle: 'Activity, API, and troubleshooting information',
                leading: const _SettingsIcon(icon: LucideIcons.logs),
                roundedEdges: true,
                showDisclosure: true,
                onTap: () => context.push('/logs'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _setSortOrder(ContactSortOrder value) async {
    if (_savingSortOrder) return;
    setState(() => _savingSortOrder = true);
    try {
      await ref.read(settingsProvider.notifier).setSortOrder(value);
    } catch (_) {
      _showSaveError();
    } finally {
      if (mounted) setState(() => _savingSortOrder = false);
    }
  }

  Future<void> _setDisplayOrder(ContactDisplayOrder value) async {
    if (_savingDisplayOrder) return;
    setState(() => _savingDisplayOrder = true);
    try {
      await ref.read(settingsProvider.notifier).setDisplayOrder(value);
    } catch (_) {
      _showSaveError();
    } finally {
      if (mounted) setState(() => _savingDisplayOrder = false);
    }
  }

  Future<void> _setThemeMode(ThemeMode value) async {
    if (_savingTheme) return;
    setState(() => _savingTheme = true);
    try {
      await ref.read(themeProvider.notifier).setMode(value);
    } catch (_) {
      _showSaveError();
    } finally {
      if (mounted) setState(() => _savingTheme = false);
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (_) => const KinCryptLogoutBottomSheet(),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      unawaited(
        ref.read(contactProviderChannelProvider).resetContactProvider(),
      );
      await ref.read(protonAuthProvider.notifier).logout();
      if (mounted) context.go('/login');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not log out')));
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  void _showSaveError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Could not save settings')));
  }
}

class _AccountIdentity extends StatelessWidget {
  const _AccountIdentity({required this.user});

  final UserInfo user;

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayname.trim().isNotEmpty
        ? user.displayname.trim()
        : user.username.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KinCryptText(displayName, variant: KinCryptTextVariant.listPrimary),
        SizedBox(height: context.theme.spaceXs),
        KinCryptText(
          user.email,
          variant: KinCryptTextVariant.meta,
          selectable: true,
        ),
      ],
    );
  }
}

class _ChoiceSetting<T> extends StatelessWidget {
  const _ChoiceSetting({
    required this.label,
    required this.description,
    required this.choices,
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.footer,
  });

  final String label;
  final String description;
  final List<KinCryptChoice<T>> choices;
  final T value;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      KinCryptText(label, variant: KinCryptTextVariant.listPrimary),
      SizedBox(height: context.theme.spaceXs),
      KinCryptText(description, variant: KinCryptTextVariant.meta),
      SizedBox(height: context.theme.spaceSm),
      KinCryptChoiceControl<T>(
        semanticLabel: label,
        choices: choices,
        value: value,
        enabled: enabled,
        onChanged: onChanged,
      ),
      if (footer case final footer?) ...[
        SizedBox(height: context.theme.spaceSm),
        footer,
      ],
    ],
  );
}

class _ContactOrderPreview extends StatelessWidget {
  const _ContactOrderPreview({required this.settings});

  final ContactSettings settings;

  @override
  Widget build(BuildContext context) {
    final contacts = [..._previewContacts]
      ..sort((left, right) {
        final leftValue = settings.sortOrder == ContactSortOrder.firstName
            ? left.firstName
            : left.lastName;
        final rightValue = settings.sortOrder == ContactSortOrder.firstName
            ? right.firstName
            : right.lastName;
        return leftValue.compareTo(rightValue);
      });
    final preview = contacts
        .map(
          (contact) =>
              settings.displayOrder == ContactDisplayOrder.firstNameFirst
              ? '${contact.firstName} ${contact.lastName}'
              : '${contact.lastName} ${contact.firstName}',
        )
        .join(' · ');

    return Container(
      padding: EdgeInsets.all(context.theme.spaceMd),
      decoration: BoxDecoration(
        color: context.theme.surfaceSoft,
        borderRadius: BorderRadius.circular(context.theme.controlRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const KinCryptText('List preview', variant: KinCryptTextVariant.meta),
          SizedBox(height: context.theme.spaceXs),
          KinCryptText(preview, variant: KinCryptTextVariant.meta),
        ],
      ),
    );
  }
}

class _PreviewContact {
  const _PreviewContact(this.firstName, this.lastName);

  final String firstName;
  final String lastName;
}

const _previewContacts = [
  _PreviewContact('Maya', 'Chen'),
  _PreviewContact('Anna', 'Keller'),
  _PreviewContact('Noah', 'Müller'),
];

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 36,
    height: 36,
    decoration: BoxDecoration(
      color: context.theme.selectedSurface,
      borderRadius: BorderRadius.circular(context.theme.controlRadius),
    ),
    child: Icon(icon, size: 18, color: context.theme.brandVault),
  );
}

class _SettingsLoading extends StatelessWidget {
  const _SettingsLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const KinCryptActivityIndicator(size: 16),
      SizedBox(width: context.theme.spaceSm),
      KinCryptText(label, color: context.theme.textMuted),
    ],
  );
}

class _SettingsLoadError extends StatelessWidget {
  const _SettingsLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      KinCryptText(message, color: context.theme.danger),
      SizedBox(height: context.theme.spaceSm),
      KinCryptTextButton(label: 'Retry', onPressed: onRetry),
    ],
  );
}
