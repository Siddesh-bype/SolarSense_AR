import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../services/user_session.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/custom_textfield.dart';

class LoginRegisterScreen extends StatefulWidget {
  const LoginRegisterScreen({super.key});

  @override
  State<LoginRegisterScreen> createState() => _LoginRegisterScreenState();
}

class _LoginRegisterScreenState extends State<LoginRegisterScreen> {
  bool isLogin = true;
  bool obscurePassword = true;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (!isLogin) {
      if (_nameCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Enter your full name.');
        return;
      }
      if (_passwordCtrl.text != _confirmCtrl.text) {
        setState(() => _error = 'Passwords do not match.');
        return;
      }
    }

    UserSession.instance.updateProfile(
      name: isLogin
          ? (email.split('@').first)
          : _nameCtrl.text.trim(),
      email: email,
    );

    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.wb_sunny_rounded,
                      size: 26,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'SolarSense',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: c.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 44),
              Text(
                isLogin ? 'Welcome back' : 'Create your account',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: c.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isLogin
                    ? 'Sign in to continue your solar journey'
                    : 'Start unlocking your rooftop potential',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: c.onSurfaceMuted,
                ),
              ),
              const SizedBox(height: 28),

              Container(
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildTab(
                        'Login',
                        isLogin,
                        () => setState(() {
                          isLogin = true;
                          _error = null;
                        }),
                        c,
                      ),
                    ),
                    Expanded(
                      child: _buildTab(
                        'Register',
                        !isLogin,
                        () => setState(() {
                          isLogin = false;
                          _error = null;
                        }),
                        c,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              if (!isLogin) ...[
                _buildFieldLabel('Full Name', c),
                CustomTextField(
                  controller: _nameCtrl,
                  hintText: 'Your name',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 20),
              ],

              _buildFieldLabel('Email Address', c),
              CustomTextField(
                controller: _emailCtrl,
                hintText: 'you@example.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              _buildFieldLabel('Password', c),
              CustomTextField(
                controller: _passwordCtrl,
                hintText: '••••••••',
                prefixIcon: Icons.lock_outline,
                obscureText: obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: c.onSurfaceMuted,
                  ),
                  onPressed: () =>
                      setState(() => obscurePassword = !obscurePassword),
                ),
              ),

              if (!isLogin) ...[
                const SizedBox(height: 20),
                _buildFieldLabel('Confirm Password', c),
                CustomTextField(
                  controller: _confirmCtrl,
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: obscurePassword,
                ),
              ],

              if (isLogin) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text(
                      'Forgot Password?',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                const SizedBox(height: 28),
              ],

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: c.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: c.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(color: c.error),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              PrimaryButton(
                text: isLogin ? 'Login' : 'Create Account',
                onPressed: _submit,
              ),

              const SizedBox(height: 28),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'OR',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: c.onSurfaceMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 28),

              SecondaryButton(
                text: 'Continue with Google',
                onPressed: () {},
                icon: const Icon(Icons.g_mobiledata, size: 24),
              ),

              const SizedBox(height: 40),
              Text(
                'By continuing you agree to our Terms & Privacy Policy',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: c.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text, SolarPalette c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: c.onSurface,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  Widget _buildTab(
      String title, bool isActive, VoidCallback onTap, SolarPalette c) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: isActive ? c.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                  color: isActive ? c.onSurface : c.onSurfaceMuted,
                ),
          ),
        ),
      ),
    );
  }
}