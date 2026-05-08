import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../data/models/auth_response_model.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_header.dart';
import '../widgets/password_field.dart';
import '../widgets/user_type_selector.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _userType;
  String? _district;
  String _language = 'mn';
  String? _userTypeError;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    setState(() {
      _userTypeError =
          _userType == null ? AppStrings.errUserTypeRequired : null;
    });
    if (!formOk || _userType == null) return;

    final ok = await context.read<AuthProvider>().register(
          RegisterRequest(
            fullName: _fullName.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            password: _password.text,
            userType: _userType!,
            district: _district,
            preferredLanguage: _language,
          ),
        );
    if (!mounted) return;
    if (ok) context.go('/home');
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
                  title: 'Бүртгэл үүсгэх',
                  subtitle: 'Хэрэгцээтэй мэдээллээ оруулна уу.',
                ),
                AppTextField(
                  label: AppStrings.fullName,
                  controller: _fullName,
                  textInputAction: TextInputAction.next,
                  validator: (v) => Validators.required(v,
                      message: AppStrings.errFullNameRequired),
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: AppStrings.email,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: Validators.email,
                ),
                const SizedBox(height: 14),
                AppTextField(
                  label: AppStrings.phone,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  validator: Validators.phoneOptional,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  label: AppStrings.password,
                  controller: _password,
                  validator: Validators.password,
                ),
                const SizedBox(height: 14),
                PasswordField(
                  label: AppStrings.confirmPassword,
                  controller: _confirm,
                  validator:
                      Validators.confirmMatches(() => _password.text),
                ),
                const SizedBox(height: 14),
                UserTypeSelector(
                  value: _userType,
                  errorText: _userTypeError,
                  onChanged: (v) => setState(() {
                    _userType = v;
                    _userTypeError = null;
                  }),
                ),
                const SizedBox(height: 14),
                _DistrictDropdown(
                  value: _district,
                  onChanged: (v) => setState(() => _district = v),
                ),
                const SizedBox(height: 14),
                _LanguageDropdown(
                  value: _language,
                  onChanged: (v) => setState(() => _language = v ?? 'mn'),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(auth.errorMessage!,
                      style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 20),
                AppButton(
                  label: AppStrings.register,
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

class _DistrictDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;
  const _DistrictDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(AppStrings.district,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              hint: const Text('Сонгох',
                  style: TextStyle(color: AppColors.textMuted)),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textMuted),
              items: AppStrings.districts
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String?> onChanged;
  const _LanguageDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(AppStrings.language,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textMuted),
              items: const [
                DropdownMenuItem(value: 'mn', child: Text('Монгол')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
