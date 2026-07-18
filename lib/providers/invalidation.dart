import 'package:proton_contact_bridge/providers/channels.dart';
import 'package:proton_contact_bridge/providers/contacts.dart';
import 'package:proton_contact_bridge/providers/groups.dart';
import 'package:proton_contact_bridge/providers/sync.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'invalidation.g.dart';

final _contactRelatedProviders = [
  allContactsProvider,
  contactProvider,
  searchContactsProvider,
  allGroupsProvider,
  groupContactsProvider,
];

@Riverpod(keepAlive: true)
void syncStatusProviderInvalidation(Ref ref) async {
  final cpService = await ref.watch(contactProviderChannelProvider.future);
  ContactSyncState? previous;
  ref.listen(contactSyncStateProvider, (prev, next) async {
    final current = next.value;

    if (previous == ContactSyncState.running &&
        current == ContactSyncState.idle) {
      for (var p in _contactRelatedProviders) {
        ref.invalidate(p);
      }
      await cpService.signalIfRequired();
    }

    previous = current;
  });
}
