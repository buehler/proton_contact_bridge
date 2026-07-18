import 'package:flutter/material.dart';
import 'package:proton_contact_bridge/ui/foundation/extensions.dart';

enum KinCryptChoiceLayout { adaptive, segmented, stacked }

class KinCryptChoice<T> {
  const KinCryptChoice({
    required this.value,
    required this.label,
    this.description,
  });

  final T value;
  final String label;
  final String? description;
}

class KinCryptChoiceControl<T> extends StatelessWidget {
  const KinCryptChoiceControl({
    super.key,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.layout = KinCryptChoiceLayout.adaptive,
    this.enabled = true,
    this.semanticLabel,
  }) : assert(choices.length > 1, 'At least two choices are required');

  final List<KinCryptChoice<T>> choices;
  final T value;
  final ValueChanged<T>? onChanged;
  final KinCryptChoiceLayout layout;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: semanticLabel,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final useStacked = switch (layout) {
          KinCryptChoiceLayout.stacked => true,
          KinCryptChoiceLayout.segmented => false,
          KinCryptChoiceLayout.adaptive =>
            MediaQuery.textScalerOf(context).scale(1) > 1.3 ||
                constraints.maxWidth < choices.length * 124,
        };

        return useStacked
            ? _StackedChoices<T>(
                choices: choices,
                value: value,
                onChanged: onChanged,
                enabled: enabled,
              )
            : _SegmentedChoices<T>(
                choices: choices,
                value: value,
                onChanged: onChanged,
                enabled: enabled,
              );
      },
    ),
  );
}

class _SegmentedChoices<T> extends StatelessWidget {
  const _SegmentedChoices({
    required this.choices,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final List<KinCryptChoice<T>> choices;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(context.theme.spaceXs),
    decoration: BoxDecoration(
      color: context.theme.surfaceSoft,
      borderRadius: BorderRadius.circular(context.theme.controlRadius),
    ),
    child: Row(
      children: [
        for (final choice in choices)
          Expanded(
            child: _ChoiceTarget<T>(
              choice: choice,
              selected: choice.value == value,
              enabled: enabled,
              onChanged: onChanged,
              segmented: true,
            ),
          ),
      ],
    ),
  );
}

class _StackedChoices<T> extends StatelessWidget {
  const _StackedChoices({
    required this.choices,
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final List<KinCryptChoice<T>> choices;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < choices.length; index++) ...[
        _ChoiceTarget<T>(
          choice: choices[index],
          selected: choices[index].value == value,
          enabled: enabled,
          onChanged: onChanged,
          segmented: false,
        ),
        if (index < choices.length - 1)
          Divider(height: 1, color: context.theme.divider),
      ],
    ],
  );
}

class _ChoiceTarget<T> extends StatelessWidget {
  const _ChoiceTarget({
    required this.choice,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.segmented,
  });

  final KinCryptChoice<T> choice;
  final bool selected;
  final bool enabled;
  final ValueChanged<T>? onChanged;
  final bool segmented;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onChanged != null;
    final description = choice.description;
    final foreground = selected
        ? context.theme.brandVault
        : context.theme.textMuted;
    final radius = BorderRadius.circular(context.theme.controlRadius - 4);

    return Semantics(
      button: true,
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: interactive,
      label: choice.label,
      hint: choice.description,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: context.theme.minimumTouchTarget,
        ),
        child: Material(
          color: segmented && selected
              ? context.theme.selectedSurface
              : Colors.transparent,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: interactive ? () => onChanged!(choice.value) : null,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: context.theme.spaceMd,
                vertical: context.theme.spaceSm,
              ),
              child: Row(
                mainAxisAlignment: segmented
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  if (!segmented) ...[
                    _SelectionMark(selected: selected, enabled: enabled),
                    SizedBox(width: context.theme.spaceMd),
                  ],
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: segmented
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          choice.label,
                          textAlign: segmented ? TextAlign.center : null,
                          style: context.theme.button.copyWith(
                            color: enabled
                                ? foreground
                                : foreground.withValues(alpha: 0.55),
                          ),
                        ),
                        if (!segmented && description != null) ...[
                          SizedBox(height: context.theme.spaceXs),
                          Text(
                            description,
                            style: context.theme.meta.copyWith(
                              color: context.theme.textMuted,
                            ),
                          ),
                        ],
                      ],
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
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected, required this.enabled});

  final bool selected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? context.theme.brandVault
        : context.theme.textMuted.withValues(alpha: 0.55);

    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: selected ? 6 : 1.5),
      ),
    );
  }
}
