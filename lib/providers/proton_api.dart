import 'package:dio/dio.dart';
import 'package:proton_contact_bridge/proton/contacts/proton_contacts_api.dart';
import 'package:proton_contact_bridge/proton/interceptors/auth_token.dart';
import 'package:proton_contact_bridge/providers/proton_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'proton_api.g.dart';

@riverpod
ProtonContacts protonContacts(Ref ref) =>
    ProtonContacts(ref.watch(authedProtonDioProvider));
