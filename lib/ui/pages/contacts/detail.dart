import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proton_contact_bridge/providers/contacts.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/components/bottomsheets.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/chip.dart';
import 'package:proton_contact_bridge/ui/components/contact_avatar.dart';
import 'package:proton_contact_bridge/ui/components/message_state.dart';
import 'package:proton_contact_bridge/ui/components/section.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_contact_bridge/utils.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactDetailPage extends ConsumerStatefulWidget {
  final String contactId;

  const ContactDetailPage({super.key, required this.contactId});

  @override
  ConsumerState<ContactDetailPage> createState() => _ContactDetailPageState();
}

class _ContactDetailPageState extends ConsumerState<ContactDetailPage> {
  var _isUpdatingFavorite = false;
  var _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final contact = ref.watch(contactProvider(widget.contactId));

    return contact.when(
      loading: () => _scaffold(
        body: const Center(child: KinCryptActivityIndicator(size: 32)),
      ),
      error: (_, _) => _scaffold(
        body: const KinCryptMessageState(
          icon: Icons.error_outline,
          message: 'Could not load contact',
        ),
      ),
      data: (contact) {
        if (contact == null) {
          return _scaffold(
            body: const KinCryptMessageState(
              icon: Icons.person_off_outlined,
              message: 'Contact not found',
            ),
          );
        }

        final displayName = _displayName(contact);
        return _scaffold(
          contact: contact,
          body: _ContactContent(
            contact: contact,
            displayName: displayName,
            isDeleting: _isDeleting,
            onDelete: () => _confirmDelete(contact, displayName),
          ),
        );
      },
    );
  }

  Widget _scaffold({required Widget body, Contact? contact}) => Scaffold(
    backgroundColor: context.theme.surface,
    appBar: AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: context.theme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      leadingWidth: 64,
      leading: Padding(
        padding: EdgeInsets.only(left: context.theme.spaceSm),
        child: KinCryptIconButton(
          icon: LucideIcons.chevronLeft,
          semanticLabel: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      actions: [
        if (contact != null) ...[
          KinCryptIconButton(
            icon: contact.isFavorite ? Icons.star : LucideIcons.star,
            semanticLabel: contact.isFavorite
                ? 'Remove from favorites'
                : 'Add to favorites',
            style: KinCryptIconButtonStyle.brand,
            selected: contact.isFavorite,
            enabled: !_isUpdatingFavorite && !_isDeleting,
            onPressed: () => _toggleFavorite(contact),
          ),
          KinCryptTextButton(
            label: 'Edit',
            enabled: !_isDeleting,
            onPressed: () => context.push(
              '/contacts/${Uri.encodeComponent(widget.contactId)}/edit',
            ),
          ),
          SizedBox(width: context.theme.spaceSm),
        ],
      ],
    ),
    body: body,
  );

  Future<void> _toggleFavorite(Contact contact) async {
    setState(() => _isUpdatingFavorite = true);
    try {
      await ref
          .read(contactProvider(widget.contactId).notifier)
          .toggleIsFavorite();
    } catch (_) {
      if (mounted) {
        _showMessage(context, 'Could not update favorite.');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingFavorite = false);
      }
    }
  }

  Future<void> _confirmDelete(Contact contact, String displayName) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => KinCryptConfirmationBottomSheet(
        title: 'Delete $displayName?',
        message: 'This permanently deletes the contact from Proton and cannot be undone.',
        confirmLabel: 'Delete contact',
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await ref.read(contactProvider(contact.id).notifier).deleteContact();
      if (!mounted) {
        return;
      }
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/contacts');
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context, 'Could not delete contact.');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}

class _ContactContent extends StatelessWidget {
  const _ContactContent({
    required this.contact,
    required this.displayName,
    required this.isDeleting,
    required this.onDelete,
  });

  final Contact contact;
  final String displayName;
  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final emails = contact.emails
        .where((email) => email.address.trim().isNotEmpty)
        .toList();
    final phones = contact.phones
        .where((phone) => phone.number.trim().isNotEmpty)
        .toList();
    final addresses = contact.addresses
        .map((address) => (address: address, value: _addressText(address)))
        .where((entry) => entry.value.isNotEmpty)
        .toList();
    final notes = contact.notes
        .map((note) => note.trim())
        .where((note) => note.isNotEmpty)
        .toList();
    final otherRows = _otherRows(context);

    return ListView(
      padding: EdgeInsets.only(bottom: context.theme.spaceXxl),
      children: [
        _ContactIdentityHeader(contact: contact, displayName: displayName),
        if (emails.isNotEmpty)
          KinCryptSection(
            title: 'Emails',
            style: KinCryptSectionStyle.flat,
            children: [
              for (final email in emails)
                _ContactValueRow(
                  icon: LucideIcons.mail,
                  label: _optional(email.type),
                  value: email.address.trim(),
                  onTap: () => _launchEmail(context, email.address.trim()),
                  onCopy: () => _copyValue(
                    context,
                    email.address.trim(),
                    confirmation: 'Email address copied.',
                  ),
                  copyLabel: 'Copy email address',
                ),
            ],
          ),
        if (phones.isNotEmpty)
          KinCryptSection(
            title: 'Phones',
            style: KinCryptSectionStyle.flat,
            children: [
              for (final phone in phones)
                _ContactValueRow(
                  icon: LucideIcons.phone,
                  label: _optional(phone.type),
                  value: readablePhoneNumber(phone.number),
                  onTap: () => _launchPhone(context, phone.number),
                  onCopy: () => _copyPhoneNumber(context, phone.number),
                  copyLabel: 'Copy phone number',
                ),
            ],
          ),
        if (addresses.isNotEmpty)
          KinCryptSection(
            title: 'Addresses',
            style: KinCryptSectionStyle.flat,
            children: [
              for (final entry in addresses)
                _ContactValueRow(
                  icon: LucideIcons.mapPin,
                  label: _optional(entry.address.type),
                  value: entry.value,
                  onTap: () => _launchAddress(context, entry.value),
                  onCopy: () => _copyValue(
                    context,
                    entry.value,
                    confirmation: 'Address copied.',
                  ),
                  copyLabel: 'Copy address',
                ),
            ],
          ),
        if (notes.isNotEmpty)
          KinCryptSection(
            title: 'Notes',
            style: KinCryptSectionStyle.flat,
            children: [
              for (final note in notes)
                _ContactValueRow(
                  icon: LucideIcons.notebook,
                  value: note,
                  onCopy: () =>
                      _copyValue(context, note, confirmation: 'Note copied.'),
                  copyLabel: 'Copy note',
                ),
            ],
          ),
        if (otherRows.isNotEmpty)
          KinCryptSection(
            title: 'Other',
            style: KinCryptSectionStyle.flat,
            children: otherRows,
          ),
        KinCryptSection(
          title: 'Delete',
          style: KinCryptSectionStyle.flat,
          children: [
            KinCryptButton(
              label: 'Delete contact',
              icon: LucideIcons.trash,
              style: KinCryptButtonStyle.dangerSoft,
              stretch: true,
              loading: isDeleting,
              onPressed: onDelete,
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _otherRows(BuildContext context) {
    final rows = <Widget>[];
    final birthday = _formatDate(contact.birthday);
    final anniversary = _formatDate(contact.anniversary);

    void addPassive({
      required IconData icon,
      required String label,
      required String value,
    }) {
      final normalized = value.trim();
      if (normalized.isEmpty) {
        return;
      }
      rows.add(
        _ContactValueRow(
          icon: icon,
          label: label,
          value: normalized,
          onCopy: () =>
              _copyValue(context, normalized, confirmation: '$label copied.'),
          copyLabel: 'Copy ${label.toLowerCase()}',
        ),
      );
    }

    if (birthday.isNotEmpty) {
      addPassive(icon: LucideIcons.cake, label: 'Birthday', value: birthday);
    }
    if (anniversary.isNotEmpty) {
      addPassive(
        icon: LucideIcons.calendar,
        label: 'Anniversary',
        value: anniversary,
      );
    }
    for (final url in contact.urls.map((value) => value.trim())) {
      if (url.isEmpty) {
        continue;
      }
      rows.add(
        _ContactValueRow(
          icon: LucideIcons.globe,
          label: 'Website',
          value: url,
          onTap: () => _launchWebUrl(context, url),
          onCopy: () =>
              _copyValue(context, url, confirmation: 'Website copied.'),
          copyLabel: 'Copy website',
        ),
      );
    }
    addPassive(
      icon: LucideIcons.venusAndMars,
      label: 'Gender',
      value: contact.gender ?? '',
    );
    for (final role in contact.roles) {
      addPassive(icon: LucideIcons.briefcase, label: 'Role', value: role);
    }
    for (final logo in contact.logos) {
      final uri = logo.uri.trim();
      if (uri.isEmpty) {
        continue;
      }
      rows.add(
        _ContactValueRow(
          icon: LucideIcons.image,
          label: 'Logo',
          value: uri,
          onTap: () => _launchWebUrl(context, uri),
          onCopy: () =>
              _copyValue(context, uri, confirmation: 'Logo URL copied.'),
          copyLabel: 'Copy logo URL',
        ),
      );
    }
    return rows;
  }
}

class _ContactIdentityHeader extends StatelessWidget {
  const _ContactIdentityHeader({
    required this.contact,
    required this.displayName,
  });

  final Contact contact;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final title = _optional(contact.title);
    final organization = _optional(contact.organization);
    final groups = contact.groups
        .map((group) => group.trim())
        .where((group) => group.isNotEmpty)
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.theme.spaceXl,
        context.theme.spaceLg,
        context.theme.spaceXl,
        context.theme.spaceXl,
      ),
      child: Column(
        children: [
          ContactAvatar(
            contact: contact,
            displayName: displayName,
            radius: 40,
            initialsStyle: context.theme.sectionTitle,
          ),
          SizedBox(height: context.theme.spaceLg),
          KinCryptText(
            displayName,
            variant: KinCryptTextVariant.sectionTitle,
            textAlign: TextAlign.center,
          ),
          if (title != null) ...[
            SizedBox(height: context.theme.spaceXs),
            KinCryptText(title, textAlign: TextAlign.center),
          ],
          if (organization != null) ...[
            SizedBox(height: context.theme.spaceXs),
            KinCryptText(
              organization,
              color: context.theme.textMuted,
              textAlign: TextAlign.center,
            ),
          ],
          if (groups.isNotEmpty) ...[
            SizedBox(height: context.theme.spaceMd),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: context.theme.spaceSm,
              runSpacing: context.theme.spaceSm,
              children: [
                for (final group in groups)
                  KinCryptChip(
                    label: group,
                    selected: true,
                    onPressed: () =>
                        context.push('/groups/${Uri.encodeComponent(group)}'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactValueRow extends StatelessWidget {
  const _ContactValueRow({
    required this.icon,
    required this.value,
    this.label,
    this.onTap,
    this.onCopy,
    this.copyLabel,
  });

  final IconData icon;
  final String? label;
  final String value;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;
  final String? copyLabel;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.theme.surfaceSoft,
            borderRadius: BorderRadius.circular(context.theme.controlRadius),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: context.theme.brandVault),
        ),
        SizedBox(width: context.theme.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (label != null) ...[
                KinCryptLabel(label!),
                SizedBox(height: context.theme.spaceXs),
              ],
              KinCryptText(
                value,
                color: onTap == null
                    ? context.theme.textPrimary
                    : context.theme.brandVault,
              ),
            ],
          ),
        ),
        if (onCopy != null) ...[
          SizedBox(width: context.theme.spaceSm),
          KinCryptIconButton(
            icon: LucideIcons.copy,
            semanticLabel: copyLabel ?? 'Copy value',
            onPressed: onCopy,
          ),
        ],
      ],
    );

    if (onTap == null) {
      return content;
    }

    return Semantics(
      button: true,
      label: label == null ? value : '$label: $value',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: context.theme.selectedSurface,
          highlightColor: context.theme.selectedSurface,
          splashColor: context.theme.selectedSurface,
          focusColor: context.theme.selectedSurface,
          borderRadius: BorderRadius.circular(context.theme.controlRadius),
          child: content,
        ),
      ),
    );
  }
}

String _displayName(Contact contact) {
  final formattedName = contact.formattedName.trim();
  if (formattedName.isNotEmpty) {
    return formattedName;
  }

  final name = [contact.name?.firstName, contact.name?.lastName]
      .whereType<String>()
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .join(' ');
  return name.isNotEmpty ? name : 'Unknown contact';
}

String? _optional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _addressText(ContactAddress address) {
  final locality = [
    address.zip,
    address.city,
    address.region,
  ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
  return [
    address.street,
    locality,
    address.country,
  ].map((part) => part.trim()).where((part) => part.isNotEmpty).join('\n');
}

String _formatDate(ContactDate? date) {
  if (date == null) {
    return '';
  }

  final year = date.year.trim();
  final month = int.tryParse(date.month.trim());
  final day = int.tryParse(date.day.trim());
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  final dateParts = <String>[];
  if (month != null && month >= 1 && month <= 12) {
    dateParts.add(months[month - 1]);
  }
  if (day != null && day >= 1 && day <= 31) {
    dateParts.add('$day');
  }
  if (year.isNotEmpty && year != '0' && year != '0000') {
    dateParts.add(year);
  }
  return dateParts.join(' ');
}

Future<void> _launchEmail(BuildContext context, String address) =>
    _launch(context, Uri(scheme: 'mailto', path: address));

Future<void> _launchPhone(BuildContext context, String number) async {
  final actionValue = await actionablePhoneNumber(
    number,
    region: Localizations.localeOf(context).countryCode,
  );
  if (context.mounted) {
    await _launch(context, Uri(scheme: 'tel', path: actionValue));
  }
}

Future<void> _copyPhoneNumber(BuildContext context, String number) async {
  final actionValue = await actionablePhoneNumber(
    number,
    region: Localizations.localeOf(context).countryCode,
  );
  if (context.mounted) {
    await _copyValue(
      context,
      actionValue,
      confirmation: 'Phone number copied.',
    );
  }
}

Future<void> _copyValue(
  BuildContext context,
  String value, {
  required String confirmation,
}) async {
  try {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      _showMessage(context, confirmation);
    }
  } catch (_) {
    if (context.mounted) {
      _showMessage(context, 'Could not copy this value.');
    }
  }
}

Future<void> _launchAddress(BuildContext context, String address) async {
  final mapUri = Uri(
    scheme: 'geo',
    path: '0,0',
    queryParameters: {'q': address},
  );
  try {
    if (await canLaunchUrl(mapUri) &&
        await launchUrl(mapUri, mode: LaunchMode.platformDefault)) {
      return;
    }
  } catch (_) {
    // Fall through to the browser-based Maps URL.
  }
  if (context.mounted) {
    await _launch(
      context,
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': address,
      }),
    );
  }
}

Future<void> _launchWebUrl(BuildContext context, String value) {
  final parsed = Uri.tryParse(value);
  final uri = parsed != null && parsed.hasScheme
      ? parsed
      : Uri.tryParse('https://$value');
  if (uri == null) {
    _showLaunchError(context);
    return Future.value();
  }
  return _launch(context, uri);
}

Future<void> _launch(BuildContext context, Uri uri) async {
  try {
    if (await canLaunchUrl(uri) &&
        await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      return;
    }
  } catch (_) {
    // Report the same recoverable message as an unavailable destination.
  }
  if (context.mounted) {
    _showLaunchError(context);
  }
}

void _showLaunchError(BuildContext context) =>
    _showMessage(context, 'No app is available for this action.');

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
