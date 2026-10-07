import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:proton_contact_bridge/ui/pages/contacts/list.dart';
import 'package:proton_contact_bridge/ui/pages/contacts/detail.dart';
import 'package:proton_contact_bridge/ui/pages/contacts/edit.dart';

import '../../preview/harness.dart';

@widgetbook.UseCase(name: 'Populated', type: ContactsPage)
Widget buildContactsPagePopulatedUseCase(BuildContext context) => previewPage(
  context,
  location: '/contacts',
  state: PreviewState.populated,
  contactControls: true,
);

@widgetbook.UseCase(name: 'Empty', type: ContactsPage)
Widget buildContactsPageEmptyUseCase(BuildContext context) => previewPage(
  context,
  location: '/contacts',
  state: PreviewState.empty,
  contactControls: true,
);

@widgetbook.UseCase(name: 'Loading', type: ContactsPage)
Widget buildContactsPageLoadingUseCase(BuildContext context) => previewPage(
  context,
  location: '/contacts',
  state: PreviewState.loading,
  contactControls: true,
);

@widgetbook.UseCase(name: 'Error', type: ContactsPage)
Widget buildContactsPageErrorUseCase(BuildContext context) => previewPage(
  context,
  location: '/contacts',
  state: PreviewState.error,
  contactControls: true,
);

@widgetbook.UseCase(name: 'Full', type: ContactDetailPage)
Widget buildContactDetailPageFullUseCase(BuildContext context) => previewPage(
  context,
  location: '/contacts/maya',
  state: PreviewState.populated,
  contactControls: true,
  detailControls: true,
);

@widgetbook.UseCase(name: 'Minimal', type: ContactDetailPage)
Widget buildContactDetailPageMinimalUseCase(BuildContext context) =>
    previewPage(
      context,
      location: '/contacts/maya',
      state: PreviewState.minimal,
      contactControls: true,
      detailControls: true,
    );

@widgetbook.UseCase(name: 'Missing', type: ContactDetailPage)
Widget buildContactDetailPageMissingUseCase(BuildContext context) =>
    previewPage(
      context,
      location: '/contacts/maya',
      state: PreviewState.missing,
      contactControls: true,
      detailControls: true,
    );

@widgetbook.UseCase(name: 'Loading', type: ContactDetailPage)
Widget buildContactDetailPageLoadingUseCase(BuildContext context) =>
    previewPage(
      context,
      location: '/contacts/maya',
      state: PreviewState.loading,
      contactControls: true,
      detailControls: true,
    );

@widgetbook.UseCase(name: 'Error', type: ContactDetailPage)
Widget buildContactDetailPageErrorUseCase(BuildContext context) => previewPage(
  context,
  location: '/contacts/maya',
  state: PreviewState.error,
  contactControls: true,
  detailControls: true,
);

@widgetbook.UseCase(name: 'New contact', type: ContactEditPage)
Widget buildContactEditPageNewContactUseCase(BuildContext context) =>
    previewPage(
      context,
      location: '/contacts/new',
      state: PreviewState.populated,
      contactControls: true,
    );

@widgetbook.UseCase(name: 'Existing contact', type: ContactEditPage)
Widget buildContactEditPageExistingContactUseCase(BuildContext context) =>
    previewPage(
      context,
      location: '/contacts/maya/edit',
      state: PreviewState.populated,
      contactControls: true,
    );

@widgetbook.UseCase(name: 'Loading', type: ContactEditPage)
Widget buildContactEditPageLoadingUseCase(BuildContext context) => previewPage(
  context,
  location: '/contacts/maya/edit',
  state: PreviewState.loading,
  contactControls: true,
);

@widgetbook.UseCase(name: 'Error', type: ContactEditPage)
Widget buildContactEditPageErrorUseCase(BuildContext context) => previewPage(
  context,
  location: '/contacts/maya/edit',
  state: PreviewState.error,
  contactControls: true,
);
