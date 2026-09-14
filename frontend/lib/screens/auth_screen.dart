import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.appState});
  final AppState appState;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!formKey.currentState!.validate()) return;
    final appState = widget.appState;
    final ok = isLogin
        ? await appState.login(
            email: emailController.text.trim(),
            password: passwordController.text,
          )
        : await appState.signup(
            name: nameController.text.trim(),
            email: emailController.text.trim(),
            password: passwordController.text,
          );
    if (!mounted) return;
    if (!ok && appState.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(appState.errorMessage!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: purple.withOpacity(.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.account_balance_wallet_outlined,
                          color: purple, size: 34),
                    ),
                    const SizedBox(height: 18),
                    const Text('CashWise',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900, color: dark)),
                    const SizedBox(height: 6),
                    Text(
                      isLogin ? 'Log in to your business' : 'Create your account',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 28),
                    if (!isLogin) ...[
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Business owner name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.length < 4)
                          ? 'At least 4 characters'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: purple,
                        padding: const EdgeInsets.all(16),
                      ),
                      onPressed: widget.appState.isBusy ? null : _submit,
                      child: widget.appState.isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(isLogin ? 'Log In' : 'Sign Up'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => isLogin = !isLogin),
                      child: Text(isLogin
                          ? "Don't have an account? Sign up"
                          : 'Already have an account? Log in'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
