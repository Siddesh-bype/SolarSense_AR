import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Abstract Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.wb_sunny_rounded, size: 32, color: AppColors.primaryContainer),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'SolarSense AR',
                    style: GoogleFonts.manrope(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 56),

              // Custom Pill Tabs
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(child: _buildTab('Login', isLogin, () => setState(() { isLogin = true; _error = null; }))),
                    Expanded(child: _buildTab('Register', !isLogin, () => setState(() { isLogin = false; _error = null; }))),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Forms
              if (!isLogin) ...[
                _buildFieldLabel('Full Name'),
                CustomTextField(
                  controller: _nameCtrl,
                  hintText: 'Your name',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 20),
              ],

              _buildFieldLabel('Email Address'),
              CustomTextField(
                controller: _emailCtrl,
                hintText: 'you@example.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),

              _buildFieldLabel('Password'),
              CustomTextField(
                controller: _passwordCtrl,
                hintText: '••••••••',
                prefixIcon: Icons.lock_outline,
                obscureText: obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.secondary,
                  ),
                  onPressed: () => setState(() => obscurePassword = !obscurePassword),
                ),
              ),

              if (!isLogin) ...[
                const SizedBox(height: 20),
                _buildFieldLabel('Confirm Password'),
                CustomTextField(
                  controller: _confirmCtrl,
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: obscurePassword,
                ),
              ],

              if (isLogin) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: Text('Forgot Password?', style: GoogleFonts.inter(color: AppColors.primaryContainer, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 8),
              ] else ...[
                const SizedBox(height: 32),
              ],

              if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
              ],

              PrimaryButton(
                text: isLogin ? 'Login' : 'Create Account',
                onPressed: _submit,
              ),

              const SizedBox(height: 32),
              Row(
                children: [
                  const Expanded(child: Divider(color: AppColors.outlineVariant)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: GoogleFonts.inter(color: AppColors.secondary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const Expanded(child: Divider(color: AppColors.outlineVariant)),
                ],
              ),
              const SizedBox(height: 32),

              SecondaryButton(
                text: 'Continue with Google',
                onPressed: () {},
              ),

              const SizedBox(height: 48),
              Text(
                'By continuing you agree to our Terms & Privacy Policy',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.secondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface),
      ),
    );
  }

  Widget _buildTab(String title, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : [],
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
              color: isActive ? AppColors.onSurface : AppColors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}
