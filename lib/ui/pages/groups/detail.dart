import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proton_contact_bridge/providers/groups.dart';
import 'package:proton_contact_bridge/providers/sync.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/contact_list.dart';
import 'package:proton_contact_bridge/ui/components/message_state.dart';
import 'package:proton_contact_bridge/ui/components/safe_area.dart';
import 'package:proton_contact_bridge/ui/components/status_indicator.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class GroupDetailPage extends ConsumerWidget {
  final String groupName;

  const GroupDetailPage({super.key, required this.groupName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(groupContactsProvider(groupName: groupName));
    final normalizedGroupName = groupName.trim();
    final displayName = normalizedGroupName.isEmpty
        ? 'Unknown group'
        : normalizedGroupName;

    return ColoredBox(
      color: context.theme.canvas,
      child: KinCryptSafeArea(
        child: Column(
          children: [
            _GroupDetailHeader(
              groupName: displayName,
              contactCount: contacts.value?.length ?? 0,
            ),
            Divider(height: 1, color: context.theme.divider),
            Expanded(
              child: contacts.when(
                skipLoadingOnReload: true,
                data: (contacts) => ContactList(
                  contacts: contacts,
                  emptyMessage: 'No contacts in $displayName',
                ),
                loading: () =>
                    const Center(child: KinCryptActivityIndicator(size: 32)),
                error: (_, _) => const KinCryptMessageState(
                  icon: Icons.error_outline,
                  message: 'Could not load contacts',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDetailHeader extends ConsumerWidget {
  const _GroupDetailHeader({required this.groupName, this.contactCount = 0});

  final String groupName;
  final int contactCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = switch (ref.watch(contactSyncStateProvider)) {
      AsyncValue(value: ContactSyncState.running) => KinCryptSyncState.syncing,
      AsyncValue(value: ContactSyncState.idle) => KinCryptSyncState.synced,
      AsyncValue(value: ContactSyncState.offline) => KinCryptSyncState.offline,
      _ => KinCryptSyncState.failed,
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.theme.spaceSm,
        0,
        context.theme.spaceLg,
        context.theme.spaceLg,
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KinCryptIconButton(
                icon: LucideIcons.chevronLeft,
                semanticLabel: 'Back',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              SizedBox(width: context.theme.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KinCryptText(
                      groupName,
                      variant: KinCryptTextVariant.screenTitle,
                    ),
                    SizedBox(height: context.theme.spaceXs),
                    KinCryptSyncIndicator(state: syncState),
                  ],
                ),
              ),
            ],
          ),
          Center(
            child: KinCryptText(
              '$contactCount ${contactCount == 1 ? 'contact' : 'contacts'}',
            ),
          ),
        ],
      ),
    );
  }
}
