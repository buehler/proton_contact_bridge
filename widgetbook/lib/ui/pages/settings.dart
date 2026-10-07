import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:proton_contact_bridge/ui/pages/settings.dart';

import '../../preview/harness.dart';

@widgetbook.UseCase(name: 'Default', type: SettingsPage)
Widget buildSettingsPageDefaultUseCase(BuildContext context) => previewPage(
  context,
  location: '/settings',
  state: PreviewState.populated,
  settingsControls: true,
);

@widgetbook.UseCase(name: 'Loading', type: SettingsPage)
Widget buildSettingsPageLoadingUseCase(BuildContext context) => previewPage(
  context,
  location: '/settings',
  state: PreviewState.loading,
  settingsControls: true,
);

@widgetbook.UseCase(name: 'Error', type: SettingsPage)
Widget buildSettingsPageErrorUseCase(BuildContext context) => previewPage(
  context,
  location: '/settings',
  state: PreviewState.error,
  settingsControls: true,
);
