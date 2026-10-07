import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:proton_contact_bridge/ui/pages/boot.dart';

import '../../preview/harness.dart';

@widgetbook.UseCase(name: 'Default', type: BootPage)
Widget buildBootPageDefaultUseCase(BuildContext context) =>
    previewPage(context, location: '/boot', state: PreviewState.populated);
