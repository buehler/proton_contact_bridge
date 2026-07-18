import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proton_contact_bridge/ui/components/button.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

enum TextFieldType {
  email,
  usernameOrEmail,
  password,
  number,
  url,
  search,
  multiline,
  text,
}

class KinCryptTextField extends StatelessWidget {
  const KinCryptTextField({
    super.key,
    this.type = TextFieldType.text,
    this.autofocus = false,
    this.hint,
    this.label,
    this.controller,
    this.focusNode,
    this.initialValue,
    this.enabled = true,
    this.readOnly = false,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.suffix,
    this.minLines,
    this.maxLines,
    this.textInputAction,
    this.keyboardType,
    this.textCapitalization,
    this.autofillHints,
    this.inputFormatters,
    this.obscureText,
    this.onChanged,
    this.onSubmitted,
    this.validator,
  }) : assert(
         controller == null || initialValue == null,
         'controller and initialValue cannot both be supplied',
       );

  final TextFieldType type;
  final bool autofocus;
  final String? hint;
  final String? label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? initialValue;
  final bool enabled;
  final bool readOnly;
  final String? errorText;
  final String? helperText;
  final Widget? prefixIcon;
  final Widget? suffix;
  final int? minLines;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final TextCapitalization? textCapitalization;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool? obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.theme.controlRadius);
    final isMultiline = type == TextFieldType.multiline;
    final effectiveObscureText = obscureText ?? type == TextFieldType.password;
    final effectiveMaxLines = effectiveObscureText
        ? 1
        : maxLines ?? (isMultiline ? null : minLines ?? 1);

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      initialValue: initialValue,
      enabled: enabled,
      readOnly: readOnly,
      autofocus: autofocus,
      autocorrect: _autocorrect,
      enableSuggestions: type != TextFieldType.password,
      obscureText: effectiveObscureText,
      minLines: effectiveObscureText ? 1 : minLines,
      maxLines: effectiveMaxLines,
      keyboardType: keyboardType ?? _keyboardType,
      textInputAction: textInputAction ?? _textInputAction,
      textCapitalization: textCapitalization ?? _textCapitalization,
      autofillHints: autofillHints ?? _autofillHints,
      inputFormatters: inputFormatters,
      style: context.theme.body.copyWith(color: context.theme.textPrimary),
      cursorColor: context.theme.brandVault,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        helperText: helperText,
        prefixIcon: prefixIcon,
        suffixIcon: suffix,
        filled: true,
        fillColor: context.theme.surface,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: context.theme.meta.copyWith(color: context.theme.textMuted),
        floatingLabelStyle: context.theme.meta.copyWith(
          color: context.theme.textMuted,
        ),
        hintStyle: context.theme.body.copyWith(color: context.theme.textMuted),
        helperStyle: context.theme.meta.copyWith(
          color: context.theme.textMuted,
        ),
        errorStyle: context.theme.meta.copyWith(color: context.theme.danger),
        contentPadding: EdgeInsets.symmetric(
          horizontal: context.theme.spaceMd,
          vertical: context.theme.spaceMd,
        ),
        constraints: BoxConstraints(
          minHeight: isMultiline ? 88 : context.theme.minimumTouchTarget,
        ),
        border: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: context.theme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: context.theme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: context.theme.brandVault, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: context.theme.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: context.theme.danger, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(
            color: context.theme.divider.withValues(alpha: 0.65),
          ),
        ),
      ),
    );
  }

  bool get _autocorrect => switch (type) {
    TextFieldType.text ||
    TextFieldType.multiline ||
    TextFieldType.search => true,
    _ => false,
  };

  TextInputType get _keyboardType => switch (type) {
    TextFieldType.email ||
    TextFieldType.usernameOrEmail => TextInputType.emailAddress,
    TextFieldType.password ||
    TextFieldType.text ||
    TextFieldType.search => TextInputType.text,
    TextFieldType.number => TextInputType.number,
    TextFieldType.url => TextInputType.url,
    TextFieldType.multiline => TextInputType.multiline,
  };

  TextInputAction get _textInputAction => switch (type) {
    TextFieldType.search => TextInputAction.search,
    TextFieldType.multiline => TextInputAction.newline,
    _ => TextInputAction.next,
  };

  TextCapitalization get _textCapitalization => switch (type) {
    TextFieldType.text ||
    TextFieldType.multiline => TextCapitalization.sentences,
    _ => TextCapitalization.none,
  };

  Iterable<String>? get _autofillHints => switch (type) {
    TextFieldType.email => const [AutofillHints.email],
    TextFieldType.usernameOrEmail => const [AutofillHints.username],
    TextFieldType.password => const [AutofillHints.password],
    TextFieldType.url => const [AutofillHints.url],
    _ => null,
  };
}

class KinCryptSearchField extends StatefulWidget {
  const KinCryptSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.clearSemanticLabel = 'Clear search',
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final String clearSemanticLabel;

  @override
  State<KinCryptSearchField> createState() => _KinCryptSearchFieldState();
}

class _KinCryptSearchFieldState extends State<KinCryptSearchField> {
  late TextEditingController _controller;
  late bool _ownsController;

  @override
  void initState() {
    super.initState();
    _setController(widget.controller);
  }

  @override
  void didUpdateWidget(KinCryptSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (_ownsController) _controller.dispose();
      _setController(widget.controller);
    }
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _setController(TextEditingController? controller) {
    _ownsController = controller == null;
    _controller = controller ?? TextEditingController();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: _controller,
        builder: (context, value, _) => KinCryptTextField(
          type: TextFieldType.search,
          controller: _controller,
          focusNode: widget.focusNode,
          hint: widget.hint,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          prefixIcon: Icon(
            Icons.search,
            color: context.theme.textMuted,
            size: 20,
          ),
          suffix: value.text.isEmpty
              ? null
              : KinCryptIconButton(
                  icon: Icons.close,
                  semanticLabel: widget.clearSemanticLabel,
                  onPressed: widget.enabled ? _clear : null,
                ),
        ),
      );
}
