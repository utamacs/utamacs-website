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
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) return;
    setState(() => _loading = true);
    try {
      // Normalise to E.164: assume India +91 if no country code
      final normalised = phone.startsWith('+') ? phone : '+91$phone';
      await ref.read(authNotifierProvider.notifier).sendOtp(normalised);
      setState(() => _otpSent = true);
    } catch (e) {
      _showError('Could not send OTP. Check your phone number.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneCtrl.text.trim();
    final token = _otpCtrl.text.trim();
    if (token.length != 6) return;
    setState(() => _loading = true);
    try {
      final normalised = phone.startsWith('+') ? phone : '+91$phone';
      await ref.read(authNotifierProvider.notifier).verifyOtp(normalised, token);
      if (mounted) context.go('/');
    } catch (e) {
      _showError('Invalid or expired OTP. Please try again.');
    } finally {
      setState(() => _loading = false);
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
              // Logo / branding
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
              Text(
                'Resident Portal',
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: kTextSecondary),
              ),
              const SizedBox(height: 48),
              if (!_otpSent) ...[
                Text('Enter your mobile number',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    prefixText: '+91  ',
                    hintText: '98765 43210',
                    labelText: 'Mobile number',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _sendOtp,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Send OTP'),
                ),
              ] else ...[
                Text('Enter the 6-digit OTP',
                    style: Theme.of(context).textTheme.titleLarge),
                Text('Sent to +91 ${_phoneCtrl.text}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: kTextSecondary)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    hintText: '• • • • • •',
                    labelText: 'OTP',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _verifyOtp,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Verify & Sign In'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _otpSent = false;
                            _otpCtrl.clear();
                          }),
                  child: const Text('Change number'),
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
