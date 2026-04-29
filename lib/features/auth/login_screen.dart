import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/app_routes.dart';
import '../../core/auth_api.dart';
import '../../widgets/app_button.dart';

enum _AuthMode { login, register, verifyEmail, forgot, resetPassword }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _api = AuthApi();
  final _imagePicker = ImagePicker();
  late final _googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  var _mode = _AuthMode.login;
  var _loading = false;
  String? _error;
  String? _pendingEmail;
  String? _avatarPath;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLogin = _mode == _AuthMode.login;
    final isRegister = _mode == _AuthMode.register;
    final isVerify = _mode == _AuthMode.verifyEmail;
    final isForgot = _mode == _AuthMode.forgot;
    final isReset = _mode == _AuthMode.resetPassword;
    final title = switch (_mode) {
      _AuthMode.login => 'Kirish',
      _AuthMode.register => "Ro'yxatdan o'tish",
      _AuthMode.verifyEmail => 'Emailni tasdiqlash',
      _AuthMode.forgot => 'Parolni tiklash',
      _AuthMode.resetPassword => "Yangi parol o'rnatish",
    };

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isLogin && !isRegister)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _loading ? null : _showLogin,
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                    ),
                  Text(
                    isLogin || isRegister ? 'Login / Register' : title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (isRegister) ...[
                    _AvatarPicker(
                      imagePath: _avatarPath,
                      onCamera: () => _pickAvatar(ImageSource.camera),
                      onGallery: () => _pickAvatar(ImageSource.gallery),
                    ),
                    const SizedBox(height: 12),
                    _AuthField(
                      controller: _fullNameController,
                      label: 'Ism familiya',
                      hint: 'Ism familiya',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (!isVerify) ...[
                    _AuthField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isVerify || isReset) ...[
                    _AuthField(
                      controller: _codeController,
                      label: 'Kod',
                      hint: '6 xonali kod',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (isLogin || isRegister) ...[
                    _AuthField(
                      controller: _passwordController,
                      label: 'Parol',
                      hint: 'Parol',
                      obscure: true,
                      textInputAction: isRegister
                          ? TextInputAction.next
                          : TextInputAction.done,
                    ),
                    if (isRegister) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Parol minimum 8 belgi bo‘lishi kerak',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      const SizedBox(height: 12),
                      _AuthField(
                        controller: _confirmPasswordController,
                        label: 'Parolni tasdiqlash',
                        hint: 'Parolni tasdiqlash',
                        obscure: true,
                        textInputAction: TextInputAction.done,
                      ),
                    ],
                  ],
                  if (isReset) ...[
                    _AuthField(
                      controller: _newPasswordController,
                      label: 'Yangi parol',
                      hint: 'Yangi parol',
                      obscure: true,
                      textInputAction: TextInputAction.done,
                    ),
                  ],
                  if (isLogin) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _signInWithGoogle,
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      label: const Text('Google orqali kirish'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onSurface,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => _switchMode(_AuthMode.forgot),
                        child: const Text(
                          'Parolni unutdingizmi?',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  AppButton(
                    label: _loading
                        ? 'Kuting...'
                        : isForgot
                        ? 'Kod yuborish'
                        : isVerify
                        ? 'Tasdiqlash'
                        : isReset
                        ? 'Parolni yangilash'
                        : isRegister
                        ? "Ro'yxatdan o'tish"
                        : 'Kirish',
                    onPressed: _loading ? null : _submit,
                  ),
                  if (isVerify) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Kod 10 daqiqa ichida amal qiladi',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    TextButton(
                      onPressed: _loading ? null : _resendCode,
                      child: const Text('Kodni qayta yuborish'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorToast(message: _error!),
                  ],
                  if (isLogin || isRegister) ...[
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: _loading
                            ? null
                            : () => _switchMode(
                                isRegister
                                    ? _AuthMode.login
                                    : _AuthMode.register,
                              ),
                        child: Text(
                          isRegister
                              ? 'Hisobingiz bormi? Kirish'
                              : "Hisobingiz yo'qmi? Ro'yxatdan o'tish",
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  if (!isLogin && !isRegister && !isVerify) ...[
                    const SizedBox(height: 12),
                    Text(
                      isForgot
                          ? 'Emailingizga reset kod yuboramiz'
                          : 'Emaildagi kod bilan yangi parol kiriting',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    try {
      switch (_mode) {
        case _AuthMode.login:
          _require(_emailController.text, 'Email kiriting');
          _require(_passwordController.text, 'Password kiriting');
          await _run(
            () => _api.login(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            ),
          );
          _openHome();
        case _AuthMode.register:
          _require(_fullNameController.text, 'Full name kiriting');
          _require(_avatarPath ?? '', 'Profil rasmini yuklang');
          _require(_emailController.text, 'Email kiriting');
          _require(_passwordController.text, 'Password kiriting');
          _requirePassword(_passwordController.text);
          if (_passwordController.text != _confirmPasswordController.text) {
            throw const AuthApiException('Parollar mos emas');
          }
          final result = await _run(
            () => _api.register(
              fullName: _fullNameController.text.trim(),
              email: _emailController.text.trim(),
              password: _passwordController.text,
              avatarUrl: _avatarPath!,
            ),
          );
          _pendingEmail = _emailController.text.trim();
          _codeController.text = result.verificationCode ?? '';
          _switchMode(_AuthMode.verifyEmail);
          _showSnack(result.message);
        case _AuthMode.verifyEmail:
          final email = _pendingEmail ?? _emailController.text.trim();
          _require(email, 'Email topilmadi');
          _require(_codeController.text, 'Kodni kiriting');
          await _run(
            () => _api.verifyEmail(
              email: email,
              code: _codeController.text.trim(),
            ),
          );
          _openHome();
        case _AuthMode.forgot:
          _require(_emailController.text, 'Email kiriting');
          final result = await _run(
            () => _api.forgotPassword(email: _emailController.text.trim()),
          );
          _pendingEmail = _emailController.text.trim();
          _codeController.text = result.code ?? '';
          _switchMode(_AuthMode.resetPassword);
          _showSnack(result.message);
        case _AuthMode.resetPassword:
          final email = _pendingEmail ?? _emailController.text.trim();
          _require(email, 'Email topilmadi');
          _require(_codeController.text, 'Kodni kiriting');
          _require(_newPasswordController.text, 'Yangi parol kiriting');
          _requirePassword(_newPasswordController.text);
          final message = await _run(
            () => _api.resetPassword(
              email: email,
              code: _codeController.text.trim(),
              newPassword: _newPasswordController.text,
            ),
          );
          _showLogin();
          _showSnack(message);
      }
    } on AuthApiException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _resendCode() async {
    final email = _pendingEmail ?? _emailController.text.trim();
    try {
      _require(email, 'Email topilmadi');
      final result = await _run(() => _api.resendCode(email: email));
      _codeController.text = result.code ?? '';
      _showSnack(result.message);
    } on AuthApiException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _error = null);
      debugPrint(
        'Google sign-in uses default_web_client_id from google-services.json.',
      );
      final account = await _googleSignIn.signIn();
      if (account == null) {
        debugPrint('Google sign-in cancelled by user.');
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        debugPrint(
          'Google sign-in failed: idToken is empty. '
          'Check default_web_client_id generated from google-services.json.',
        );
        throw const AuthApiException(
          'Google id_token olinmadi. Android OAuth client va webClientId sozlamalarini tekshiring.',
        );
      }
      debugPrint('Google sign-in succeeded for ${account.email}.');
      await _run(() => _api.googleLogin(idToken: idToken));
      _openHome();
    } on AuthApiException catch (error) {
      debugPrint('Google auth API error: ${error.message}');
      setState(() => _error = error.message);
    } on PlatformException catch (error) {
      debugPrint(
        'Google PlatformException: code=${error.code}, '
        'message=${error.message}, details=${error.details}',
      );
      setState(() => _error = _googleErrorMessage(error));
    } catch (error) {
      debugPrint('Google sign-in unexpected error: $error');
      setState(() => _error = 'Google orqali kirishda xatolik: $error');
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 78,
      maxWidth: 1200,
    );
    if (picked == null) return;
    setState(() {
      _avatarPath = picked.path;
      _error = null;
    });
  }

  Future<T> _run<T>(Future<T> Function() action) async {
    setState(() => _loading = true);
    try {
      return await action();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
    });
  }

  void _showLogin() {
    _switchMode(_AuthMode.login);
    _codeController.clear();
    _newPasswordController.clear();
  }

  void _openHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  void _showSnack(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static void _require(String value, String message) {
    if (value.trim().isEmpty) throw AuthApiException(message);
  }

  static void _requirePassword(String value) {
    if (value.length < 8) {
      throw const AuthApiException('Password minimum 8 belgi bo‘lishi kerak');
    }
  }

  static String _googleErrorMessage(PlatformException error) {
    final text = '${error.message ?? ''} ${error.details ?? ''}';
    if (text.contains('ApiException: 10')) {
      return 'Google sozlamasi mos emas. serverClientId uchun Android client ID emas, Web application client ID kerak. Google Cloud/Firebase ichida package name com.example.medtime, SHA-1 va Web client ID ni tekshiring.';
    }
    return 'Google orqali kirishda xatolik: ${error.message ?? error.code}';
  }
}

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.imagePath,
    required this.onCamera,
    required this.onGallery,
  });

  final String? imagePath;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.successSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white,
            backgroundImage: path == null || path.isEmpty
                ? null
                : FileImage(File(path)),
            child: path == null || path.isEmpty
                ? const Icon(
                    Icons.person_add_alt_1_outlined,
                    color: AppColors.primary,
                    size: 30,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profil rasmi',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  'Ro‘yxatdan o‘tish uchun majburiy',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.photo_camera_outlined, size: 16),
                      label: const Text('Kamera'),
                      onPressed: onCamera,
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.photo_library_outlined,
                        size: 16,
                      ),
                      label: const Text('Galereya'),
                      onPressed: onGallery,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthField extends StatefulWidget {
  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  State<_AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<_AuthField> {
  late var _obscured = widget.obscure;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      TextField(
        controller: widget.controller,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        decoration: InputDecoration(
          suffixIcon: widget.obscure
              ? IconButton(
                  onPressed: () => setState(() => _obscured = !_obscured),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                )
              : null,
          hintText: widget.hint,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
      ),
    ],
  );
}

class _ErrorToast extends StatelessWidget {
  const _ErrorToast({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.text,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.error, color: AppColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
