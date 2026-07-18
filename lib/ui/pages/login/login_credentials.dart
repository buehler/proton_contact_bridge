import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:proton_contact_bridge/providers/proton_auth.dart';
import 'package:proton_contact_bridge/ui/components/text.dart';

class LoginCredentialsPage extends ConsumerWidget {
  LoginCredentialsPage({super.key});

  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Flex(
    direction: Axis.vertical,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const AppText(
                  'Welcome!',
                  variant: TypographyVariant.diplayLarge,
                ),
                AppText(
                  'Please sign in to continue',
                  variant: TypographyVariant.headlineMedium,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                TextField(
                  controller: _usernameController,
                  autofocus: true,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'Enter your username or email',
                    labelText: 'USERNAME OR EMAIL',
                    labelStyle: TypographyVariant.labelMedium.style,
                  ),
                ),
                TextField(
                  controller: _passwordController,
                  autocorrect: false,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    labelText: 'PASSWORD',
                    labelStyle: TypographyVariant.labelMedium.style,
                    suffixIcon: Icon(
                      Icons.visibility_off_outlined,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  obscureText: true,
                ),
                FilledButton(
                  onPressed: () => ref
                      .read(protonAuthProvider)
                      .login(
                        username: _usernameController.text,
                        password: _passwordController.text,
                      ),
                  child: const AppText('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
