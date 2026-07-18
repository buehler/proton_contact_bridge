import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptOneTimeCodeField extends StatefulWidget {
  const KinCryptOneTimeCodeField({
    super.key,
    this.controller,
    this.focusNode,
    this.length = 6,
    this.enabled = true,
    this.autofocus = false,
    this.errorText,
    this.onChanged,
    this.onCompleted,
    this.semanticLabel = 'One-time code',
  }) : assert(length > 0);

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final int length;
  final bool enabled;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final String semanticLabel;

  @override
  State<KinCryptOneTimeCodeField> createState() =>
      _KinCryptOneTimeCodeFieldState();
}

class _KinCryptOneTimeCodeFieldState extends State<KinCryptOneTimeCodeField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  late bool _ownsController;
  late bool _ownsFocusNode;
  String? _lastCompletedCode;

  @override
  void initState() {
    super.initState();
    _setController(widget.controller);
    _setFocusNode(widget.focusNode);
  }

  @override
  void didUpdateWidget(KinCryptOneTimeCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleValueChanged);
      if (_ownsController) _controller.dispose();
      _setController(widget.controller);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChanged);
      if (_ownsFocusNode) _focusNode.dispose();
      _setFocusNode(widget.focusNode);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleValueChanged);
    _focusNode.removeListener(_handleFocusChanged);
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _setController(TextEditingController? controller) {
    _ownsController = controller == null;
    _controller = controller ?? TextEditingController();
    _controller.addListener(_handleValueChanged);
  }

  void _setFocusNode(FocusNode? focusNode) {
    _ownsFocusNode = focusNode == null;
    _focusNode = focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  void _handleValueChanged() {
    final code = _controller.text;
    widget.onChanged?.call(code);

    if (code.length == widget.length) {
      if (_lastCompletedCode != code) {
        _lastCompletedCode = code;
        widget.onCompleted?.call(code);
      }
    } else {
      _lastCompletedCode = null;
    }

    if (mounted) setState(() {});
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text;
    final activeIndex = value.length.clamp(0, widget.length - 1);
    final hasError = widget.errorText != null;

    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      enabled: widget.enabled,
      value: value.isEmpty
          ? 'Empty'
          : '${value.length} of ${widget.length} digits',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Stack(
              children: [
                ExcludeSemantics(
                  child: Row(
                    children: [
                      for (var index = 0; index < widget.length; index++) ...[
                        if (index > 0) SizedBox(width: context.theme.spaceSm),
                        Expanded(
                          child: _CodeCell(
                            digit: index < value.length ? value[index] : '',
                            active:
                                widget.enabled &&
                                _focusNode.hasFocus &&
                                index == activeIndex,
                            hasError: hasError,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Positioned.fill(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: widget.enabled,
                    autofocus: widget.autofocus,
                    autocorrect: false,
                    enableSuggestions: false,
                    showCursor: false,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    style: const TextStyle(color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      filled: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.errorText case final error?) ...[
            SizedBox(height: context.theme.spaceSm),
            KinCryptText(
              error,
              variant: KinCryptTextVariant.meta,
              color: context.theme.danger,
            ),
          ],
        ],
      ),
    );
  }
}

class _CodeCell extends StatelessWidget {
  const _CodeCell({
    required this.digit,
    required this.active,
    required this.hasError,
  });

  final String digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.theme.surface,
      borderRadius: BorderRadius.circular(context.theme.controlRadius),
      border: Border.all(
        width: active ? 1.5 : 1,
        color: hasError
            ? context.theme.danger
            : active
            ? context.theme.brandVault
            : context.theme.divider,
      ),
    ),
    child: Text(
      digit,
      style: context.theme.sectionTitle.copyWith(
        color: context.theme.textPrimary,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}
