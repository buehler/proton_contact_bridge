import 'package:flutter/material.dart';

class LoginShell extends StatelessWidget {
  const LoginShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    extendBodyBehindAppBar: true,
    extendBody: true,
    body: SafeArea(child: child),
  );
}
