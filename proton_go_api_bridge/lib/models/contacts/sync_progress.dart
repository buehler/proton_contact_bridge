import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_progress.freezed.dart';

@freezed
sealed class ContactSyncProgress with _$ContactSyncProgress {
  const factory ContactSyncProgress(int processed, int total) =
      _ContactSyncProgress;
}
