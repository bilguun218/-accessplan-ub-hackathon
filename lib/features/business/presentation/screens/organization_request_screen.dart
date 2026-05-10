import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../data/models/business_models.dart';
import '../providers/business_provider.dart';
import '../widgets/business_text_scale.dart';

class OrganizationRequestScreen extends StatefulWidget {
  const OrganizationRequestScreen({super.key});

  @override
  State<OrganizationRequestScreen> createState() =>
      _OrganizationRequestScreenState();
}

class _OrganizationRequestScreenState extends State<OrganizationRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _activity = TextEditingController();
  final _registration = TextEditingController();
  final _location = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _description = TextEditingController();
  var _verificationMethod = 'emongolia';
  var _latitude = 47.918873;
  var _longitude = 106.917701;

  @override
  void dispose() {
    _name.dispose();
    _activity.dispose();
    _registration.dispose();
    _location.dispose();
    _contact.dispose();
    _phone.dispose();
    _email.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final now = DateTime.now();
    final profile = BusinessProfile(
      id: 'draft-${now.millisecondsSinceEpoch}',
      organizationName: _name.text.trim(),
      branchName: '',
      activityType: _activity.text.trim(),
      registrationNumber: _registration.text.trim(),
      location: _location.text.trim(),
      contactPerson: _contact.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      description: _description.text.trim(),
      verificationMethod: _verificationMethod,
      status: 'active',
      website: '',
      latitude: _latitude,
      longitude: _longitude,
      hasParking: true,
      hasCoveredParking: false,
      parkingSpaces: 8,
      wheelchairAccessible: true,
      hasElevator: true,
      accessibleRestroom: true,
      onlineService: true,
      appointmentBooking: false,
      hours: BusinessHour.defaultWeek(),
      createdAt: now,
      updatedAt: now,
    );

    final provider = context.read<BusinessProvider>();
    final ok = await provider.createOrganization(profile);
    if (!mounted || !ok) return;

    final message = provider.lastSyncMessage;
    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
    context.go('/business');
  }

  void _useTestUbLocation() {
    setState(() {
      _name.text = 'Test Coffee Zaisan';
      _activity.text = 'coffee_shop';
      _registration.text = 'TEST-UB-001';
      _location.text = 'Зайсан, Хан-Уул дүүрэг';
      _contact.text = 'Test Admin';
      _phone.text = '99112233';
      _email.text = 'testcoffee@example.mn';
      _description.text =
          'MapScreen дээр real promotion gift marker шалгах тест байгууллага.';
      _latitude = 47.8912;
      _longitude = 106.9214;
    });
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>();

    return BusinessTextScale(
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F9FD),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(
                title: 'Байгууллага бүртгүүлэх',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 26),
                    children: [
                      const _InfoBanner(),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: business.isSubmitting
                              ? null
                              : _useTestUbLocation,
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Use Test UB Location'),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _Section(
                        title: 'БАЙГУУЛЛАГЫН МЭДЭЭЛЭЛ',
                        children: [
                          _Field(
                            label: 'Байгууллагын нэр',
                            hint: 'Жишээ: Blue Bean Coffee',
                            controller: _name,
                            validator: (value) => Validators.required(
                              value,
                              message: 'Байгууллагын нэр шаардлагатай.',
                            ),
                          ),
                          _Field(
                            label: 'Үйл ажиллагааны чиглэл',
                            hint: 'Жишээ: Кофе шоп, эмийн сан',
                            controller: _activity,
                            validator: (value) => Validators.required(
                              value,
                              message: 'Үйл ажиллагааны чиглэл шаардлагатай.',
                            ),
                          ),
                          _Field(
                            label: 'Улсын бүртгэлийн дугаар',
                            hint: 'Улсын бүртгэлийн дугаар',
                            controller: _registration,
                            validator: (value) => Validators.required(
                              value,
                              message: 'Бүртгэлийн дугаар шаардлагатай.',
                            ),
                          ),
                          _Field(
                            label: 'Байршил',
                            hint: 'Дүүрэг, хороо, гудамж',
                            controller: _location,
                            validator: (value) => Validators.required(
                              value,
                              message: 'Байршил шаардлагатай.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _Section(
                        title: 'ХОЛБОО БАРИХ',
                        children: [
                          _Field(
                            label: 'Холбоо барих хүн',
                            hint: 'Нэр, овог',
                            controller: _contact,
                            validator: (value) => Validators.required(
                              value,
                              message: 'Холбоо барих хүн шаардлагатай.',
                            ),
                          ),
                          _ResponsiveFieldPair(
                            left: _Field(
                              label: 'Утас',
                              hint: '99000000',
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              validator: _phoneRequired,
                            ),
                            right: _Field(
                              label: 'Имэйл',
                              hint: 'name@business.mn',
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              validator: Validators.email,
                            ),
                          ),
                          _Field(
                            label: 'Тайлбар',
                            hint: 'Байгууллагын тухай товч мэдээлэл...',
                            controller: _description,
                            height: 92,
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _VerificationSection(
                        value: _verificationMethod,
                        onChanged: (value) =>
                            setState(() => _verificationMethod = value),
                      ),
                      const SizedBox(height: 20),
                      const _SecureNote(),
                    ],
                  ),
                ),
              ),
              _BottomActions(
                primary: business.isSubmitting
                    ? 'Илгээж байна...'
                    : 'Байгууллага үүсгэх',
                onCancel: business.isSubmitting ? null : () => context.pop(),
                onPrimary: business.isSubmitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _phoneRequired(String? value) {
    final required = Validators.required(
      value,
      message: 'Утасны дугаар шаардлагатай.',
    );
    if (required != null) return required;
    return Validators.phoneOptional(value);
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCFE4FF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.business_rounded, color: AppColors.primary, size: 26),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Мэдээллээ оруулмагц байгууллагын dashboard үүсэж, урамшуулал, статистик, профайл засвар шууд ажиллана.',
              style: TextStyle(
                color: Color(0xFF1D4ED8),
                fontSize: 17,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationSection extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _VerificationSection({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'БАТАЛГААЖУУЛАЛТ',
      children: [
        _VerifyChoice(
          selected: value == 'emongolia',
          icon: Icons.shield_outlined,
          title: 'e-Mongolia-аар баталгаажуулах',
          subtitle: 'Хурдан, найдвартай',
          onTap: () => onChanged('emongolia'),
        ),
        const SizedBox(height: 14),
        _VerifyChoice(
          selected: value == 'document',
          icon: Icons.description_outlined,
          title: 'Албан бичиг хавсаргах',
          subtitle: 'Бичиг баримтаар шалгуулах',
          onTap: () => onChanged('document'),
        ),
      ],
    );
  }
}

class _VerifyChoice extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _VerifyChoice({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : const Color(0xFFCBD5E1);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF3FF) : const Color(0xFFFAFBFD),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF77B7FF)
                  : const Color(0xFFE5E7EB),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFFDCEBFF) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? AppColors.primary : const Color(0xFF9AA3B2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF334155),
                        fontSize: 17,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF9AA3B2),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                  color: selected ? AppColors.primary : Colors.transparent,
                ),
                child: selected
                    ? const Center(
                        child: CircleAvatar(
                          radius: 4,
                          backgroundColor: Colors.white,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecureNote extends StatelessWidget {
  const _SecureNote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.shield_outlined, color: Color(0xFF94A3B8), size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Байгууллагын мэдээлэл энэ төхөөрөмж дээр хадгалагдаж, боломжтой үед сервер рүү хүсэлтээр илгээгдэнэ.',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 14.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Row(
        children: [
          _BackButton(onTap: onBack),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              softWrap: true,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 21,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEFF3F8)),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final double height;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.label,
    required this.hint,
    required this.controller,
    this.height = 58,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            maxLines: maxLines,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: const Color(0xFFFBFCFE),
              constraints: BoxConstraints(minHeight: height),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFFE0E6EE),
                  width: 1.35,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveFieldPair extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _ResponsiveFieldPair({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(children: [left, right]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.arrow_back_rounded, color: Color(0xFF334155)),
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final String primary;
  final VoidCallback? onCancel;
  final VoidCallback? onPrimary;

  const _BottomActions({
    required this.primary,
    required this.onCancel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.black.withValues(alpha: 0.04)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cancel = _ActionButtonFrame(
              onPressed: onCancel,
              child: const Text('Болих', textAlign: TextAlign.center),
            );
            final submit = _ActionButtonFrame(
              onPressed: onPrimary,
              primary: true,
              child: Text(primary, textAlign: TextAlign.center),
            );

            if (constraints.maxWidth < 340) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(width: double.infinity, child: submit),
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: cancel),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: cancel),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: submit),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionButtonFrame extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool primary;

  const _ActionButtonFrame({
    required this.onPressed,
    required this.child,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = const TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w900,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: primary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                shape: shape,
                textStyle: textStyle,
              ),
              child: DefaultTextStyle.merge(
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                child: child,
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                shape: shape,
                textStyle: textStyle,
              ),
              child: DefaultTextStyle.merge(
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                child: child,
              ),
            ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE7ECF3)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.045),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );
}
