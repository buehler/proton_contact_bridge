import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

class KinCryptActivityIndicator extends StatefulWidget {
  const KinCryptActivityIndicator({
    super.key,
    required this.size,
    this.semanticLabel = 'Loading',
  });

  final double size;
  final String semanticLabel;

  @override
  State<KinCryptActivityIndicator> createState() =>
      _KinCryptActivityIndicatorState();
}

class _KinCryptActivityIndicatorState extends State<KinCryptActivityIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indicator = SizedBox.square(
      dimension: widget.size,
      child: CircularProgressIndicator(
        value: 0.28,
        strokeWidth: (widget.size / 10).clamp(2, 3),
        backgroundColor: context.theme.divider,
        color: context.theme.brandVault,
      ),
    );
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return Semantics(
      label: widget.semanticLabel,
      child: ExcludeSemantics(
        child: disableAnimations
            ? indicator
            : RotationTransition(turns: _controller, child: indicator),
      ),
    );
  }
}
