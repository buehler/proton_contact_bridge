import 'dart:async';

import 'package:proton_contact_bridge/providers/channels.dart';
import 'package:proton_contact_bridge/providers/groups.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'contacts.g.dart';

@riverpod
Future<List<Contact>> allContacts(Ref ref) async {
  final api = await ref.watch(protonApiProvider.future);

  return api.getAllContacts();
}

@riverpod
Future<List<Contact>> searchContacts(Ref ref, String query) async {
  final api = await ref.watch(protonApiProvider.future);

  return query.trim().isEmpty
      ? api.getAllContacts()
      : api.searchContacts(query);
}

@riverpod
final class ContactNotifier extends _$ContactNotifier {
  static final _contactRelatedProviders = [
    allContactsProvider,
    searchContactsProvider,
    allGroupsProvider,
    groupContactsProvider,
  ];

  @override
  Future<Contact?> build([String? contactId]) async {
    final api = await ref.watch(protonApiProvider.future);
    return contactId == null ? null : api.getContactById(contactId);
  }

  Future<void> toggleIsFavorite() async {
    await state.maybeWhen(
      data: (contact) async {
        if (contact == null) return;

        final api = await ref.read(protonApiProvider.future);
        await api.toggleFavorite(contact.id);
        ref.invalidateSelf();
        for (var p in _contactRelatedProviders) {
          ref.invalidate(p);
        }
      },
      orElse: () {},
    );
  }

  Future<Contact> upsertContact(Contact contact) async {
    // Inserts use an unobserved contactProvider(null), so retain the notifier
    // until the mutation and its dependent invalidations are complete.
    final keepAlive = ref.keepAlive();
    try {
      final api = await ref.read(protonApiProvider.future);
      final cpService = await ref.read(contactProviderChannelProvider.future);
      final updatedContact = await api.upsertContact(contact);
      for (var p in _contactRelatedProviders) {
        ref.invalidate(p);
      }
      if (contact.id.isNotEmpty) {
        state = AsyncData(updatedContact);
      }
      unawaited(cpService.signalIfRequired());
      return updatedContact;
    } finally {
      keepAlive.close();
    }
  }

  Future<void> deleteContact() async {
    await state.maybeWhen(
      data: (contact) async {
        if (contact == null) return;

        final api = await ref.read(protonApiProvider.future);
        final cpService = await ref.read(contactProviderChannelProvider.future);
        await api.deleteContact(contact.id);
        ref.invalidateSelf();
        for (var p in _contactRelatedProviders) {
          ref.invalidate(p);
        }
        unawaited(cpService.signalIfRequired());
      },
      orElse: () {},
    );
  }
}
