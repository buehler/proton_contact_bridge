import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:test/test.dart';

void main() {
  group('Contact.toProto', () {
    test('maps every field and preserves repeated field order', () {
      const contact = Contact(
        id: 'contact-id',
        formattedName: 'Jane Smith',
        name: ContactName(firstName: 'Jane', lastName: 'Smith'),
        isFavorite: true,
        gender: 'female',
        logos: [
          ContactImage(uri: 'logo-1'),
          ContactImage(uri: 'logo-2'),
        ],
        title: 'Product Manager',
        organization: 'Proton AG',
        photos: [
          ContactImage(uri: 'photo-1'),
          ContactImage(uri: 'photo-2'),
        ],
        emails: [
          ContactEmail(address: 'work@example.com', type: 'work'),
          ContactEmail(address: 'home@example.com'),
        ],
        phones: [
          ContactPhone(number: '+41 1', type: 'mobile'),
          ContactPhone(number: '+41 2'),
        ],
        addresses: [
          ContactAddress(
            street: 'Main Street 1',
            zip: '8000',
            city: 'Zurich',
            region: 'ZH',
            country: 'Switzerland',
            type: 'home',
          ),
        ],
        birthday: ContactDate(year: '1990', month: '4', day: '12'),
        anniversary: ContactDate(year: '2016', month: '5', day: '20'),
        notes: ['first note', 'second note'],
        urls: ['https://one.example', 'https://two.example'],
        roles: ['manager', 'maintainer'],
        groups: ['Friends', 'Work'],
      );

      final proto = contact.toProto();

      expect(proto.id, 'contact-id');
      expect(proto.formattedName, 'Jane Smith');
      expect(proto.name.firstName, 'Jane');
      expect(proto.name.lastName, 'Smith');
      expect(proto.isFavorite, isTrue);
      expect(proto.gender, 'female');
      expect(proto.logos.map((item) => item.uri), ['logo-1', 'logo-2']);
      expect(proto.title, 'Product Manager');
      expect(proto.organization, 'Proton AG');
      expect(proto.photos.map((item) => item.uri), ['photo-1', 'photo-2']);
      expect(proto.emails.map((item) => item.address), [
        'work@example.com',
        'home@example.com',
      ]);
      expect(proto.emails.first.type, 'work');
      expect(proto.emails.last.hasType(), isFalse);
      expect(proto.phones.map((item) => item.number), ['+41 1', '+41 2']);
      expect(proto.addresses.single.street, 'Main Street 1');
      expect(proto.birthday.year, '1990');
      expect(proto.anniversary.day, '20');
      expect(proto.notes, ['first note', 'second note']);
      expect(proto.urls, ['https://one.example', 'https://two.example']);
      expect(proto.roles, ['manager', 'maintainer']);
      expect(proto.groups, ['Friends', 'Work']);
    });

    test('keeps optional protobuf fields absent', () {
      const contact = Contact(
        id: '',
        formattedName: '',
        isFavorite: false,
        logos: [],
        photos: [],
        emails: [],
        phones: [],
        addresses: [],
        notes: [],
        urls: [],
        roles: [],
        groups: [],
      );

      final proto = contact.toProto();

      expect(proto.id, isEmpty);
      expect(proto.hasName(), isFalse);
      expect(proto.hasGender(), isFalse);
      expect(proto.hasTitle(), isFalse);
      expect(proto.hasOrganization(), isFalse);
      expect(proto.hasBirthday(), isFalse);
      expect(proto.hasAnniversary(), isFalse);
    });

    test('round trips through protobuf without losing data', () {
      const contact = Contact(
        id: 'id',
        formattedName: 'A Contact',
        name: ContactName(firstName: 'A', lastName: 'Contact'),
        isFavorite: false,
        gender: '',
        logos: [ContactImage(uri: 'data:image/png;base64,AA==')],
        title: '',
        organization: 'Org',
        photos: [ContactImage(uri: 'https://example.com/photo.png')],
        emails: [ContactEmail(address: 'a@example.com', type: '')],
        phones: [ContactPhone(number: '123', type: 'custom')],
        addresses: [
          ContactAddress(
            street: '',
            zip: '1',
            city: 'City',
            region: '',
            country: 'Country',
          ),
        ],
        birthday: ContactDate(year: '', month: '4', day: '12'),
        notes: ['note'],
        urls: ['site.example'],
        roles: ['role'],
        groups: ['group'],
      );

      expect(Contact.fromProto(contact.toProto()), contact);
    });
  });
}
