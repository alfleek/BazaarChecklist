import 'package:flutter/material.dart';
import 'package:mobile/features/auth/auth_service.dart';
import 'package:mobile/features/auth/session_controller.dart';
import 'package:mobile/features/shared/ui/section_card.dart';

enum _AuthMode { signIn, createAccount }

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _accountTabIndex = 2;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isBusy = false;
  bool _obscurePassword = true;
  _AuthMode _authMode = _AuthMode.signIn;
  String? _formError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).maybePop()),
        title: const Text('Sign in'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'BazaarChecklist',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track your winning boards and item progress.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFE3D2B7),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const SectionCard(
                    title: 'Sign In',
                    subtitle: 'Use your account to sync across devices.',
                    child: Text(
                      'Sign in for cloud sync, or continue as guest for local tracking.',
                    ),
                  ),
                  _LoginForm(
                    formKey: _formKey,
                    emailController: _emailController,
                    passwordController: _passwordController,
                    obscurePassword: _obscurePassword,
                    mode: _authMode,
                    onTogglePasswordVisibility: _togglePasswordVisibility,
                    onPasswordSubmitted: _signInWithEmail,
                    onForgotPassword: _isBusy ? null : _sendPasswordReset,
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<_AuthMode>(
                    segments: const [
                      ButtonSegment(
                        value: _AuthMode.signIn,
                        label: Text('Sign in'),
                      ),
                      ButtonSegment(
                        value: _AuthMode.createAccount,
                        label: Text('Create account'),
                      ),
                    ],
                    selected: {_authMode},
                    onSelectionChanged: _isBusy
                        ? null
                        : (selection) {
                            setState(() {
                              _authMode = selection.first;
                              _formError = null;
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  if (_formError != null)
                    Card(
                      color: const Color(0xFF381A16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFF8E3A2D)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 18),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_formError!)),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _isBusy
                        ? null
                        : _authMode == _AuthMode.signIn
                        ? _signInWithEmail
                        : _createAccount,
                    child: _isBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _authMode == _AuthMode.signIn
                                ? 'Sign in'
                                : 'Create account',
                          ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _isBusy ? null : _signInWithGoogle,
                    icon: const Icon(Icons.g_mobiledata),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.apple),
                    label: const Text('Apple sign-in (coming soon)'),
                  ),
                  const SizedBox(height: 18),
                  Card(
                    color: const Color(0xFF26150F),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFF845020)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xFFF2AA37),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Guest mode keeps your data on this device. Sign in anytime to sync across devices.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: const Color(0xFFFFE6BE)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _isBusy ? null : _continueAsGuest,
                    icon: const Icon(Icons.person_outline),
                    label: const Text('Continue as guest'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signInWithEmail() async {
    if (!_validateForm()) return;
    await _runAuthAction(() async {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      sessionController.clearGuest();
      await authService.signInWithEmail(email: email, password: password);
    });
  }

  Future<void> _createAccount() async {
    if (!_validateForm()) return;
    await _runAuthAction(() async {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      sessionController.clearGuest();
      await authService.createAccountWithEmail(
        email: email,
        password: password,
      );
    });
  }

  Future<void> _signInWithGoogle() async {
    await _runAuthAction(() async {
      sessionController.clearGuest();
      final result = await authService.signInWithGoogle();
      if (result != null && mounted) {
        sessionController.setPreferredTabIndex(_accountTabIndex);
        Navigator.of(context).maybePop();
      }
    }, closeOnSuccess: false);
  }

  Future<void> _continueAsGuest() async {
    sessionController.setPreferredTabIndex(_accountTabIndex);
    sessionController.continueAsGuest();
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  Future<void> _sendPasswordReset() async {
    final emailError = _LoginForm.validateEmail(_emailController.text);
    if (emailError != null) {
      setState(() => _formError = emailError);
      return;
    }
    await _runAuthAction(() async {
      final email = _emailController.text.trim();
      await authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    }, closeOnSuccess: false);
  }

  bool _validateForm() {
    final form = _formKey.currentState;
    if (form == null) return false;
    return form.validate();
  }

  Future<void> _runAuthAction(
    Future<void> Function() action, {
    bool closeOnSuccess = true,
  }) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _formError = null;
    });
    try {
      await action();
      if (mounted && closeOnSuccess) {
        sessionController.setPreferredTabIndex(_accountTabIndex);
        Navigator.of(context).maybePop();
      }
    } catch (error) {
      if (!mounted) return;
      final message = switch (error) {
        _ => authService.friendlyError(error),
      };
      setState(() => _formError = message);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.mode,
    required this.onTogglePasswordVisibility,
    required this.onPasswordSubmitted,
    required this.onForgotPassword,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final _AuthMode mode;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onPasswordSubmitted;
  final VoidCallback? onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            validator: _validateEmail,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'you@example.com',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => onPasswordSubmitted(),
            validator: _validatePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter password',
              suffixIcon: IconButton(
                tooltip: obscurePassword ? 'Show password' : 'Hide password',
                onPressed: onTogglePasswordVisibility,
                icon: Icon(
                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          if (mode == _AuthMode.signIn) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Email is required.';
    final basicEmailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!basicEmailPattern.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validateEmail(String? value) => validateEmail(value);

  String? _validatePassword(String? value) {
    if ((value ?? '').isEmpty) return 'Password is required.';
    return null;
  }
}
