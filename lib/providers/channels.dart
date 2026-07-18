import 'package:proton_contact_bridge/method_channels/contact_provider_channel.dart';
import 'package:proton_contact_bridge/method_channels/native_path_channel.dart';
import 'package:proton_contact_bridge/providers/proton.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'channels.g.dart';

@riverpod
Future<ContactProviderChannel> contactProviderChannel(Ref ref) async {
  final api = await ref.watch(protonApiProvider.future);
  return ContactProviderChannel(api);
}

@riverpod
NativePathChannel nativePathChannel(Ref ref) => NativePathChannel();
