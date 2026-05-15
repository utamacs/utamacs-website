import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  bool _otpSent  = false;
  bool _loading  = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Enter a valid email address.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authNotifierProvider.notifier).sendEmailOtp(email);
      if (mounted) setState(() => _otpSent = true);
    } catch (e) {
      _showError('Could not send OTP. Make sure your email is registered on the portal.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final email = _emailCtrl.text.trim();
    final token = _otpCtrl.text.trim();
    if (token.length != 6) {
      _showError('Enter the 6-digit code from your email.');
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(authNotifierProvider.notifier).verifyEmailOtp(email, token);
      if (mounted) context.go('/');
    } catch (e) {
      _showError('Invalid or expired code. Check your email and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: kRed600),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              // Branding
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: kPrimary600,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.apartment, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 24),
              Text('UTA MACS',
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 6),
              Text('Resident Portal',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: kTextSecondary)),
              const SizedBox(height: 48),
              if (!_otpSent) ...[
                Text('Sign in with your email',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('Use the same email address registered on the portal.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: kTextSecondary)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Send sign-in code'),
                ),
              ] else ...[
                Text('Enter the 6-digit code',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text('Sent to ${_emailCtrl.text}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: kTextSecondary)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'Sign-in code',
                    prefixIcon: Icon(Icons.lock_outline),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Sign in'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _otpSent = false;
                            _otpCtrl.clear();
                          }),
                  child: const Text('Use a different email'),
                ),
              ],
              const Spacer(flex: 2),
              Text(
                'Kondakal, Shankarpalle • Ranga Reddy District',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: kTextSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
