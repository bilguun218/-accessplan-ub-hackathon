import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_header.dart';
import '../widgets/password_field.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? token;
  const ResetPasswordScreen({super.key, this.token});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirm = TextEditingController();
  late final TextEditingController _tokenCtrl;

  @override
  void initState() {
    super.initState();
    _tokenCtrl = TextEditingController(text: widget.token ?? '');
  }

  @override
  void dispose() {
    _newPassword.dispose();
    _confirm.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context.read<AuthProvider>().resetPassword(
          _tokenCtrl.text.trim(),
          _newPassword.text,
        );
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(AppStrings.passwordResetSuccess),
          backgroundColor: AppColors.primary,
        ),
      );
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthHeader(
                  title: 'Нууц үг шинэчлэх',
                  subtitle: 'Шинэ нууц үгээ оруулна уу.',
                ),
                AppTextField(
                  label: 'Сэргээх токен',
                  controller: _tokenCtrl,
                  validator: (v) => Validators.required(v),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  label: AppStrings.newPassword,
                  controller: _newPassword,
                  validator: Validators.password,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  label: AppStrings.confirmNewPassword,
                  controller: _confirm,
                  validator:
                      Validators.confirmMatches(() => _newPassword.text),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.errorMessage!,
                      style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: AppStrings.resetPassword,
                  loading: auth.isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
