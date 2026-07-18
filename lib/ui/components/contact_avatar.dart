import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';
import 'package:proton_go_api_bridge/models/contacts/contact.dart';

class ContactAvatar extends StatelessWidget {
  const ContactAvatar({
    super.key,
    required this.contact,
    required this.displayName,
    this.radius = 20,
    this.initialsStyle,
    this.showFavoriteBadge = false,
    this.unavailable = false,
    this.semanticLabel,
  });

  final Contact contact;
  final String displayName;
  final double radius;
  final TextStyle? initialsStyle;
  final bool showFavoriteBadge;
  final bool unavailable;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final photo = contact.photos
        .map((photo) => photo.uri.trim())
        .where((uri) => uri.isNotEmpty)
        .firstOrNull;
    final avatar = unavailable
        ? _UnavailableAvatar(radius: radius)
        : photo == null
        ? _InitialsAvatar(
            displayName: displayName,
            radius: radius,
            textStyle: initialsStyle,
          )
        : _PhotoAvatar(
            uri: photo,
            radius: radius,
            fallback: _InitialsAvatar(
              displayName: displayName,
              radius: radius,
              textStyle: initialsStyle,
            ),
          );

    return Semantics(
      image: true,
      label: semanticLabel ?? '$displayName avatar',
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: radius * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(child: avatar),
              if (showFavoriteBadge && contact.isFavorite)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: context.theme.surface,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      LucideIcons.star,
                      size: 14,
                      color: context.theme.brandVault,
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

class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar({
    required this.uri,
    required this.radius,
    required this.fallback,
  });

  final String uri;
  final double radius;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    final bytes = _dataUriBytes(uri);
    return ClipOval(
      child: SizedBox.square(
        dimension: radius * 2,
        child: bytes != null
            ? Image.memory(
                bytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: _error,
              )
            : Image.network(
                uri,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: _error,
              ),
      ),
    );
  }

  Widget _error(BuildContext context, Object error, StackTrace? stackTrace) =>
      fallback;
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.displayName,
    required this.radius,
    this.textStyle,
  });

  final String displayName;
  final double radius;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(displayName);
    return CircleAvatar(
      radius: radius,
      backgroundColor: context.theme.selectedSurface,
      child: initials.isEmpty
          ? Icon(
              Icons.person_outline,
              size: radius,
              color: context.theme.brandVault,
            )
          : Text(
              initials,
              style:
                  textStyle ??
                  context.theme.button.copyWith(
                    color: context.theme.brandVault,
                  ),
            ),
    );
  }
}

class _UnavailableAvatar extends StatelessWidget {
  const _UnavailableAvatar({required this.radius});

  final double radius;

  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: radius,
    backgroundColor: context.theme.surfaceSoft,
    child: Icon(
      Icons.person_off_outlined,
      size: radius,
      color: context.theme.textMuted,
    ),
  );
}

String _initials(String displayName) => displayName
    .split(RegExp(r'\s+'))
    .where((part) => part.isNotEmpty)
    .take(2)
    .map((part) => part[0])
    .join()
    .toUpperCase();

Uint8List? _dataUriBytes(String value) {
  if (!value.startsWith('data:')) {
    return null;
  }

  try {
    return UriData.parse(value).contentAsBytes();
  } on FormatException {
    return null;
  }
}
