import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:proton_go_api_bridge/src/protobuf/models/models.pb.dart'
    as models;

part 'group.freezed.dart';

@freezed
sealed class Group with _$Group {
  const factory Group({required String name}) = _Group;

  factory Group.fromProto(models.Group proto) => Group(name: proto.name);
}
