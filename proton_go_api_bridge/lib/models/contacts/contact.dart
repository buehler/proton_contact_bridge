import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:proton_go_api_bridge/src/protobuf/models/models.pb.dart'
    as models;

part 'contact.freezed.dart';

@freezed
sealed class Contact with _$Contact {
  const Contact._();

  const factory Contact({
    required String id,
    required String formattedName,
    ContactName? name,
    required bool isFavorite,
    String? gender,
    required List<ContactImage> logos,
    String? title,
    String? organization,
    required List<ContactImage> photos,
    required List<ContactEmail> emails,
    required List<ContactPhone> phones,
    required List<ContactAddress> addresses,
    ContactDate? birthday,
    ContactDate? anniversary,
    required List<String> notes,
    required List<String> urls,
    required List<String> roles,
    required List<String> groups,
  }) = _Contact;

  factory Contact.fromProto(models.Contact proto) => Contact(
    id: proto.id,
    formattedName: proto.formattedName,
    name: proto.hasName() ? ContactName.fromProto(proto.name) : null,
    isFavorite: proto.isFavorite,
    gender: proto.hasGender() ? proto.gender : null,
    logos: proto.logos.map(ContactImage.fromProto).toList(),
    title: proto.hasTitle() ? proto.title : null,
    organization: proto.hasOrganization() ? proto.organization : null,
    photos: proto.photos.map(ContactImage.fromProto).toList(),
    emails: proto.emails.map(ContactEmail.fromProto).toList(),
    phones: proto.phones.map(ContactPhone.fromProto).toList(),
    addresses: proto.addresses.map(ContactAddress.fromProto).toList(),
    birthday: proto.hasBirthday()
        ? ContactDate.fromProto(proto.birthday)
        : null,
    anniversary: proto.hasAnniversary()
        ? ContactDate.fromProto(proto.anniversary)
        : null,
    notes: proto.notes.toList(),
    urls: proto.urls.toList(),
    roles: proto.roles.toList(),
    groups: proto.groups.toList(),
  );

  models.Contact toProto() => models.Contact(
    id: id,
    formattedName: formattedName,
    name: name?.toProto(),
    isFavorite: isFavorite,
    gender: gender,
    logos: logos.map((image) => image.toProto()),
    title: title,
    organization: organization,
    photos: photos.map((image) => image.toProto()),
    emails: emails.map((email) => email.toProto()),
    phones: phones.map((phone) => phone.toProto()),
    addresses: addresses.map((address) => address.toProto()),
    birthday: birthday?.toProto(),
    anniversary: anniversary?.toProto(),
    notes: notes,
    urls: urls,
    roles: roles,
    groups: groups,
  );
}

@freezed
sealed class ContactName with _$ContactName {
  const ContactName._();

  const factory ContactName({
    required String firstName,
    required String lastName,
  }) = _ContactName;

  factory ContactName.fromProto(models.Contact_Name proto) =>
      ContactName(firstName: proto.firstName, lastName: proto.lastName);

  models.Contact_Name toProto() =>
      models.Contact_Name(firstName: firstName, lastName: lastName);
}

@freezed
sealed class ContactImage with _$ContactImage {
  const ContactImage._();

  const factory ContactImage({required String uri}) = _ContactImage;

  factory ContactImage.fromProto(models.Contact_Image proto) =>
      ContactImage(uri: proto.uri);

  models.Contact_Image toProto() => models.Contact_Image(uri: uri);
}

@freezed
sealed class ContactEmail with _$ContactEmail {
  const ContactEmail._();

  const factory ContactEmail({required String address, String? type}) =
      _ContactEmail;

  factory ContactEmail.fromProto(models.Contact_Email proto) => ContactEmail(
    address: proto.address,
    type: proto.hasType() ? proto.type : null,
  );

  models.Contact_Email toProto() =>
      models.Contact_Email(address: address, type: type);
}

@freezed
sealed class ContactPhone with _$ContactPhone {
  const ContactPhone._();

  const factory ContactPhone({required String number, String? type}) =
      _ContactPhone;

  factory ContactPhone.fromProto(models.Contact_Phone proto) => ContactPhone(
    number: proto.number,
    type: proto.hasType() ? proto.type : null,
  );

  models.Contact_Phone toProto() =>
      models.Contact_Phone(number: number, type: type);
}

@freezed
sealed class ContactAddress with _$ContactAddress {
  const ContactAddress._();

  const factory ContactAddress({
    required String street,
    required String zip,
    required String city,
    required String region,
    required String country,
    String? type,
  }) = _ContactAddress;

  factory ContactAddress.fromProto(models.Contact_Address proto) =>
      ContactAddress(
        street: proto.street,
        zip: proto.zip,
        city: proto.city,
        region: proto.region,
        country: proto.country,
        type: proto.hasType() ? proto.type : null,
      );

  models.Contact_Address toProto() => models.Contact_Address(
    street: street,
    zip: zip,
    city: city,
    region: region,
    country: country,
    type: type,
  );
}

@freezed
sealed class ContactDate with _$ContactDate {
  const ContactDate._();

  const factory ContactDate({
    required String year,
    required String month,
    required String day,
  }) = _ContactDate;

  factory ContactDate.fromProto(models.Contact_Date proto) =>
      ContactDate(year: proto.year, month: proto.month, day: proto.day);

  models.Contact_Date toProto() =>
      models.Contact_Date(year: year, month: month, day: day);
}
