import 'package:proton_contact_bridge/method_channels/contact_provider_channel.dart';
import 'package:proton_contact_bridge/method_channels/native_path_channel.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'channels.g.dart';

@riverpod
ContactProviderChannel contactProviderChannel(Ref ref) =>
    ContactProviderChannel();

@riverpod
NativePathChannel nativePathChannel(Ref ref) => NativePathChannel();
