import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/providers/contacts.dart';
import 'package:proton_contact_bridge/providers/groups.dart';
import 'package:proton_contact_bridge/providers/sync.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/components/group_list.dart';
import 'package:proton_contact_bridge/ui/components/safe_area.dart';
import 'package:proton_contact_bridge/ui/components/status_indicator.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class _GroupsPageHeader extends ConsumerWidget {
  const _GroupsPageHeader({required this.groupCount});

  final int groupCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = switch (ref.watch(contactSyncStateProvider)) {
      AsyncValue(value: ContactSyncState.running) => KinCryptSyncState.syncing,
      AsyncValue(value: ContactSyncState.idle) => KinCryptSyncState.synced,
      AsyncValue(value: ContactSyncState.offline) => KinCryptSyncState.offline,
      _ => KinCryptSyncState.failed,
    };

    return Padding(
      padding: EdgeInsets.only(
        left: context.theme.spaceLg,
        right: context.theme.spaceLg,
        bottom: context.theme.spaceLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Groups', style: context.theme.screenTitle),
          KinCryptSyncIndicator(state: syncState),
          Align(
            alignment: Alignment.center,
            child: KinCryptText('$groupCount groups'),
          ),
        ],
      ),
    );
  }
}

class GroupsPage extends ConsumerWidget {
  const GroupsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(allGroupsProvider);
    final contacts = ref.watch(allContactsProvider).value;
    Map<String, int>? contactCounts;

    if (contacts != null) {
      contactCounts = {};
      for (final contact in contacts) {
        for (final groupName
            in contact.groups
                .map((name) => name.trim())
                .where((name) => name.isNotEmpty)
                .toSet()) {
          contactCounts.update(
            groupName,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }

    return KinCryptSafeArea(
      child: Column(
        children: [
          _GroupsPageHeader(
            groupCount: groups.maybeWhen(
              data: (groups) => groups.length,
              orElse: () => 0,
            ),
          ),
          Divider(height: 1, color: context.theme.divider),
          Expanded(
            child: groups.when(
              skipLoadingOnReload: true,
              data: (groups) => GroupList(
                groups: groups,
                contactCounts: contactCounts,
                emptyMessage: 'No groups found',
              ),
              loading: () =>
                  const Center(child: KinCryptActivityIndicator(size: 32)),
              error: (_, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: context.theme.textMuted,
                    ),
                    SizedBox(height: context.theme.spaceMd),
                    Text(
                      'Could not load groups',
                      style: context.theme.listPrimary.copyWith(
                        color: context.theme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
