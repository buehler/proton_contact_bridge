import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptConfirmationBottomSheet extends StatelessWidget {
  const KinCryptConfirmationBottomSheet({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel = 'Cancel',
    this.confirmStyle = KinCryptButtonStyle.danger,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final KinCryptButtonStyle confirmStyle;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      padding: EdgeInsets.all(context.theme.spaceLg),
      decoration: BoxDecoration(
        color: context.theme.surface,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.theme.containerRadius),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          KinCryptText(title, variant: KinCryptTextVariant.sectionTitle),
          SizedBox(height: context.theme.spaceSm),
          KinCryptText(message),
          SizedBox(height: context.theme.spaceXl),
          KinCryptButton(
            label: confirmLabel,
            stretch: true,
            style: confirmStyle,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          SizedBox(height: context.theme.spaceSm),
          KinCryptButton(
            label: cancelLabel,
            stretch: true,
            style: KinCryptButtonStyle.secondary,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ),
  );
}

class KinCryptLogoutBottomSheet extends StatelessWidget {
  const KinCryptLogoutBottomSheet({super.key});

  @override
  Widget build(BuildContext context) => const KinCryptConfirmationBottomSheet(
    title: 'Log out of KinCrypt?',
    message: 'Contact data still remains in Proton. KinCrypt will return to sign in.',
    confirmLabel: 'Log out',
  );
}

// part 'bottomsheets.freezed.dart';

// @freezed
// sealed class KinCryptBottomSheetResult<T> with _$KinCryptBottomSheetResult {
//   const factory KinCryptBottomSheetResult.canceled() = Canceled;
//   const factory KinCryptBottomSheetResult.confirmed(T result) = Confirmed;
// }

// abstract class KinCryptBottomSheet<T> extends StatelessWidget {
//   final VoidCallback onCancel;
//   final Function(T) onConfirm;

//   const KinCryptBottomSheet({
//     super.key,
//     required this.onCancel,
//     required this.onConfirm,
//   });

//   T get result;
// }

// abstract class KinCryptConfirmBottomSheet extends KinCryptBottomSheet<bool> {
//   const KinCryptConfirmBottomSheet({
//     super.key,
//     required super.onCancel,
//     required super.onConfirm,
//   });
// }

// class KinCryptLogoutConfirmBottomSheet extends KinCryptConfirmBottomSheet {
//   const KinCryptLogoutConfirmBottomSheet({super.key});

//   @override
//   Widget build(BuildContext context) {
//     throw UnimplementedError();
//   }

//   @override
//   bool get result => throw UnimplementedError();
// }
