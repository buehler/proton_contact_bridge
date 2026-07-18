import 'dart:async';

import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:proton_go_api_bridge/proton_go_api_bridge.dart';
import 'package:proton_go_api_bridge/src/executor.dart';
import 'package:proton_go_api_bridge/src/protobuf/bridge/bridge.pb.dart';
import 'package:proton_go_api_bridge/src/protobuf/commands/commands.pb.dart'
    as c;

extension ContactsApi on ProtonApi {
  Future<List<Contact>> getAllContacts() async {
    final result = await executeCommand(
      Command(contacts: c.Contacts(getAll: c.Contacts_GetAll())),
    );

    return result.contacts.getAll.contacts
        .map(Contact.fromProto)
        .toList(growable: false);
  }

  Future<List<Contact>> getFavoriteContacts() async {
    final result = await executeCommand(
      Command(contacts: c.Contacts(getFavorites: c.Contacts_GetFavorites())),
    );

    return result.contacts.getFavorites.contacts
        .map(Contact.fromProto)
        .toList(growable: false);
  }

  Future<Contact?> getContactById(String id) async {
    final result = await executeCommand(
      Command(
        contacts: c.Contacts(getById: c.Contacts_GetById(id: id)),
      ),
    );

    final getById = result.contacts.getById;
    return getById.hasContact() ? Contact.fromProto(getById.contact) : null;
  }

  Future<List<Contact>> searchContacts(String query) async {
    final result = await executeCommand(
      Command(
        contacts: c.Contacts(search: c.Contacts_Search(query: query)),
      ),
    );

    return result.contacts.search.contacts
        .map(Contact.fromProto)
        .toList(growable: false);
  }

  Future<Contact> upsertContact(Contact contact) => executeCommand(
    Command(
      contacts: c.Contacts(
        upsertContact: c.Contacts_UpsertContact(contact: contact.toProto()),
      ),
    ),
  ).then((r) => Contact.fromProto(r.contacts.upsertContact.contact));

  Future<void> deleteContact(String id) => executeCommand(
    Command(
      contacts: c.Contacts(deleteContact: c.Contacts_DeleteContact(id: id)),
    ),
  );
}
