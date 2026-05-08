import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_header.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await context
        .read<AuthProvider>()
        .forgotPassword(_email.text.trim());
    if (!mounted) return;
    if (ok) setState(() => _sent = true);
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
                  title: 'Нууц үг сэргээх',
                  subtitle: 'Бүртгэлтэй имэйл хаягаа оруулна уу.',
                ),
                if (_sent)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightGreenBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle,
                            color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppStrings.forgotPasswordSent,
                            style: TextStyle(color: AppColors.textDark),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  AppTextField(
                    label: AppStrings.email,
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(auth.errorMessage!,
                        style: const TextStyle(color: AppColors.error)),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    label: AppStrings.sendResetLink,
                    loading: auth.isLoading,
                    onPressed: _submit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
