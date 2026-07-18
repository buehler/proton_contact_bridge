import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:proton_contact_bridge/providers/proton_auth.dart';
import 'package:proton_contact_bridge/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GoogleFonts.pendingFonts([
    GoogleFonts.hankenGrotesk(),
    GoogleFonts.inter(),
    GoogleFonts.jetBrainsMono(),
  ]);
  runApp(const ProviderScope(child: ProtonContactBridgeApp()));
}

class ProtonContactBridgeApp extends ConsumerWidget {
  const ProtonContactBridgeApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(protonAuthProvider).attemptLocalLogin();
    return MaterialApp.router(
      title: 'Flutter Demo',
      theme: FlexThemeData.light(scheme: FlexScheme.aquaBlue),
      darkTheme: FlexThemeData.dark(scheme: FlexScheme.aquaBlue),
      themeMode: ThemeMode.system,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

// class MyHomePage extends StatefulWidget {
//   const MyHomePage({super.key, required this.title});
//   final String title;

//   @override
//   State<MyHomePage> createState() => _MyHomePageState();
// }

// class _MyHomePageState extends State<MyHomePage> {
//   final _usernameController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _totpController = TextEditingController();

//   @override
//   void initState() {
//     ProtonAuth.attemptLocalLogin();
//     super.initState();
//   }

//   @override
//   void dispose() {
//     _usernameController.dispose();
//     _passwordController.dispose();
//     _totpController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
//         title: Text(widget.title),
//       ),
//       body: Center(
//         child: Column(
//           mainAxisAlignment: .center,
//           children: [
//             const Text('Demo UI'),
//             StreamBuilder(
//               stream: ProtonAuth.stateStream,
//               builder: (ctx, snap) {
//                 print('state: ${snap.data}');
//                 return switch (snap.data) {
//                   LoggedIn(session: AuthSession(:final userId)) => Column(
//                     children: [
//                       Text('Logged in as $userId'),
//                       ElevatedButton(
//                         onPressed: () async {
//                           await ProtonAuth.logout();
//                         },
//                         child: const Text('Logout'),
//                       ),
//                       ElevatedButton(
//                         onPressed: () async {
//                           final api = ProtonContacts();
//                           await api.testContextFetch();
//                         },
//                         child: const Text('TestCall'),
//                       ),
//                     ],
//                   ),
//                   Initial() => Column(
//                     children: [
//                       const Text('Login'),
//                       TextField(
//                         controller: _usernameController,
//                         decoration: const InputDecoration(
//                           labelText: 'Username',
//                         ),
//                       ),
//                       TextField(
//                         controller: _passwordController,
//                         decoration: const InputDecoration(
//                           labelText: 'Password',
//                         ),
//                         obscureText: true,
//                       ),
//                       ElevatedButton(
//                         onPressed: () async {
//                           await ProtonAuth.login(
//                             username: _usernameController.text,
//                             password: _passwordController.text,
//                             onHumanVerificationRequest:
//                                 _humanVerificationRequest,
//                           );
//                         },
//                         child: const Text('Login'),
//                       ),
//                     ],
//                   ),
//                   RequireTwoFactor(
//                     twoFactorInfo: TwoFactorInfo(hasTOTP: true),
//                   ) =>
//                     Column(
//                       children: [
//                         const Text('2FA required, enter TOTP code'),
//                         TextField(
//                           controller: _totpController,
//                           keyboardType: TextInputType.number,
//                         ),
//                         ElevatedButton(
//                           onPressed: () async {
//                             ProtonAuth.submitTotp(_totpController.text);
//                           },
//                           child: const Text('Submit TOTP'),
//                         ),
//                       ],
//                     ),
//                   Error(:final exception) => Column(
//                     children: [
//                       Text('Error: $exception'),
//                       ElevatedButton(
//                         onPressed: () => ProtonAuth.reset(),
//                         child: const Text('Reset'),
//                       ),
//                     ],
//                   ),
//                   _ => const CircularProgressIndicator(),
//                 };
//               },
//             ),
//           ],
//         ),
//       ),
//     );
//   }
