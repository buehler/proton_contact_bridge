import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_contact_bridge/ui/components/list_row.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_go_api_bridge/models/groups/group.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';

class GroupList extends ConsumerWidget {
  const GroupList({
    super.key,
    required this.groups,
    required this.emptyMessage,
    this.contactCounts,
  });

  final List<Group> groups;
  final String emptyMessage;
  final Map<String, int>? contactCounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (groups.isEmpty) {
      return _EmptyState(message: emptyMessage);
    }

    final groupedGroups = <String, List<Group>>{};

    for (final group in groups) {
      final name = group.name.trim();
      final letter = name.isEmpty ? '#' : name.substring(0, 1).toUpperCase();
      groupedGroups.putIfAbsent(letter, () => []).add(group);
    }

    for (final group in groupedGroups.values) {
      group.sort(
        (left, right) =>
            left.name.toLowerCase().compareTo(right.name.toLowerCase()),
      );
    }

    final sections = groupedGroups.entries.toList()
      ..sort((left, right) => left.key.compareTo(right.key));

    return RefreshIndicator(
      color: context.theme.brandSignal,
      backgroundColor: context.theme.surface,
      onRefresh: () async {
        final api = await ref.read(protonApiProvider.future);
        await api.startSync();
      },
      child: ListView(
        padding: EdgeInsets.symmetric(vertical: context.theme.spaceSm),
        children: [
          for (final section in sections) ...[
            KinCryptAlphabetHeader(label: section.key),
            for (final group in section.value)
              _GroupTile(
                group: group,
                contactCount: contactCounts?[group.name.trim()],
              ),
          ],
        ],
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group, this.contactCount});

  final Group group;
  final int? contactCount;

  @override
  Widget build(BuildContext context) {
    final name = group.name.trim();
    final displayName = name.isEmpty ? 'Unknown group' : name;
    final count = contactCount;

    return KinCryptListRow(
      title: displayName,
      subtitle: count == null
          ? null
          : '$count ${count == 1 ? 'contact' : 'contacts'}',
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.theme.selectedSurface,
          borderRadius: BorderRadius.circular(context.theme.controlRadius),
        ),
        child: Icon(
          LucideIcons.usersRound,
          size: 20,
          color: context.theme.brandSignal,
        ),
      ),
      showDisclosure: true,
      semanticLabel: count == null
          ? displayName
          : '$displayName, $count ${count == 1 ? 'contact' : 'contacts'}',
      onTap: () => context.push('/groups/${Uri.encodeComponent(group.name)}'),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.theme.surface,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(context.theme.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_off_outlined,
              size: 48,
              color: context.theme.textMuted,
            ),
            SizedBox(height: context.theme.spaceMd),
            KinCryptText(
              message,
              variant: KinCryptTextVariant.listPrimary,
              color: context.theme.textMuted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
