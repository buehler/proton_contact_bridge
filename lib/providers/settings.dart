import 'package:proton_contact_bridge/providers/storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings.g.dart';

enum ContactSortOrder {
  firstName('first_name'),
  lastName('last_name');

  const ContactSortOrder(this.storageValue);

  final String storageValue;

  static ContactSortOrder fromStorage(String? value) => values.firstWhere(
    (order) => order.storageValue == value,
    orElse: () => ContactSettings.defaults.sortOrder,
  );
}

enum ContactDisplayOrder {
  firstNameFirst('first_name_first'),
  lastNameFirst('last_name_first');

  const ContactDisplayOrder(this.storageValue);

  final String storageValue;

  static ContactDisplayOrder fromStorage(String? value) => values.firstWhere(
    (order) => order.storageValue == value,
    orElse: () => ContactSettings.defaults.displayOrder,
  );
}

class ContactSettings {
  const ContactSettings({required this.sortOrder, required this.displayOrder});

  static const defaults = ContactSettings(
    sortOrder: ContactSortOrder.lastName,
    displayOrder: ContactDisplayOrder.firstNameFirst,
  );

  final ContactSortOrder sortOrder;
  final ContactDisplayOrder displayOrder;

  ContactSettings copyWith({
    ContactSortOrder? sortOrder,
    ContactDisplayOrder? displayOrder,
  }) => ContactSettings(
    sortOrder: sortOrder ?? this.sortOrder,
    displayOrder: displayOrder ?? this.displayOrder,
  );
}

@riverpod
class Settings extends _$Settings {
  @override
  Future<ContactSettings> build() async {
    final store = ref.watch(sharedPreferencesProvider);
    final values = await Future.wait([
      store.getString(StorageKeys.contactSortOrder.key),
      store.getString(StorageKeys.contactDisplayOrder.key),
    ]);

    return ContactSettings(
      sortOrder: ContactSortOrder.fromStorage(values[0]),
      displayOrder: ContactDisplayOrder.fromStorage(values[1]),
    );
  }

  Future<void> setSortOrder(ContactSortOrder sortOrder) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(sortOrder: sortOrder));

    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(StorageKeys.contactSortOrder.key, sortOrder.storageValue);
    } catch (_) {
      final latest = state.requireValue;
      if (latest.sortOrder == sortOrder) {
        state = AsyncData(latest.copyWith(sortOrder: current.sortOrder));
      }
      rethrow;
    }
  }

  Future<void> setDisplayOrder(ContactDisplayOrder displayOrder) async {
    final current = state.requireValue;
    state = AsyncData(current.copyWith(displayOrder: displayOrder));

    try {
      await ref
          .read(sharedPreferencesProvider)
          .setString(
            StorageKeys.contactDisplayOrder.key,
            displayOrder.storageValue,
          );
    } catch (_) {
      final latest = state.requireValue;
      if (latest.displayOrder == displayOrder) {
        state = AsyncData(latest.copyWith(displayOrder: current.displayOrder));
      }
      rethrow;
    }
  }
}
