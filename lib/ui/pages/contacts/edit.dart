import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_libphonenumber/flutter_libphonenumber.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proton_contact_bridge/providers/contacts.dart';
import 'package:proton_contact_bridge/providers/groups.dart';
import 'package:proton_contact_bridge/providers/storage.dart';
import 'package:proton_contact_bridge/ui/components/activity_indicator.dart';
import 'package:proton_contact_bridge/ui/components/bottomsheets.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/chip.dart';
import 'package:proton_contact_bridge/ui/components/list_row.dart';
import 'package:proton_contact_bridge/ui/components/message_state.dart';
import 'package:proton_contact_bridge/ui/components/safe_area.dart';
import 'package:proton_contact_bridge/ui/components/status_indicator.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/components/text_fields.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_contact_bridge/utils.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';
import 'package:proton_go_api_bridge/models/groups/group.dart';

class ContactEditPage extends ConsumerStatefulWidget {
  /// The contact ID to edit. If null, a new contact will be created.
  final String? contactId;

  const ContactEditPage({super.key, this.contactId});

  @override
  ConsumerState<ContactEditPage> createState() => _ContactEditPageState();
}

class _ContactEditPageState extends ConsumerState<ContactEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _organization = TextEditingController();
  final _title = TextEditingController();
  final _imagePicker = ImagePicker();

  final _emails = <_TypedValueDraft>[];
  final _phones = <_PhoneDraft>[];
  final _addresses = <_AddressDraft>[];
  final _notes = <_TextDraft>[];
  final _additionalFields = <_AdditionalFieldDraft>[];
  final _photos = <_MediaDraft>[];
  final _groups = <String>[];
  late final List<CountryWithPhoneCode> _phoneCountries;
  CountryWithPhoneCode? _preferredPhoneCountry;
  CountryWithPhoneCode? _localePhoneCountry;
  late final Future<void> _phoneCountryPreferenceReady;

  Contact? _sourceContact;
  ContactDate? _birthday;
  ContactDate? _anniversary;
  bool _initialized = false;
  bool _syncDisplayName = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _saveFailed = false;
  bool _identityInvalid = false;
  bool _allowPop = false;
  String? _initialDraftFingerprint;

  bool get _isEditing => widget.contactId != null;
  bool get _isBusy => _isSaving || _isDeleting;
  bool get _isDirty =>
      _initialized &&
      _initialDraftFingerprint != null &&
      _draftFingerprint != _initialDraftFingerprint;

  @override
  void initState() {
    super.initState();
    _phoneCountries = [...CountryManager().countries]
      ..sort((left, right) {
        final nameComparison = (left.countryName ?? left.countryCode).compareTo(
          right.countryName ?? right.countryCode,
        );
        return nameComparison != 0
            ? nameComparison
            : left.countryCode.compareTo(right.countryCode);
      });
    _localePhoneCountry = _countryByCode(
      WidgetsBinding.instance.platformDispatcher.locale.countryCode,
    );
    _phoneCountryPreferenceReady = _loadPreferredPhoneCountry();
    if (!_isEditing) {
      _initialize(null);
    }
  }

  @override
  void dispose() {
    _displayName.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _organization.dispose();
    _title.dispose();
    for (final draft in _emails) {
      draft.dispose();
    }
    for (final draft in _phones) {
      draft.dispose();
    }
    for (final draft in _addresses) {
      draft.dispose();
    }
    for (final draft in _notes) {
      draft.dispose();
    }
    for (final draft in _additionalFields) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEditing) {
      return _buildEditor(context);
    }

    final contact = ref.watch(contactProvider(widget.contactId));
    return contact.when(
      loading: () => _buildStateScaffold(
        title: 'Edit contact',
        child: const Center(child: KinCryptActivityIndicator(size: 32)),
      ),
      error: (_, _) => _buildStateScaffold(
        title: 'Edit contact',
        child: const KinCryptMessageState(
          icon: Icons.error_outline,
          message: 'Could not load contact',
        ),
      ),
      data: (contact) {
        if (contact == null) {
          return _buildStateScaffold(
            title: 'Edit contact',
            child: const KinCryptMessageState(
              icon: Icons.person_off_outlined,
              message: 'Contact not found',
            ),
          );
        }
        if (!_initialized) {
          _initialize(contact);
        }
        return _buildEditor(context);
      },
    );
  }

  Widget _buildStateScaffold({required String title, required Widget child}) {
    return Scaffold(
      backgroundColor: context.theme.surface,
      appBar: AppBar(
        backgroundColor: context.theme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: KinCryptText(title, variant: KinCryptTextVariant.listPrimary),
        centerTitle: true,
        leading: KinCryptIconButton(
          semanticLabel: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: LucideIcons.chevronLeft,
        ),
      ),
      body: child,
    );
  }

  Widget _buildEditor(BuildContext context) {
    final groupState = ref.watch(allGroupsProvider);
    return PopScope(
      canPop: _allowPop || (!_isBusy && !_isDirty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isBusy) _requestClose();
      },
      child: Scaffold(
        backgroundColor: context.theme.surface,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: context.theme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 92,
          leading: KinCryptTextButton(
            label: 'Cancel',
            enabled: !_isBusy,
            onPressed: _requestClose,
          ),
          title: KinCryptText(
            _isEditing ? 'Edit contact' : 'New contact',
            variant: KinCryptTextVariant.listPrimary,
          ),
          centerTitle: true,
          actions: [
            if (_isSaving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 23),
                child: Center(child: KinCryptActivityIndicator(size: 18)),
              )
            else
              KinCryptTextButton(
                label: 'Save',
                enabled: !_isBusy,
                onPressed: _save,
              ),
            SizedBox(width: context.theme.spaceSm),
          ],
        ),
        body: FocusTraversalGroup(
          policy: ReadingOrderTraversalPolicy(),
          child: AutofillGroup(
            child: Form(
              key: _formKey,
              onChanged: _onFormChanged,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  context.theme.spaceLg,
                  context.theme.spaceSm,
                  context.theme.spaceLg,
                  context.theme.spaceXxl +
                      MediaQuery.viewPaddingOf(context).bottom +
                      MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildAvatar(context),
                          SizedBox(height: context.theme.spaceSm),
                          Center(child: _buildDraftStatus()),
                          _buildIdentity(),
                          _buildTypedSections(),
                          _buildAddresses(),
                          _buildDates(),
                          _buildGroups(groupState),
                          _buildAdditionalFields(),
                          _buildNotes(),
                          if (_isEditing) _buildDeleteButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDraftStatus() {
    if (_isSaving) {
      return const KinCryptStatusIndicator(
        label: 'Saving…',
        loading: true,
        announce: true,
      );
    }
    if (_saveFailed) {
      return _draftStatus(
        label: 'Save failed',
        color: context.theme.danger,
        announce: true,
      );
    }
    if (_isDirty) {
      return _draftStatus(
        label: 'Unsaved changes',
        color: context.theme.warning,
      );
    }
    return const KinCryptStatusIndicator(label: 'No unsaved changes');
  }

  Widget _draftStatus({
    required String label,
    required Color color,
    bool announce = false,
  }) => Semantics(
    liveRegion: announce,
    label: label,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: context.theme.spaceSm),
        KinCryptText(label, variant: KinCryptTextVariant.meta, color: color),
      ],
    ),
  );

  Widget _buildIdentity() => _EditorSection(
    title: 'Identity',
    error: _identityInvalid
        ? 'Enter a display name, first name, last name, or organization.'
        : null,
    child: Column(
      children: [
        _ResponsivePair(
          first: KinCryptTextField(
            key: const Key('contact-first-name'),
            autofocus: true,
            controller: _firstName,
            label: 'First name',
            onChanged: _onIdentityChanged,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.givenName],
          ),
          second: KinCryptTextField(
            key: const Key('contact-last-name'),
            controller: _lastName,
            label: 'Last name',
            onChanged: _onIdentityChanged,
            textCapitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.familyName],
          ),
        ),
        SizedBox(height: context.theme.spaceMd),
        KinCryptTextField(
          key: const Key('contact-display-name'),
          controller: _displayName,
          label: 'Display name',
          onChanged: _onDisplayNameChanged,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.name],
        ),
        SizedBox(height: context.theme.spaceMd),
        KinCryptTextField(
          key: const Key('contact-organization'),
          controller: _organization,
          label: 'Organization',
          onChanged: _onIdentityChanged,
          textCapitalization: TextCapitalization.words,
          autofillHints: const [AutofillHints.organizationName],
        ),
        SizedBox(height: context.theme.spaceMd),
        KinCryptTextField(
          key: const Key('contact-title'),
          controller: _title,
          label: 'Job title',
          textCapitalization: TextCapitalization.words,
        ),
      ],
    ),
  );

  Widget _buildTypedSections() => Column(
    children: [
      _TypedSection(
        title: 'Emails',
        addLabel: 'Add email',
        drafts: _emails,
        suggestions: const ['Home', 'Work', 'Main', 'Other'],
        valueLabel: 'Email address',
        keyboardType: TextInputType.emailAddress,
        onAdd: () => _mutateDraft(() => _emails.add(_TypedValueDraft())),
        onRemove: (index) =>
            _mutateDraft(() => _emails.removeAt(index).dispose()),
        onReorder: (oldIndex, newIndex) =>
            _mutateDraft(() => _reorder(_emails, oldIndex, newIndex)),
      ),
      _PhoneSection(
        title: 'Phones',
        addLabel: 'Add phone',
        drafts: _phones,
        suggestions: const ['Mobile', 'Home', 'Work', 'Main', 'Other'],
        countries: _phoneCountries,
        formattingAvailable:
            phoneNumberFormattingAvailable && _phoneCountries.isNotEmpty,
        countryPreferenceReady: _phoneCountryPreferenceReady,
        onAdd: () => _mutateDraft(
          () => _phones.add(_PhoneDraft(selectedCountry: _defaultPhoneCountry)),
        ),
        onRemove: (index) =>
            _mutateDraft(() => _phones.removeAt(index).dispose()),
        onReorder: (oldIndex, newIndex) =>
            _mutateDraft(() => _reorder(_phones, oldIndex, newIndex)),
        onChanged: _onFormChanged,
        onCountrySelected: _rememberPhoneCountry,
      ),
    ],
  );

  Widget _buildAvatar(BuildContext context) {
    final displayName = _formattedName.isEmpty ? 'Contact' : _formattedName;
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          _UriAvatar(
            uri: _photos.firstOrNull?.uri,
            displayName: displayName,
            radius: 44,
          ),
          Positioned(
            right: -8,
            bottom: -6,
            child: Material(
              shape: const CircleBorder(),
              color: context.theme.selectedSurface,
              child: KinCryptIconButton(
                key: const Key('contact-photo-button'),
                semanticLabel: 'Edit contact photos',
                onPressed: _isBusy ? null : _showPhotoManager,
                icon: LucideIcons.camera,
                style: KinCryptIconButtonStyle.neutral,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddresses() {
    return _EditorSection(
      title: 'Addresses',
      actionLabel: 'Add address',
      onAction: () => _mutateDraft(() => _addresses.add(_AddressDraft())),
      child: _ReorderableColumn(
        itemCount: _addresses.length,
        onReorder: (oldIndex, newIndex) =>
            _mutateDraft(() => _reorder(_addresses, oldIndex, newIndex)),
        itemBuilder: (context, index) {
          final draft = _addresses[index];
          return _AddressEditor(
            key: ValueKey(draft.id),
            draft: draft,
            index: index,
            onRemove: () =>
                _mutateDraft(() => _addresses.removeAt(index).dispose()),
          );
        },
      ),
    );
  }

  Widget _buildDates() {
    return _EditorSection(
      title: 'Dates',
      child: Column(
        children: [
          _DateInput(
            key: const Key('contact-birthday'),
            label: 'Birthday',
            value: _birthday,
            onTap: () => _pickDate(isBirthday: true),
            onClear: _birthday == null
                ? null
                : () => _mutateDraft(() => _birthday = null),
          ),
          const SizedBox(height: 12),
          _DateInput(
            key: const Key('contact-anniversary'),
            label: 'Anniversary',
            value: _anniversary,
            onTap: () => _pickDate(isBirthday: false),
            onClear: _anniversary == null
                ? null
                : () => _mutateDraft(() => _anniversary = null),
          ),
        ],
      ),
    );
  }

  Widget _buildGroups(AsyncValue<List<Group>> groupState) {
    final visibleGroups = _normalizedGroups(_groups);
    return _EditorSection(
      title: 'Groups',
      actionLabel: 'Add group',
      onAction: () => _showGroupSelector(groupState),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (groupState.isLoading)
            const Align(
              alignment: Alignment.centerLeft,
              child: KinCryptActivityIndicator(size: 18),
            ),
          if (groupState.hasError)
            KinCryptText(
              'Could not load existing groups. Custom groups remain available.',
              color: context.theme.danger,
            ),
          if (visibleGroups.isEmpty)
            KinCryptText('No groups selected', color: context.theme.textMuted)
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final group in visibleGroups)
                  KinCryptChip(
                    key: ValueKey('group-$group'),
                    label: group,
                    selected: true,
                    icon: LucideIcons.x,
                    semanticLabel: 'Remove $group',
                    onPressed: () => _mutateDraft(() => _groups.remove(group)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildAdditionalFields() {
    final hasGender = _additionalFields.any(
      (field) => field.kind == _AdditionalKind.gender,
    );
    return _EditorSection(
      title: 'Additional fields',
      action: MenuAnchor(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(context.theme.surfaceSoft),
          shadowColor: WidgetStatePropertyAll(context.theme.surfaceSoft),
          side: WidgetStatePropertyAll(
            BorderSide(color: context.theme.divider),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(context.theme.controlRadius),
            ),
          ),
        ),
        menuChildren: [
          for (final kind in _AdditionalKind.values)
            if (kind != _AdditionalKind.gender || !hasGender)
              MenuItemButton(
                onPressed: () => _mutateDraft(
                  () =>
                      _additionalFields.add(_AdditionalFieldDraft(kind: kind)),
                ),
                child: KinCryptText(kind.label),
              ),
        ],
        builder: (context, controller, child) => KinCryptTextButton(
          key: const Key('add-additional-field'),
          label: 'Add field',
          icon: LucideIcons.plus,
          onPressed: controller.isOpen ? controller.close : controller.open,
        ),
      ),
      child: _ReorderableColumn(
        itemCount: _additionalFields.length,
        onReorder: (oldIndex, newIndex) =>
            _mutateDraft(() => _reorder(_additionalFields, oldIndex, newIndex)),
        itemBuilder: (context, index) {
          final draft = _additionalFields[index];
          return _AdditionalFieldEditor(
            key: ValueKey(draft.id),
            draft: draft,
            index: index,
            onPickMedia: draft.kind == _AdditionalKind.logo
                ? () async {
                    final uri = await _pickMediaUri();
                    if (uri != null) {
                      _mutateDraft(() => draft.value.text = uri);
                    }
                  }
                : null,
            onRemove: () =>
                _mutateDraft(() => _additionalFields.removeAt(index).dispose()),
          );
        },
      ),
    );
  }

  Widget _buildNotes() {
    return _EditorSection(
      title: 'Notes',
      actionLabel: 'Add note',
      onAction: () => _mutateDraft(() => _notes.add(_TextDraft())),
      child: _ReorderableColumn(
        itemCount: _notes.length,
        onReorder: (oldIndex, newIndex) =>
            _mutateDraft(() => _reorder(_notes, oldIndex, newIndex)),
        itemBuilder: (context, index) {
          final draft = _notes[index];
          return Padding(
            key: ValueKey(draft.id),
            padding: EdgeInsets.only(bottom: context.theme.spaceMd),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: _CompoundCard(
                header: Row(
                  children: [
                    _DragHandle(index: index),
                    const Spacer(),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: KinCryptIconButton(
                        semanticLabel: 'Delete note',
                        icon: LucideIcons.trash2,
                        style: KinCryptIconButtonStyle.danger,
                        onPressed: () => _mutateDraft(
                          () => _notes.removeAt(index).dispose(),
                        ),
                      ),
                    ),
                  ],
                ),
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: KinCryptTextField(
                    key: Key('contact-note-$index'),
                    controller: draft.value,
                    label: 'Note',
                    type: TextFieldType.multiline,
                    minLines: 3,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDeleteButton() {
    return Padding(
      padding: EdgeInsets.only(top: context.theme.spaceXl),
      child: KinCryptButton(
        key: const Key('delete-contact-button'),
        label: 'Delete contact',
        icon: LucideIcons.trash2,
        style: KinCryptButtonStyle.dangerSoft,
        stretch: true,
        loading: _isDeleting,
        enabled: !_isBusy,
        onPressed: _isBusy ? null : _confirmDelete,
      ),
    );
  }

  void _initialize(Contact? contact) {
    _sourceContact = contact;
    _displayName.text = contact?.formattedName ?? '';
    _firstName.text = contact?.name?.firstName ?? '';
    _lastName.text = contact?.name?.lastName ?? '';
    _organization.text = contact?.organization ?? '';
    _syncDisplayName =
        contact == null ||
        contact.formattedName.trim().isEmpty ||
        contact.formattedName.trim() == _calculatedDisplayName;
    _title.text = contact?.title ?? '';
    _birthday = contact?.birthday;
    _anniversary = contact?.anniversary;
    _photos.addAll(
      contact?.photos.map((photo) => _MediaDraft(photo.uri)) ?? const [],
    );
    _groups.addAll(_normalizedGroups(contact?.groups ?? const []));
    _emails.addAll(
      contact?.emails.map(
            (email) => _TypedValueDraft(type: email.type, value: email.address),
          ) ??
          const [],
    );
    _phones.addAll(
      contact?.phones.map((phone) {
            final inferredCountry = _countryFromInternationalNumber(
              phone.number,
              _phoneCountries,
            );
            return _PhoneDraft(
              type: phone.type,
              number: phone.number,
              selectedCountry: inferredCountry ?? _defaultPhoneCountry,
              countryWasInferred: inferredCountry != null,
            );
          }) ??
          const [],
    );
    _addresses.addAll(
      contact?.addresses.map(_AddressDraft.fromContact) ?? const [],
    );
    _notes.addAll(contact?.notes.map(_TextDraft.new) ?? const []);
    _additionalFields.addAll([
      ...?contact?.urls.map(
        (value) =>
            _AdditionalFieldDraft(kind: _AdditionalKind.website, value: value),
      ),
      if (contact?.gender != null)
        _AdditionalFieldDraft(
          kind: _AdditionalKind.gender,
          value: contact!.gender!,
        ),
      ...?contact?.roles.map(
        (value) =>
            _AdditionalFieldDraft(kind: _AdditionalKind.role, value: value),
      ),
      ...?contact?.logos.map(
        (value) =>
            _AdditionalFieldDraft(kind: _AdditionalKind.logo, value: value.uri),
      ),
    ]);
    _initialized = true;
    _initialDraftFingerprint = _draftFingerprint;
  }

  String get _draftFingerprint => jsonEncode({
    'displayName': _displayName.text,
    'firstName': _firstName.text,
    'lastName': _lastName.text,
    'organization': _organization.text,
    'title': _title.text,
    'emails': [
      for (final draft in _emails)
        {'type': draft.type.text, 'value': draft.value.text},
    ],
    'phones': [
      for (final draft in _phones)
        {'type': draft.type.text, 'value': draft.persistedNumber},
    ],
    'addresses': [
      for (final draft in _addresses)
        {
          'type': draft.type.text,
          'street': draft.street.text,
          'zip': draft.zip.text,
          'city': draft.city.text,
          'region': draft.region.text,
          'country': draft.country.text,
        },
    ],
    'birthday': _dateFingerprint(_birthday),
    'anniversary': _dateFingerprint(_anniversary),
    'groups': _groups,
    'additional': [
      for (final draft in _additionalFields)
        {'kind': draft.kind.name, 'value': draft.value.text},
    ],
    'notes': [for (final draft in _notes) draft.value.text],
    'photos': [for (final draft in _photos) draft.uri],
  });

  void _onFormChanged() {
    if (!mounted) return;
    setState(() {
      _saveFailed = false;
      if (_hasIdentity) _identityInvalid = false;
    });
  }

  void _mutateDraft(VoidCallback change) {
    setState(() {
      change();
      _saveFailed = false;
      if (_hasIdentity) _identityInvalid = false;
    });
  }

  Future<void> _requestClose() async {
    if (_isBusy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_isDirty) {
      Navigator.of(context).maybePop();
      return;
    }

    final discard = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => const KinCryptConfirmationBottomSheet(
        title: 'Discard changes?',
        message: 'Your unsaved contact changes will be lost.',
        confirmLabel: 'Discard changes',
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_hasIdentity) {
      setState(() => _identityInvalid = true);
      return;
    }

    setState(() {
      _isSaving = true;
      _saveFailed = false;
      _identityInvalid = false;
    });
    try {
      await Future.wait([
        for (final draft in _phones)
          if (draft.numberChanged)
            draft.finalize(countries: _phoneCountries, formatForDisplay: false),
      ]);
      final contact = _buildContact();
      final Contact updatedContact;
      final provider = _isEditing
          ? contactProvider(widget.contactId)
          : contactProvider();
      updatedContact = await ref.read(provider.notifier).upsertContact(contact);
      if (!mounted) return;
      setState(() => _allowPop = true);
      context.go('/contacts/${Uri.encodeComponent(updatedContact.id)}');
    } catch (_) {
      if (mounted) {
        setState(() => _saveFailed = true);
        _showMessage('Could not save contact.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _confirmDelete() async {
    final name = _formattedName.isEmpty ? 'this contact' : _formattedName;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => KinCryptConfirmationBottomSheet(
        title: 'Delete $name?',
        message: 'This permanently deletes the contact from Proton and cannot be undone.',
        confirmLabel: 'Delete contact',
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      await ref
          .read(contactProvider(widget.contactId).notifier)
          .deleteContact();
      if (mounted) {
        setState(() => _allowPop = true);
        context.go('/contacts');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Could not delete contact.');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Contact _buildContact() {
    final firstName = _firstName.text.trim();
    final lastName = _lastName.text.trim();
    final additional = _additionalFields.where(
      (field) => field.value.text.trim().isNotEmpty,
    );
    return Contact(
      id: widget.contactId ?? '',
      formattedName: _formattedName,
      name: firstName.isEmpty && lastName.isEmpty
          ? null
          : ContactName(firstName: firstName, lastName: lastName),
      isFavorite: _sourceContact?.isFavorite ?? false,
      gender: _optional(
        additional
            .where((field) => field.kind == _AdditionalKind.gender)
            .firstOrNull
            ?.value
            .text,
      ),
      logos: additional
          .where((field) => field.kind == _AdditionalKind.logo)
          .map((field) => ContactImage(uri: field.value.text.trim()))
          .toList(),
      title: _optional(_title.text),
      organization: _optional(_organization.text),
      photos: _photos
          .map((photo) => photo.uri.trim())
          .where((uri) => uri.isNotEmpty)
          .map((uri) => ContactImage(uri: uri))
          .toList(),
      emails: _emails
          .where((draft) => draft.value.text.trim().isNotEmpty)
          .map(
            (draft) => ContactEmail(
              address: draft.value.text.trim(),
              type: _optional(draft.type.text),
            ),
          )
          .toList(),
      phones: _phones
          .where((draft) => draft.persistedNumber.trim().isNotEmpty)
          .map(
            (draft) => ContactPhone(
              number: draft.persistedNumber,
              type: _optional(draft.type.text),
            ),
          )
          .toList(),
      addresses: _addresses
          .where((draft) => draft.hasValue)
          .map((draft) => draft.toContact())
          .toList(),
      birthday: _birthday,
      anniversary: _anniversary,
      notes: _notes
          .map((draft) => draft.value.text.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
      urls: additional
          .where((field) => field.kind == _AdditionalKind.website)
          .map((field) => field.value.text.trim())
          .toList(),
      roles: additional
          .where((field) => field.kind == _AdditionalKind.role)
          .map((field) => field.value.text.trim())
          .toList(),
      groups: _deduplicatedGroups,
    );
  }

  bool get _hasIdentity => _formattedName.isNotEmpty;

  CountryWithPhoneCode? get _defaultPhoneCountry =>
      _preferredPhoneCountry ?? _localePhoneCountry;

  CountryWithPhoneCode? _countryByCode(String? countryCode) {
    if (countryCode == null) return null;
    final normalized = countryCode.toUpperCase();
    return _phoneCountries
        .where((country) => country.countryCode.toUpperCase() == normalized)
        .firstOrNull;
  }

  Future<void> _loadPreferredPhoneCountry() async {
    String? storedCode;
    try {
      storedCode = await ref
          .read(sharedPreferencesProvider)
          .getString(StorageKeys.phoneCountryCode.key);
    } catch (_) {
      return;
    }
    final storedCountry = _countryByCode(storedCode);
    if (!mounted || storedCountry == null) return;

    setState(() {
      _preferredPhoneCountry = storedCountry;
      for (final draft in _phones) {
        if (!draft.countryWasInferred && !draft.numberChanged) {
          draft.selectedCountry = storedCountry;
        }
      }
    });
  }

  void _rememberPhoneCountry(CountryWithPhoneCode country) {
    _preferredPhoneCountry = country;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(StorageKeys.phoneCountryCode.key, country.countryCode)
          .catchError((_) {}),
    );
  }

  void _onDisplayNameChanged(String value) {
    _syncDisplayName =
        value.trim().isEmpty || value.trim() == _calculatedDisplayName;
    _onFormChanged();
  }

  void _onIdentityChanged(String _) {
    if (_syncDisplayName) {
      _displayName.text = _calculatedDisplayName;
    }
    _onFormChanged();
  }

  String get _formattedName {
    final displayName = _displayName.text.trim();
    if (displayName.isNotEmpty) return displayName;

    return _calculatedDisplayName;
  }

  String get _calculatedDisplayName => _defaultDisplayName(
    firstName: _firstName.text,
    lastName: _lastName.text,
    organization: _organization.text,
  );

  String _defaultDisplayName({
    required String firstName,
    required String lastName,
    required String organization,
  }) {
    final name = [
      firstName.trim(),
      lastName.trim(),
    ].where((value) => value.isNotEmpty).join(' ');
    if (name.isNotEmpty) return name;

    return organization.trim();
  }

  List<String> get _deduplicatedGroups => _normalizedGroups(_groups);

  Future<void> _pickDate({required bool isBirthday}) async {
    final current = isBirthday ? _birthday : _anniversary;
    final now = DateTime.now();
    final firstDate = DateTime(1800);
    final lastDate = DateTime(now.year + 100);
    final parsed = _parseDate(current);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          parsed != null &&
              !parsed.isBefore(firstDate) &&
              !parsed.isAfter(lastDate)
          ? parsed
          : now,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isBirthday ? 'Select birthday' : 'Select anniversary',
      builder: (context, child) {
        final theme = context.theme;
        final brightness = Theme.of(context).brightness;
        final selectedForeground = WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return theme.textMuted.withValues(alpha: 0.5);
          }
          return states.contains(WidgetState.selected)
              ? theme.onBrand
              : theme.textPrimary;
        });
        final selectedBackground = WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? theme.brandVault
              : Colors.transparent,
        );
        final todayForeground = WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return theme.textMuted.withValues(alpha: 0.5);
          }
          return states.contains(WidgetState.selected)
              ? theme.onBrand
              : theme.brandVault;
        });

        return Theme(
          data: ThemeData(
            brightness: brightness,
            extensions: [theme],
            colorScheme: ColorScheme(
              brightness: brightness,
              primary: theme.brandVault,
              onPrimary: theme.onBrand,
              secondary: theme.brandSignal,
              onSecondary: theme.onBrand,
              error: theme.danger,
              onError: theme.onDanger,
              surface: theme.surface,
              onSurface: theme.textPrimary,
              outline: theme.divider,
              outlineVariant: theme.divider,
              onSurfaceVariant: theme.textMuted,
              surfaceContainerHigh: theme.surfaceSoft,
            ),
            dividerColor: theme.divider,
            disabledColor: theme.textMuted.withValues(alpha: 0.5),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: theme.surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(theme.containerRadius),
              ),
              headerBackgroundColor: theme.surfaceSoft,
              headerForegroundColor: theme.textPrimary,
              headerHeadlineStyle: theme.screenTitle,
              headerHelpStyle: theme.meta.copyWith(color: theme.textMuted),
              weekdayStyle: theme.meta.copyWith(color: theme.textMuted),
              dayStyle: theme.body,
              dayForegroundColor: selectedForeground,
              dayBackgroundColor: selectedBackground,
              todayForegroundColor: todayForeground,
              todayBorder: BorderSide(color: theme.brandVault),
              yearStyle: theme.body,
              yearForegroundColor: selectedForeground,
              yearBackgroundColor: selectedBackground,
              dividerColor: theme.divider,
              cancelButtonStyle: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(theme.textMuted),
                textStyle: WidgetStatePropertyAll(theme.button),
              ),
              confirmButtonStyle: ButtonStyle(
                foregroundColor: WidgetStatePropertyAll(theme.brandVault),
                textStyle: WidgetStatePropertyAll(theme.button),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    final value = ContactDate(
      year: picked.year.toString().padLeft(4, '0'),
      month: picked.month.toString().padLeft(2, '0'),
      day: picked.day.toString().padLeft(2, '0'),
    );
    _mutateDraft(() {
      if (isBirthday) {
        _birthday = value;
      } else {
        _anniversary = value;
      }
    });
  }

  Future<void> _showPhotoManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.theme.surface,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void refresh(VoidCallback change) {
            _mutateDraft(change);
            setSheetState(() {});
          }

          return KinCryptSafeArea(
            child: FractionallySizedBox(
              heightFactor: .82,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const KinCryptText(
                      'Contact photos',
                      variant: KinCryptTextVariant.sectionTitle,
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _photos.isEmpty
                          ? const Center(child: KinCryptText('No photos added'))
                          : ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              proxyDecorator: (child, index, animation) =>
                                  _reorderProxyDecorator(
                                    context,
                                    child,
                                    animation,
                                  ),
                              itemCount: _photos.length,
                              onReorderItem: (oldIndex, newIndex) => refresh(
                                () => _reorder(_photos, oldIndex, newIndex),
                              ),
                              itemBuilder: (context, index) {
                                final photo = _photos[index];
                                return KinCryptListRow(
                                  key: ValueKey(photo.id),
                                  leading: _UriAvatar(
                                    uri: photo.uri,
                                    displayName: _displayName.text,
                                    radius: 22,
                                  ),
                                  title: index == 0
                                      ? 'Primary photo'
                                      : 'Photo ${index + 1}',
                                  subtitle: photo.uri.startsWith('data:')
                                      ? 'Photo from device'
                                      : photo.uri,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ReorderableDragStartListener(
                                        key: Key('contact-photo-drag-$index'),
                                        index: index,
                                        child: const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Icon(Icons.drag_handle),
                                        ),
                                      ),
                                      KinCryptIconButton(
                                        semanticLabel: 'Remove photo',
                                        onPressed: () => refresh(
                                          () => _photos.removeAt(index),
                                        ),
                                        icon: LucideIcons.trash2,
                                        style: KinCryptIconButtonStyle.danger,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    if (_cameraSupported)
                      KinCryptListRow(
                        leading: const Icon(LucideIcons.camera),
                        title: 'Take photo',
                        onTap: () async {
                          final uri = await _pickImage(ImageSource.camera);
                          if (uri != null) {
                            refresh(() => _photos.add(_MediaDraft(uri)));
                          }
                        },
                      ),
                    KinCryptListRow(
                      leading: const Icon(LucideIcons.image),
                      title: 'Choose from device',
                      onTap: () async {
                        final uri = await _pickImage(ImageSource.gallery);
                        if (uri != null) {
                          refresh(() => _photos.add(_MediaDraft(uri)));
                        }
                      },
                    ),
                    KinCryptListRow(
                      leading: const Icon(LucideIcons.link),
                      title: 'Use image URL',
                      onTap: () async {
                        final uri = await _requestImageUrl();
                        if (uri != null) {
                          refresh(() => _photos.add(_MediaDraft(uri)));
                        }
                      },
                    ),
                    if (_photos.isNotEmpty)
                      KinCryptListRow(
                        leading: Icon(
                          LucideIcons.trash2,
                          color: context.theme.danger,
                        ),
                        title: 'Remove all photos',
                        onTap: () => refresh(_photos.clear),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String?> _pickMediaUri() async {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.theme.surface,
      useSafeArea: true,
      builder: (context) => KinCryptSafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: KinCryptText(
                'Choose image',
                variant: KinCryptTextVariant.sectionTitle,
              ),
            ),
            if (_cameraSupported)
              KinCryptListRow(
                leading: const Icon(LucideIcons.camera),
                title: 'Take photo',
                onTap: () async {
                  final uri = await _pickImage(ImageSource.camera);
                  if (context.mounted && uri != null) {
                    Navigator.of(context).pop(uri);
                  }
                },
              ),
            KinCryptListRow(
              leading: const Icon(LucideIcons.image),
              title: 'Choose from device',
              onTap: () async {
                final uri = await _pickImage(ImageSource.gallery);
                if (context.mounted && uri != null) {
                  Navigator.of(context).pop(uri);
                }
              },
            ),
            KinCryptListRow(
              leading: const Icon(LucideIcons.link),
              title: 'Use image URL',
              onTap: () async {
                final uri = await _requestImageUrl();
                if (context.mounted && uri != null) {
                  Navigator.of(context).pop(uri);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickImage(ImageSource source) async {
    try {
      final file = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
        requestFullMetadata: false,
      );
      if (file == null) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final mimeType = file.mimeType ?? _mimeTypeFromPath(file.path);
      return 'data:$mimeType;base64,${base64Encode(bytes)}';
    } catch (_) {
      if (mounted) {
        _showMessage('Could not load that image.');
      }
      return null;
    }
  }

  Future<String?> _requestImageUrl() async {
    return _requestTextValue(
      title: 'Use image URL',
      label: 'Image URL',
      confirmLabel: 'Add',
      fieldKey: const Key('image-url-input'),
      type: TextFieldType.url,
      isValid: (value) {
        final uri = Uri.tryParse(value);
        return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
      },
    );
  }

  Future<void> _showGroupSelector(AsyncValue<List<Group>> groupState) async {
    final loadedGroups = groupState.value ?? const [];
    final available = <String>[
      ..._groups,
      ...loadedGroups.map((group) => group.name),
    ];
    final allNames = <String>[];
    final seen = <String>{};
    for (final value in available) {
      final name = value.trim();
      if (name.isNotEmpty && seen.add(name)) allNames.add(name);
    }
    final selected = _normalizedGroups(_groups);
    var searchQuery = '';

    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.theme.surface,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filtered = allNames
              .where((name) => name.toLowerCase().contains(searchQuery))
              .toList();
          return KinCryptSafeArea(
            child: FractionallySizedBox(
              heightFactor: .85,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: KinCryptText(
                            'Select groups',
                            variant: KinCryptTextVariant.sectionTitle,
                          ),
                        ),
                        KinCryptTextButton(
                          label: 'Done',
                          onPressed: () => Navigator.of(context).pop(selected),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    KinCryptSearchField(
                      key: const Key('group-search'),
                      onChanged: (value) => setSheetState(
                        () => searchQuery = value.trim().toLowerCase(),
                      ),
                      hint: 'Search groups',
                    ),
                    const SizedBox(height: 12),
                    if (selected.isNotEmpty) ...[
                      const KinCryptText(
                        'Selected',
                        variant: KinCryptTextVariant.meta,
                      ),
                      SizedBox(
                        height: (selected.length * 48)
                            .clamp(48, 180)
                            .toDouble(),
                        child: ReorderableListView.builder(
                          proxyDecorator: (child, index, animation) =>
                              _reorderProxyDecorator(context, child, animation),
                          itemCount: selected.length,
                          onReorderItem: (oldIndex, newIndex) => setSheetState(
                            () => _reorder(selected, oldIndex, newIndex),
                          ),
                          itemBuilder: (context, index) => KinCryptListRow(
                            key: ValueKey('selected-${selected[index]}'),
                            leading: const Icon(Icons.check_box),
                            title: selected[index],
                            trailing: const Icon(Icons.drag_handle),
                            compact: true,
                            onTap: () =>
                                setSheetState(() => selected.removeAt(index)),
                          ),
                        ),
                      ),
                      const Divider(),
                    ],
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final group = filtered[index];
                          final checked = selected.contains(group);
                          void toggle() => setSheetState(() {
                            if (checked) {
                              selected.remove(group);
                            } else {
                              selected.add(group);
                            }
                          });
                          return KinCryptListRow(
                            title: group,
                            selected: checked,
                            leading: Checkbox(
                              value: checked,
                              onChanged: (_) => toggle(),
                            ),
                            onTap: toggle,
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    KinCryptListRow(
                      leading: const Icon(LucideIcons.plus),
                      title: 'Create new group',
                      onTap: () async {
                        final group = await _requestGroupName();
                        if (group == null) return;
                        setSheetState(() {
                          if (!allNames.contains(group)) allNames.add(group);
                          if (!selected.contains(group)) selected.add(group);
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (result != null && mounted) {
      _mutateDraft(() {
        _groups
          ..clear()
          ..addAll(_normalizedGroups(result));
      });
    }
  }

  Future<String?> _requestGroupName() async {
    return _requestTextValue(
      title: 'Create new group',
      label: 'Group name',
      confirmLabel: 'Create',
      fieldKey: const Key('new-group-name'),
      capitalization: TextCapitalization.words,
      isValid: (value) => value.isNotEmpty,
    );
  }

  Future<String?> _requestTextValue({
    required String title,
    required String label,
    required String confirmLabel,
    required Key fieldKey,
    required bool Function(String value) isValid,
    TextFieldType type = TextFieldType.text,
    TextCapitalization capitalization = TextCapitalization.none,
  }) async {
    var value = '';
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Container(
          padding: EdgeInsets.all(context.theme.spaceLg),
          decoration: BoxDecoration(
            color: context.theme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(context.theme.containerRadius),
            ),
          ),
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KinCryptText(title, variant: KinCryptTextVariant.sectionTitle),
                SizedBox(height: context.theme.spaceLg),
                KinCryptTextField(
                  key: fieldKey,
                  autofocus: true,
                  label: label,
                  type: type,
                  textCapitalization: capitalization,
                  textInputAction: TextInputAction.done,
                  onChanged: (input) => value = input.trim(),
                  onSubmitted: (input) {
                    final submittedValue = input.trim();
                    if (isValid(submittedValue)) {
                      Navigator.of(context).pop(submittedValue);
                    }
                  },
                ),
                SizedBox(height: context.theme.spaceLg),
                KinCryptButton(
                  label: confirmLabel,
                  stretch: true,
                  onPressed: () {
                    if (isValid(value)) Navigator.of(context).pop(value);
                  },
                ),
                SizedBox(height: context.theme.spaceSm),
                KinCryptButton(
                  label: 'Cancel',
                  stretch: true,
                  style: KinCryptButtonStyle.secondary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.first, required this.second});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final scale = MediaQuery.textScalerOf(context).scale(1);
      if (constraints.maxWidth < 480 || scale > 1.25) {
        return Column(
          children: [
            first,
            SizedBox(height: context.theme.spaceMd),
            second,
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          SizedBox(width: context.theme.spaceMd),
          Expanded(child: second),
        ],
      );
    },
  );
}

class _CompoundCard extends StatelessWidget {
  const _CompoundCard({required this.header, required this.child});

  final Widget header;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(context.theme.spaceMd),
    decoration: BoxDecoration(
      color: context.theme.surfaceSoft,
      border: Border.all(color: context.theme.divider),
      borderRadius: BorderRadius.circular(context.theme.containerRadius),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        SizedBox(height: context.theme.spaceSm),
        child,
      ],
    ),
  );
}

class _EditorSection extends StatelessWidget {
  const _EditorSection({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.action,
    this.error,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.theme.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: KinCryptText(
                  title,
                  variant: KinCryptTextVariant.sectionTitle,
                ),
              ),
              if (action != null)
                action!
              else if (actionLabel != null)
                KinCryptTextButton(
                  label: actionLabel!,
                  icon: LucideIcons.plus,
                  onPressed: onAction,
                ),
            ],
          ),
          if (error case final error?) ...[
            SizedBox(height: context.theme.spaceXs),
            KinCryptText(
              error,
              variant: KinCryptTextVariant.meta,
              color: context.theme.danger,
            ),
          ],
          SizedBox(height: context.theme.spaceMd),
          child,
        ],
      ),
    );
  }
}

class _TypedSection extends StatelessWidget {
  const _TypedSection({
    required this.title,
    required this.addLabel,
    required this.drafts,
    required this.suggestions,
    required this.valueLabel,
    required this.keyboardType,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
  });

  final String title;
  final String addLabel;
  final List<_TypedValueDraft> drafts;
  final List<String> suggestions;
  final String valueLabel;
  final TextInputType keyboardType;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      title: title,
      actionLabel: addLabel,
      onAction: onAdd,
      child: _ReorderableColumn(
        itemCount: drafts.length,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          final draft = drafts[index];
          return Padding(
            key: ValueKey(draft.id),
            padding: EdgeInsets.only(bottom: context.theme.spaceMd),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: _CompoundCard(
                header: Row(
                  children: [
                    _DragHandle(index: index),
                    SizedBox(width: context.theme.spaceXs),
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: _TypeAutocomplete(
                          key: Key('${title.toLowerCase()}-type-$index'),
                          controller: draft.type,
                          focusNode: draft.typeFocus,
                          suggestions: suggestions,
                        ),
                      ),
                    ),
                    SizedBox(width: context.theme.spaceSm),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: KinCryptIconButton(
                        semanticLabel: 'Delete ${title.toLowerCase()} entry',
                        icon: LucideIcons.trash2,
                        style: KinCryptIconButtonStyle.danger,
                        onPressed: () => onRemove(index),
                      ),
                    ),
                  ],
                ),
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: KinCryptTextField(
                    key: Key('${title.toLowerCase()}-value-$index'),
                    controller: draft.value,
                    label: valueLabel,
                    type: keyboardType == TextInputType.emailAddress
                        ? TextFieldType.email
                        : TextFieldType.text,
                    keyboardType: keyboardType,
                    autofillHints: keyboardType == TextInputType.emailAddress
                        ? const [AutofillHints.email]
                        : const [AutofillHints.telephoneNumber],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhoneSection extends StatelessWidget {
  const _PhoneSection({
    required this.title,
    required this.addLabel,
    required this.drafts,
    required this.suggestions,
    required this.countries,
    required this.formattingAvailable,
    required this.countryPreferenceReady,
    required this.onAdd,
    required this.onRemove,
    required this.onReorder,
    required this.onChanged,
    required this.onCountrySelected,
  });

  final String title;
  final String addLabel;
  final List<_PhoneDraft> drafts;
  final List<String> suggestions;
  final List<CountryWithPhoneCode> countries;
  final bool formattingAvailable;
  final Future<void> countryPreferenceReady;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ReorderCallback onReorder;
  final VoidCallback onChanged;
  final ValueChanged<CountryWithPhoneCode> onCountrySelected;

  @override
  Widget build(BuildContext context) {
    return _EditorSection(
      title: title,
      actionLabel: addLabel,
      onAction: onAdd,
      child: _ReorderableColumn(
        itemCount: drafts.length,
        onReorder: onReorder,
        itemBuilder: (context, index) {
          final draft = drafts[index];
          return Padding(
            key: ValueKey(draft.id),
            padding: EdgeInsets.only(bottom: context.theme.spaceMd),
            child: FocusTraversalGroup(
              policy: OrderedTraversalPolicy(),
              child: _CompoundCard(
                header: Row(
                  children: [
                    _DragHandle(index: index),
                    SizedBox(width: context.theme.spaceXs),
                    Expanded(
                      child: FocusTraversalOrder(
                        order: const NumericFocusOrder(1),
                        child: _TypeAutocomplete(
                          key: Key('phones-type-$index'),
                          controller: draft.type,
                          focusNode: draft.typeFocus,
                          suggestions: suggestions,
                        ),
                      ),
                    ),
                    SizedBox(width: context.theme.spaceSm),
                    FocusTraversalOrder(
                      order: const NumericFocusOrder(3),
                      child: KinCryptIconButton(
                        semanticLabel: 'Delete phone entry',
                        icon: LucideIcons.trash2,
                        style: KinCryptIconButtonStyle.danger,
                        onPressed: () => onRemove(index),
                      ),
                    ),
                  ],
                ),
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: _PhoneNumberField(
                    key: Key('phones-value-$index'),
                    draft: draft,
                    countries: countries,
                    formattingAvailable: formattingAvailable,
                    countryPreferenceReady: countryPreferenceReady,
                    onChanged: onChanged,
                    onCountrySelected: onCountrySelected,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhoneNumberField extends StatefulWidget {
  const _PhoneNumberField({
    super.key,
    required this.draft,
    required this.countries,
    required this.formattingAvailable,
    required this.countryPreferenceReady,
    required this.onChanged,
    required this.onCountrySelected,
  });

  final _PhoneDraft draft;
  final List<CountryWithPhoneCode> countries;
  final bool formattingAvailable;
  final Future<void> countryPreferenceReady;
  final VoidCallback onChanged;
  final ValueChanged<CountryWithPhoneCode> onCountrySelected;

  @override
  State<_PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<_PhoneNumberField> {
  Timer? _countryDetectionTimer;

  @override
  void initState() {
    super.initState();
    widget.draft.numberFocus.addListener(_handleFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_formatInitialValue());
    });
  }

  @override
  void didUpdateWidget(covariant _PhoneNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      oldWidget.draft.numberFocus.removeListener(_handleFocusChange);
      widget.draft.numberFocus.addListener(_handleFocusChange);
    }
  }

  @override
  void dispose() {
    _countryDetectionTimer?.cancel();
    widget.draft.numberFocus.removeListener(_handleFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final country = widget.draft.selectedCountry;
    final inputFormatter = widget.formattingAvailable && country != null
        ? _PhoneInputFormatter(country: country)
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 108,
          child: KinCryptButton(
            label: country == null
                ? 'Country'
                : '${country.countryCode} +${country.phoneCode}',
            semanticLabel: country == null
                ? 'Select phone country'
                : 'Phone country ${country.countryName ?? country.countryCode}, +${country.phoneCode}',
            style: KinCryptButtonStyle.secondary,
            enabled: widget.formattingAvailable,
            onPressed: widget.formattingAvailable ? _selectCountry : null,
          ),
        ),
        SizedBox(width: context.theme.spaceSm),
        Expanded(
          child: KinCryptTextField(
            controller: widget.draft.number,
            focusNode: widget.draft.numberFocus,
            label: 'Phone number',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: inputFormatter == null ? null : [inputFormatter],
            onChanged: _handleChanged,
          ),
        ),
      ],
    );
  }

  Future<void> _formatInitialValue() async {
    await widget.countryPreferenceReady;
    if (!mounted) return;
    if (!widget.formattingAvailable ||
        widget.draft.number.text.trim().isEmpty) {
      return;
    }
    await widget.draft.finalize(
      countries: widget.countries,
      formatForDisplay: true,
    );
    if (mounted) setState(() {});
  }

  void _handleFocusChange() {
    if (!widget.draft.numberFocus.hasFocus && widget.formattingAvailable) {
      unawaited(_formatOnBlur());
    }
  }

  Future<void> _formatOnBlur() async {
    await widget.draft.finalize(
      countries: widget.countries,
      formatForDisplay: true,
    );
    if (mounted) {
      setState(() {});
      widget.onChanged();
    }
  }

  void _handleChanged(String value) {
    _countryDetectionTimer?.cancel();
    widget.draft.markNumberChanged();
    widget.onChanged();

    final trimmed = value.trimLeft();
    if (!widget.formattingAvailable || !trimmed.startsWith('+')) return;

    final match = _countryCallingCodeMatch(trimmed, widget.countries);
    if (match == null || match.subscriberDigits.isEmpty) return;

    final selected = widget.draft.selectedCountry;
    final matchingSelected = selected?.phoneCode == match.phoneCode
        ? selected
        : null;
    final detectedCountry =
        matchingSelected ??
        (match.countries.length == 1 ? match.countries.single : null);
    if (detectedCountry != null) {
      _selectDetectedCountry(detectedCountry);
      return;
    }

    _countryDetectionTimer = Timer(
      const Duration(milliseconds: 240),
      _finalizeInternationalInput,
    );
  }

  void _selectDetectedCountry(CountryWithPhoneCode country) {
    widget.draft.selectedCountry = country;
    widget.draft.countryWasInferred = true;
    if (mounted) setState(() {});
    _countryDetectionTimer = Timer(
      const Duration(milliseconds: 240),
      _finalizeInternationalInput,
    );
  }

  Future<void> _finalizeInternationalInput() async {
    await widget.draft.finalize(
      countries: widget.countries,
      formatForDisplay: true,
    );
    if (mounted) {
      setState(() {});
      widget.onChanged();
    }
  }

  Future<void> _selectCountry() async {
    final country = await showModalBottomSheet<CountryWithPhoneCode>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _CountryPickerSheet(
        countries: widget.countries,
        selectedCountry: widget.draft.selectedCountry,
      ),
    );
    if (country == null || !mounted) return;

    widget.draft.selectedCountry = country;
    widget.onCountrySelected(country);
    if (widget.draft.number.text.trim().isNotEmpty) {
      widget.draft.markNumberChanged();
      widget.onChanged();
      await widget.draft.finalize(
        countries: widget.countries,
        formatForDisplay: true,
      );
    }
    if (mounted) setState(() {});
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  _PhoneInputFormatter({required CountryWithPhoneCode country})
    : _delegate = LibPhonenumberTextFormatter(
        country: country,
        phoneNumberFormat: PhoneNumberFormat.national,
        inputContainsCountryCode: false,
        additionalDigits: 5,
        shouldKeepCursorAtEndOfInput: false,
      );

  final LibPhonenumberTextFormatter _delegate;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.trimLeft().startsWith('+')) return newValue;

    final formatted = _delegate.formatEditUpdate(oldValue, newValue);
    return _digitCount(formatted.text) < _digitCount(newValue.text)
        ? newValue
        : formatted;
  }
}

class _CountryPickerSheet extends StatefulWidget {
  const _CountryPickerSheet({
    required this.countries,
    required this.selectedCountry,
  });

  final List<CountryWithPhoneCode> countries;
  final CountryWithPhoneCode? selectedCountry;

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _search = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase().replaceFirst('+', '');
    final countries = widget.countries.where((country) {
      if (query.isEmpty) return true;
      return (country.countryName ?? '').toLowerCase().contains(query) ||
          country.countryCode.toLowerCase().contains(query) ||
          country.phoneCode.contains(query);
    }).toList();

    return FractionallySizedBox(
      heightFactor: 0.78,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.theme.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(context.theme.containerRadius),
          ),
        ),
        child: KinCryptSafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  context.theme.spaceLg,
                  context.theme.spaceLg,
                  context.theme.spaceLg,
                  context.theme.spaceMd,
                ),
                child: KinCryptText(
                  'Phone country',
                  variant: KinCryptTextVariant.sectionTitle,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.theme.spaceLg,
                ),
                child: KinCryptSearchField(
                  controller: _search,
                  hint: 'Search country or calling code',
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              SizedBox(height: context.theme.spaceMd),
              Divider(height: 1, color: context.theme.divider),
              Expanded(
                child: ListView.builder(
                  itemCount: countries.length,
                  itemBuilder: (context, index) {
                    final country = countries[index];
                    return KinCryptListRow(
                      title: country.countryName ?? country.countryCode,
                      subtitle:
                          '${country.countryCode} · +${country.phoneCode}',
                      selected:
                          country.countryCode ==
                          widget.selectedCountry?.countryCode,
                      onTap: () => Navigator.of(context).pop(country),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressEditor extends StatelessWidget {
  const _AddressEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.onRemove,
  });

  final _AddressDraft draft;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.theme.spaceMd),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: _CompoundCard(
          header: Row(
            children: [
              _DragHandle(index: index),
              SizedBox(width: context.theme.spaceXs),
              Expanded(
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: _TypeAutocomplete(
                    controller: draft.type,
                    focusNode: draft.typeFocus,
                    suggestions: const ['Home', 'Work', 'Other'],
                  ),
                ),
              ),
              SizedBox(width: context.theme.spaceSm),
              FocusTraversalOrder(
                order: const NumericFocusOrder(7),
                child: KinCryptIconButton(
                  semanticLabel: 'Delete address',
                  icon: LucideIcons.trash2,
                  style: KinCryptIconButtonStyle.danger,
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
          child: Column(
            children: [
              FocusTraversalOrder(
                order: const NumericFocusOrder(2),
                child: KinCryptTextField(
                  controller: draft.street,
                  label: 'Street',
                  keyboardType: TextInputType.streetAddress,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.streetAddressLine1],
                ),
              ),
              SizedBox(height: context.theme.spaceMd),
              _ResponsivePair(
                first: FocusTraversalOrder(
                  order: const NumericFocusOrder(3),
                  child: KinCryptTextField(
                    controller: draft.zip,
                    label: 'ZIP',
                    autofillHints: const [AutofillHints.postalCode],
                  ),
                ),
                second: FocusTraversalOrder(
                  order: const NumericFocusOrder(4),
                  child: KinCryptTextField(
                    controller: draft.city,
                    label: 'City',
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.addressCity],
                  ),
                ),
              ),
              SizedBox(height: context.theme.spaceMd),
              _ResponsivePair(
                first: FocusTraversalOrder(
                  order: const NumericFocusOrder(5),
                  child: KinCryptTextField(
                    controller: draft.region,
                    label: 'Region',
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.addressState],
                  ),
                ),
                second: FocusTraversalOrder(
                  order: const NumericFocusOrder(6),
                  child: KinCryptTextField(
                    controller: draft.country,
                    label: 'Country',
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.countryName],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdditionalFieldEditor extends StatelessWidget {
  const _AdditionalFieldEditor({
    super.key,
    required this.draft,
    required this.index,
    required this.onRemove,
    this.onPickMedia,
  });

  final _AdditionalFieldDraft draft;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback? onPickMedia;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.theme.spaceMd),
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: _CompoundCard(
          header: Row(
            children: [
              _DragHandle(index: index),
              SizedBox(width: context.theme.spaceSm),
              Expanded(
                child: KinCryptText(
                  draft.kind.label,
                  variant: KinCryptTextVariant.meta,
                  color: context.theme.textMuted,
                ),
              ),
              FocusTraversalOrder(
                order: const NumericFocusOrder(3),
                child: KinCryptIconButton(
                  semanticLabel: 'Delete ${draft.kind.label.toLowerCase()}',
                  icon: LucideIcons.trash2,
                  style: KinCryptIconButtonStyle.danger,
                  onPressed: onRemove,
                ),
              ),
            ],
          ),
          child: FocusTraversalOrder(
            order: const NumericFocusOrder(1),
            child: KinCryptTextField(
              key: Key('additional-${draft.kind.name}-$index'),
              controller: draft.value,
              label: draft.kind.valueLabel,
              type:
                  draft.kind == _AdditionalKind.website ||
                      draft.kind == _AdditionalKind.logo
                  ? TextFieldType.url
                  : TextFieldType.text,
              keyboardType:
                  draft.kind == _AdditionalKind.website ||
                      draft.kind == _AdditionalKind.logo
                  ? TextInputType.url
                  : TextInputType.text,
              suffix: onPickMedia == null
                  ? null
                  : FocusTraversalOrder(
                      order: const NumericFocusOrder(2),
                      child: KinCryptIconButton(
                        semanticLabel: 'Choose image',
                        icon: LucideIcons.image,
                        onPressed: onPickMedia,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeAutocomplete extends StatelessWidget {
  const _TypeAutocomplete({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.suggestions,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> suggestions;

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: focusNode,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        return suggestions.where(
          (option) => query.isEmpty || option.toLowerCase().contains(query),
        );
      },
      onSelected: (value) {
        controller.text = value;
        context
            .findAncestorStateOfType<_ContactEditPageState>()
            ?._onFormChanged();
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return KinCryptTextField(
          controller: controller,
          focusNode: focusNode,
          label: 'Type',
          suffix: Icon(Icons.arrow_drop_down, color: context.theme.textMuted),
          onSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            color: context.theme.surfaceSoft,
            shadowColor: context.theme.surfaceSoft,
            borderRadius: BorderRadius.circular(context.theme.controlRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 180),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: KinCryptText(option),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DateInput extends StatelessWidget {
  const _DateInput({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final ContactDate? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: _decoration(context, label).copyWith(
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onClear != null)
                KinCryptIconButton(
                  semanticLabel: 'Clear $label',
                  onPressed: onClear,
                  icon: LucideIcons.x,
                ),
              Padding(
                padding: EdgeInsets.only(right: context.theme.spaceMd),
                child: Icon(
                  LucideIcons.calendarDays,
                  color: context.theme.textMuted,
                ),
              ),
            ],
          ),
        ),
        child: KinCryptText(
          _formatDate(value),
          color: value == null ? context.theme.textMuted : null,
        ),
      ),
    );
  }
}

class _ReorderableColumn extends StatelessWidget {
  const _ReorderableColumn({
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ReorderCallback onReorder;

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) return const SizedBox.shrink();
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) =>
          _reorderProxyDecorator(context, child, animation),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      onReorderItem: onReorder,
    );
  }
}

Widget _reorderProxyDecorator(
  BuildContext context,
  Widget child,
  Animation<double> animation,
) {
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) => Material(
      color: Colors.transparent,
      elevation: Tween<double>(begin: 0, end: 6).evaluate(animation),
      child: child,
    ),
  );
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return ExcludeFocus(
      child: ReorderableDragStartListener(
        index: index,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.theme.spaceXs,
            vertical: context.theme.spaceMd,
          ),
          child: Icon(
            LucideIcons.gripVertical,
            size: 20,
            color: context.theme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _UriAvatar extends StatefulWidget {
  const _UriAvatar({
    required this.uri,
    required this.displayName,
    required this.radius,
  });

  final String? uri;
  final String displayName;
  final double radius;

  @override
  State<_UriAvatar> createState() => _UriAvatarState();
}

class _UriAvatarState extends State<_UriAvatar> {
  String? _uri;
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _updateImage();
  }

  @override
  void didUpdateWidget(covariant _UriAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) _updateImage();
  }

  void _updateImage() {
    _uri = widget.uri?.trim();
    _bytes = _uri == null ? null : _dataUriBytes(_uri!);
  }

  @override
  Widget build(BuildContext context) {
    Widget fallback() => CircleAvatar(
      radius: widget.radius,
      backgroundColor: context.theme.identitySurface,
      child: KinCryptText(
        _initials(widget.displayName),
        variant: KinCryptTextVariant.sectionTitle,
        color: context.theme.onIdentity,
      ),
    );
    if (_uri == null || _uri!.isEmpty) return fallback();

    return ClipOval(
      child: SizedBox.square(
        dimension: widget.radius * 2,
        child: _bytes != null
            ? Image.memory(
                _bytes!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              )
            : Image.network(
                _uri!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback(),
              ),
      ),
    );
  }
}

class _TypedValueDraft {
  _TypedValueDraft({String? type, String value = ''})
    : type = TextEditingController(text: type ?? ''),
      value = TextEditingController(text: value);

  final Object id = Object();
  final TextEditingController type;
  final TextEditingController value;
  final FocusNode typeFocus = FocusNode();

  void dispose() {
    type.dispose();
    value.dispose();
    typeFocus.dispose();
  }
}

class _PhoneDraft {
  _PhoneDraft({
    String? type,
    String number = '',
    this.selectedCountry,
    this.countryWasInferred = false,
  }) : originalNumber = number,
       type = TextEditingController(text: type ?? ''),
       number = TextEditingController(text: number);

  final Object id = Object();
  final String originalNumber;
  final TextEditingController type;
  final TextEditingController number;
  final FocusNode typeFocus = FocusNode();
  final FocusNode numberFocus = FocusNode();
  CountryWithPhoneCode? selectedCountry;
  String? e164;
  bool numberChanged = false;
  bool countryWasInferred;
  int _parseRevision = 0;

  String get persistedNumber => numberChanged
      ? (e164?.isNotEmpty == true ? e164! : number.text.trim())
      : originalNumber;

  void markNumberChanged() {
    numberChanged = true;
    e164 = null;
    _parseRevision++;
  }

  void setDisplayText(String value) {
    if (value.isEmpty || value == number.text) return;
    number.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> finalize({
    required List<CountryWithPhoneCode> countries,
    required bool formatForDisplay,
  }) async {
    final raw = number.text.trim();
    final revision = ++_parseRevision;
    if (raw.isEmpty || !phoneNumberFormattingAvailable) {
      if (revision == _parseRevision) e164 = null;
      return;
    }

    try {
      final result = await parse(raw, region: selectedCountry?.countryCode);
      if (revision != _parseRevision || number.text.trim() != raw) return;

      final parsedE164 = (result['e164'] as String?)?.trim();
      e164 = parsedE164 == null || parsedE164.isEmpty ? null : parsedE164;

      final regionCode = (result['region_code'] as String?)?.toUpperCase();
      final parsedCountry = countries
          .where((country) => country.countryCode.toUpperCase() == regionCode)
          .firstOrNull;
      if (parsedCountry != null) {
        selectedCountry = parsedCountry;
        countryWasInferred = true;
      }

      if (formatForDisplay) {
        final national = (result['national'] as String?)?.trim();
        if (national != null && national.isNotEmpty) setDisplayText(national);
      }
    } catch (_) {
      if (revision == _parseRevision && number.text.trim() == raw) e164 = null;
    }
  }

  void dispose() {
    type.dispose();
    number.dispose();
    typeFocus.dispose();
    numberFocus.dispose();
  }
}

class _CountryCallingCodeMatch {
  const _CountryCallingCodeMatch({
    required this.phoneCode,
    required this.subscriberDigits,
    required this.countries,
  });

  final String phoneCode;
  final String subscriberDigits;
  final List<CountryWithPhoneCode> countries;
}

_CountryCallingCodeMatch? _countryCallingCodeMatch(
  String value,
  List<CountryWithPhoneCode> countries,
) {
  if (!value.trimLeft().startsWith('+')) return null;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  final matchingCodes = countries
      .map((country) => country.phoneCode)
      .where((phoneCode) => digits.startsWith(phoneCode))
      .toSet();
  if (matchingCodes.isEmpty) return null;

  final phoneCode = matchingCodes.reduce(
    (left, right) => left.length >= right.length ? left : right,
  );
  return _CountryCallingCodeMatch(
    phoneCode: phoneCode,
    subscriberDigits: digits.substring(phoneCode.length),
    countries: countries
        .where((country) => country.phoneCode == phoneCode)
        .toList(),
  );
}

CountryWithPhoneCode? _countryFromInternationalNumber(
  String value,
  List<CountryWithPhoneCode> countries,
) {
  final match = _countryCallingCodeMatch(value, countries);
  return match?.countries.length == 1 ? match!.countries.single : null;
}

int _digitCount(String value) => RegExp(r'\d').allMatches(value).length;

class _AddressDraft {
  _AddressDraft({
    String? type,
    String street = '',
    String zip = '',
    String city = '',
    String region = '',
    String country = '',
  }) : type = TextEditingController(text: type ?? ''),
       street = TextEditingController(text: street),
       zip = TextEditingController(text: zip),
       city = TextEditingController(text: city),
       region = TextEditingController(text: region),
       country = TextEditingController(text: country);

  factory _AddressDraft.fromContact(ContactAddress address) => _AddressDraft(
    type: address.type,
    street: address.street,
    zip: address.zip,
    city: address.city,
    region: address.region,
    country: address.country,
  );

  final Object id = Object();
  final TextEditingController type;
  final TextEditingController street;
  final TextEditingController zip;
  final TextEditingController city;
  final TextEditingController region;
  final TextEditingController country;
  final FocusNode typeFocus = FocusNode();

  bool get hasValue => [
    street.text,
    zip.text,
    city.text,
    region.text,
    country.text,
  ].any((value) => value.trim().isNotEmpty);

  ContactAddress toContact() => ContactAddress(
    street: street.text.trim(),
    zip: zip.text.trim(),
    city: city.text.trim(),
    region: region.text.trim(),
    country: country.text.trim(),
    type: _optional(type.text),
  );

  void dispose() {
    type.dispose();
    street.dispose();
    zip.dispose();
    city.dispose();
    region.dispose();
    country.dispose();
    typeFocus.dispose();
  }
}

class _TextDraft {
  _TextDraft([String value = '']) : value = TextEditingController(text: value);

  final Object id = Object();
  final TextEditingController value;

  void dispose() => value.dispose();
}

class _MediaDraft {
  _MediaDraft(this.uri);

  final Object id = Object();
  final String uri;
}

enum _AdditionalKind {
  website('Website', 'Website URL'),
  gender('Gender', 'Gender'),
  role('Role', 'Role'),
  logo('Logo', 'Logo URL or image data');

  const _AdditionalKind(this.label, this.valueLabel);

  final String label;
  final String valueLabel;
}

class _AdditionalFieldDraft {
  _AdditionalFieldDraft({required this.kind, String value = ''})
    : value = TextEditingController(text: value);

  final Object id = Object();
  final _AdditionalKind kind;
  final TextEditingController value;

  void dispose() => value.dispose();
}

InputDecoration _decoration(BuildContext context, String label) =>
    InputDecoration(
      labelText: label,
      labelStyle: context.theme.meta.copyWith(color: context.theme.textMuted),
      floatingLabelStyle: context.theme.meta.copyWith(
        color: context.theme.textMuted,
      ),
      filled: true,
      fillColor: context.theme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(context.theme.controlRadius),
        borderSide: BorderSide(color: context.theme.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(context.theme.controlRadius),
        borderSide: BorderSide(color: context.theme.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(context.theme.controlRadius),
        borderSide: BorderSide(color: context.theme.brandVault, width: 1.5),
      ),
      isDense: true,
    );

String? _optional(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

List<String> _normalizedGroups(Iterable<String> groups) {
  final seen = <String>{};
  return groups
      .map((group) => group.trim())
      .where((group) => group.isNotEmpty && seen.add(group))
      .toList();
}

void _reorder<T>(List<T> items, int oldIndex, int newIndex) {
  final item = items.removeAt(oldIndex);
  items.insert(newIndex, item);
}

bool get _cameraSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

String _mimeTypeFromPath(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

DateTime? _parseDate(ContactDate? value) {
  if (value == null) return null;
  final year = int.tryParse(value.year);
  final month = int.tryParse(value.month);
  final day = int.tryParse(value.day);
  if (year == null || month == null || day == null) return null;
  try {
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  } on ArgumentError {
    return null;
  }
}

Map<String, String>? _dateFingerprint(ContactDate? value) => value == null
    ? null
    : {'year': value.year, 'month': value.month, 'day': value.day};

String _formatDate(ContactDate? value) {
  if (value == null) return 'Not set';
  final date = _parseDate(value);
  if (date == null) {
    return [
      value.year,
      value.month,
      value.day,
    ].where((part) => part.trim().isNotEmpty).join('-');
  }
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

Uint8List? _dataUriBytes(String value) {
  if (!value.startsWith('data:')) return null;
  try {
    return UriData.parse(value).contentAsBytes();
  } on FormatException {
    return null;
  }
}

String _initials(String value) {
  final initials = value
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();
  return initials.isEmpty ? '?' : initials;
}
