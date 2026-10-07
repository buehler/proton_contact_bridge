import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;
import 'package:proton_contact_bridge/ui/pages/groups/list.dart';
import 'package:proton_contact_bridge/ui/pages/groups/detail.dart';

import '../../preview/harness.dart';

@widgetbook.UseCase(name: 'Populated', type: GroupsPage)
Widget buildGroupsPagePopulatedUseCase(BuildContext context) =>
    previewPage(context, location: '/groups', state: PreviewState.populated);

@widgetbook.UseCase(name: 'Empty', type: GroupsPage)
Widget buildGroupsPageEmptyUseCase(BuildContext context) =>
    previewPage(context, location: '/groups', state: PreviewState.empty);

@widgetbook.UseCase(name: 'Loading', type: GroupsPage)
Widget buildGroupsPageLoadingUseCase(BuildContext context) =>
    previewPage(context, location: '/groups', state: PreviewState.loading);

@widgetbook.UseCase(name: 'Error', type: GroupsPage)
Widget buildGroupsPageErrorUseCase(BuildContext context) =>
    previewPage(context, location: '/groups', state: PreviewState.error);

@widgetbook.UseCase(name: 'Populated', type: GroupDetailPage)
Widget buildGroupDetailPagePopulatedUseCase(BuildContext context) =>
    previewPage(
      context,
      location: '/groups/Friends',
      state: PreviewState.populated,
      contactControls: true,
      groupControls: true,
    );

@widgetbook.UseCase(name: 'Empty', type: GroupDetailPage)
Widget buildGroupDetailPageEmptyUseCase(BuildContext context) => previewPage(
  context,
  location: '/groups/Friends',
  state: PreviewState.empty,
  contactControls: true,
  groupControls: true,
);

@widgetbook.UseCase(name: 'Loading', type: GroupDetailPage)
Widget buildGroupDetailPageLoadingUseCase(BuildContext context) => previewPage(
  context,
  location: '/groups/Friends',
  state: PreviewState.loading,
  contactControls: true,
  groupControls: true,
);

@widgetbook.UseCase(name: 'Error', type: GroupDetailPage)
Widget buildGroupDetailPageErrorUseCase(BuildContext context) => previewPage(
  context,
  location: '/groups/Friends',
  state: PreviewState.error,
  contactControls: true,
  groupControls: true,
);
