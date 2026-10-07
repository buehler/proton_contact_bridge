import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/method_channels/contact_provider_channel.dart';
import 'package:proton_contact_bridge/providers/contacts.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:proton_go_api_bridge/models/auth/auth_state.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';

import 'store.dart';

class PreviewContactNotifier extends ContactNotifier {
  PreviewContactNotifier(this.store);
  final PreviewStore store;

  @override
  Future<Contact?> build([String? contactId]) =>
      store.query(store.contact(contactId));

  @override
  Future<void> toggleIsFavorite() async {
    final contact = state.value;
    if (contact != null) {
      store.save(contact.copyWith(isFavorite: !contact.isFavorite));
    }
  }

  @override
  Future<Contact> upsertContact(Contact contact) async => store.save(contact);

  @override
  Future<void> deleteContact() async {
    final contact = state.value;
    if (contact != null) store.delete(contact.id);
  }
}

class PreviewAuth extends ProtonAuth {
  PreviewAuth(this.initialState, {required this.rejectSubmission});
  final AuthState initialState;
  final bool rejectSubmission;

  @override
  Future<AuthState> build() async => initialState;

  Future<void> _submit() async {
    if (rejectSubmission) throw StateError('Simulated authentication failure');
    state = const AsyncData(AuthState.authenticated());
  }

  @override
  Future<void> login(String username, String password) => _submit();
  @override
  Future<void> submitTotp(String code) => _submit();
  @override
  Future<void> submitHumanVerification({
    required String token,
    required String method,
  }) => _submit();
  @override
  Future<void> logout() async {
    state = const AsyncData(AuthState.unauthenticated());
  }

  @override
  void reset() {
    state = AsyncData(initialState);
  }
}

class PreviewContactChannel extends ContactProviderChannel {
  @override
  Future<void> performLocalContactSync([bool force = false]) async {}
  @override
  Future<void> resetContactProvider() async {}
}
