import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

const supportedOS = [OS.iOS, OS.macOS, OS.android];

String _mapToGoOS(OS os) => switch (os) {
  OS.iOS => 'ios',
  OS.macOS => 'darwin',
  OS.android => 'android',
  _ => throw Exception('Unsupported OS'),
};

String _mapToGoArch(Architecture arch) => switch (arch) {
  Architecture.arm64 => 'arm64',
  Architecture.x64 => 'amd64',
  Architecture.arm => 'arm',
  Architecture.ia32 => '386',
  _ => throw Exception('Unsupported Architecture'),
};

String _mapToAndroidTarget(Architecture arch) => switch (arch) {
  Architecture.arm64 => 'aarch64-linux-android',
  Architecture.x64 => 'x86_64-linux-android',
  Architecture.arm => 'armv7a-linux-androideabi',
  Architecture.ia32 => 'i686-linux-android',
  _ => throw Exception('Unsupported Android architecture'),
};

String _mapToAppleTarget(Architecture arch) => switch (arch) {
  Architecture.arm64 => 'arm64',
  Architecture.x64 => 'x86_64',
  _ => throw Exception('Unsupported Apple architecture'),
};

Future<String> _xcrun(String sdk, List<String> arguments) async {
  final result = await Process.run('xcrun', ['--sdk', sdk, ...arguments]);
  if (result.exitCode != 0) {
    throw Exception('xcrun failed for SDK $sdk: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }

    final targetOS = input.config.code.targetOS;
    final targetArch = input.config.code.targetArchitecture;

    // The hook cache does not automatically track files read by external
    // tools such as `go build`. Declare the Go source tree so changes to the
    // bridge invalidate this hook's cached native asset.
    output.dependencies.add(input.packageRoot.resolve('src/'));
    final srcDir = Directory.fromUri(input.packageRoot.resolve('src/'));
    if (await srcDir.exists()) {
      await for (final entity in srcDir.list(recursive: true)) {
        if (entity is File) {
          // Only track actual source code files
          final path = entity.path;
          final fileName = entity.uri.pathSegments.last;
          final trackedExtension =
              path.endsWith('.go') ||
              path.endsWith('.c') ||
              path.endsWith('.cc') ||
              path.endsWith('.cpp') ||
              path.endsWith('.m') ||
              path.endsWith('.mm') ||
              path.endsWith('.h') ||
              path.endsWith('.s') ||
              path.endsWith('.S') ||
              path.endsWith('.sql');
          if (trackedExtension ||
              fileName == 'go.mod' ||
              fileName == 'go.sum') {
            output.dependencies.add(entity.uri);
          }
        }
      }
    }

    final packageName = input.packageName;
    // Match ffigen's default @Native asset ID for lib/src/bindings.g.dart.
    final assetName = 'src/bindings.g.dart';

    if (!supportedOS.contains(targetOS)) {
      throw Exception(
        'Target OS $targetOS not supported by this build script.',
      );
    }

    final goOS = _mapToGoOS(targetOS);
    final goArch = _mapToGoArch(targetArch);
    print('Building for Go target: $goOS/$goArch');

    final outUri = input.outputDirectory.resolve(switch (targetOS) {
      OS.iOS || OS.macOS => 'libbridge.dylib',
      OS.android => 'libbridge_android.so',
      _ => throw Exception('Unsupported OS'),
    });
    final intermediateStaticUri = input.outputDirectory.resolve(
      'libbridge_intermediate.a',
    );

    final cCompiler = input.config.code.cCompiler;
    if (cCompiler == null) {
      throw Exception('No C compiler was provided for $goOS/$goArch.');
    }

    final environment = <String, String>{
      ...Platform.environment,
      'GOOS': goOS,
      'GOARCH': goArch,
      'CGO_ENABLED': '1',
    };
    String? iosSdkPath;
    String? iosTargetTriple;

    if (targetOS == OS.iOS) {
      final iosConfig = input.config.code.iOS;

      final sdk = switch (iosConfig.targetSdk) {
        IOSSdk.iPhoneOS => 'iphoneos',
        IOSSdk.iPhoneSimulator => 'iphonesimulator',
        _ => throw Exception('Unsupported iOS SDK: ${iosConfig.targetSdk}.'),
      };
      final sdkPath = await _xcrun(sdk, ['--show-sdk-path']);
      final compiler = cCompiler.compiler.toFilePath();

      final isSimulator = sdk == 'iphonesimulator';
      final targetTriple =
          '${_mapToAppleTarget(targetArch)}-apple-ios${iosConfig.targetVersion}${isSimulator ? '-simulator' : ''}';

      final cgoFlags = '-isysroot $sdkPath -target $targetTriple';
      iosSdkPath = sdkPath;
      iosTargetTriple = targetTriple;

      environment.addAll({
        'CC': compiler,
        'SDKROOT': sdkPath,
        'CGO_CFLAGS': cgoFlags,
        'CGO_LDFLAGS': cgoFlags,
      });
    } else if (targetOS == OS.macOS) {
      final macOSConfig = input.config.code.macOS;
      final sdkPath = await _xcrun('macosx', ['--show-sdk-path']);
      final compiler = cCompiler.compiler.toFilePath();
      final targetVersion = '${macOSConfig.targetVersion}.0';
      final targetTriple =
          '${_mapToAppleTarget(targetArch)}-apple-macos$targetVersion';

      final cgoFlags = '-isysroot $sdkPath -target $targetTriple';

      environment.addAll({
        'CC': compiler,
        'SDKROOT': sdkPath,
        'MACOSX_DEPLOYMENT_TARGET': targetVersion,
        'CGO_CFLAGS': cgoFlags,
        'CGO_LDFLAGS': cgoFlags,
      });
    } else {
      final androidApi = input.config.code.android.targetNdkApi;
      final target = '${_mapToAndroidTarget(targetArch)}$androidApi';
      final compiler = cCompiler.compiler.toFilePath();
      final targetFlag = '--target=$target';

      environment.addAll({
        'CC': '$compiler $targetFlag',
        'CGO_CFLAGS': targetFlag,
        'CGO_LDFLAGS': targetFlag,
      });
    }

    final isIOS = targetOS == OS.iOS;

    final goOutputUri = isIOS ? intermediateStaticUri : outUri;
    final goBuildMode = isIOS ? '-buildmode=c-archive' : '-buildmode=c-shared';

    final goResult = await Process.run(
      'go',
      ['build', goBuildMode, '-o', goOutputUri.toFilePath(), '.'],
      workingDirectory: input.packageRoot.resolve('src').toFilePath(),
      environment: environment,
    );

    if (goResult.exitCode != 0) {
      print('Go Build Error Log:');
      print(goResult.stdout);
      print(goResult.stderr);
      throw Exception('Go compilation failed for $goOS/$goArch');
    }

    if (targetOS == OS.iOS) {
      final clangResult = await Process.run(cCompiler.compiler.toFilePath(), [
        '-shared',
        '-isysroot',
        iosSdkPath!,
        '-target',
        iosTargetTriple!,
        '-Wl,-all_load',
        '-framework',
        'CoreFoundation',
        '-framework',
        'Security',
        '-framework',
        'Foundation',
        '-o',
        outUri.toFilePath(),
        intermediateStaticUri.toFilePath(),
      ]);

      if (clangResult.exitCode != 0) {
        print('Apple Clang Wrapper Error Log:');
        print(clangResult.stdout);
        print(clangResult.stderr);
        throw Exception(
          'Failed to wrap Go archive as a dynamic iOS library for '
          '$iosTargetTriple',
        );
      }
    }

    output.assets.code.add(
      CodeAsset(
        package: packageName,
        name: assetName,
        linkMode: DynamicLoadingBundled(),
        file: outUri,
      ),
    );
  });
}
