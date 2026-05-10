import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../data/models/business_models.dart';
import '../providers/business_provider.dart';
import '../widgets/business_text_scale.dart';

class OrganizationInfoScreen extends StatefulWidget {
  const OrganizationInfoScreen({super.key});

  @override
  State<OrganizationInfoScreen> createState() => _OrganizationInfoScreenState();
}

class _OrganizationInfoScreenState extends State<OrganizationInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _activity = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _website = TextEditingController();
  final _parkingSpaces = TextEditingController();

  late List<BusinessHour> _hours;
  var _initialized = false;
  var _hasParking = true;
  var _hasCoveredParking = false;
  var _wheelchairAccessible = true;
  var _hasElevator = true;
  var _accessibleRestroom = true;
  var _onlineService = true;
  var _appointmentBooking = false;
  var _latitude = 47.918873;
  var _longitude = 106.917701;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final profile = context.read<BusinessProvider>().profile;
    _name.text = profile.organizationName;
    _activity.text = profile.activityType;
    _description.text = profile.description;
    _location.text = profile.location;
    _phone.text = profile.phone;
    _email.text = profile.email;
    _website.text = profile.website;
    _parkingSpaces.text = profile.parkingSpaces.toString();
    _hasParking = profile.hasParking;
    _hasCoveredParking = profile.hasCoveredParking;
    _wheelchairAccessible = profile.wheelchairAccessible;
    _hasElevator = profile.hasElevator;
    _accessibleRestroom = profile.accessibleRestroom;
    _onlineService = profile.onlineService;
    _appointmentBooking = profile.appointmentBooking;
    _latitude = profile.latitude;
    _longitude = profile.longitude;
    _hours = [...profile.hours];
    _initialized = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _activity.dispose();
    _description.dispose();
    _location.dispose();
    _phone.dispose();
    _email.dispose();
    _website.dispose();
    _parkingSpaces.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final current = context.read<BusinessProvider>().profile;
    final updated = current.copyWith(
      organizationName: _name.text.trim(),
      activityType: _activity.text.trim(),
      description: _description.text.trim(),
      location: _location.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      website: _website.text.trim(),
      latitude: _latitude,
      longitude: _longitude,
      hasParking: _hasParking,
      hasCoveredParking: _hasCoveredParking,
      parkingSpaces: int.tryParse(_parkingSpaces.text.trim()) ?? 0,
      wheelchairAccessible: _wheelchairAccessible,
      hasElevator: _hasElevator,
      accessibleRestroom: _accessibleRestroom,
      onlineService: _onlineService,
      appointmentBooking: _appointmentBooking,
      hours: _hours,
    );
    await context.read<BusinessProvider>().updateProfile(updated);
    if (mounted) context.pop();
  }

  void _shiftPin() {
    setState(() {
      _latitude = double.parse((_latitude + 0.0008).toStringAsFixed(6));
      _longitude = double.parse((_longitude + 0.0008).toStringAsFixed(6));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BusinessTextScale(
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F9FD),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(
                title: 'Байгууллагын мэдээлэл',
                onBack: () => context.pop(),
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 26),
                    children: [
                      const _InfoBanner(),
                      const SizedBox(height: 18),
                      _EditSection(
                        title: 'ҮНДСЭН МЭДЭЭЛЭЛ',
                        children: [
                          _EditField(
                            label: 'Байгууллагын нэр',
                            controller: _name,
                            validator: (value) => Validators.required(
                              value,
                              message: 'Байгууллагын нэр шаардлагатай.',
                            ),
                          ),
                          _EditField(
                            label: 'Үйлчилгээний төрөл',
                            controller: _activity,
                            validator: (value) => Validators.required(
                              value,
                              message: 'Үйлчилгээний төрөл шаардлагатай.',
                            ),
                          ),
                          _EditField(
                            label: 'Товч тайлбар',
                            controller: _description,
                            height: 82,
                            maxLines: 3,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _MapSection(
                        locationController: _location,
                        latitude: _latitude,
                        longitude: _longitude,
                        onMovePin: _shiftPin,
                      ),
                      const SizedBox(height: 18),
                      _EditSection(
                        title: 'ХОЛБОО БАРИХ',
                        children: [
                          _EditField(
                            label: 'Утас',
                            controller: _phone,
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: _phoneRequired,
                          ),
                          _EditField(
                            label: 'Имэйл',
                            controller: _email,
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: Validators.email,
                          ),
                          _EditField(
                            label: 'Вэбсайт',
                            controller: _website,
                            icon: Icons.language_rounded,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _HoursSection(
                        hours: _hours,
                        onChanged: (index, value) {
                          setState(() => _hours[index] = value);
                        },
                      ),
                      const SizedBox(height: 18),
                      _EditSection(
                        title: 'ЗОГСООЛ',
                        children: [
                          _SwitchRow(
                            label: 'Зогсоолтой',
                            enabled: _hasParking,
                            onChanged: (value) =>
                                setState(() => _hasParking = value),
                          ),
                          _SwitchRow(
                            label: 'Далд зогсоолтой',
                            enabled: _hasCoveredParking,
                            onChanged: (value) =>
                                setState(() => _hasCoveredParking = value),
                          ),
                          const SizedBox(height: 10),
                          _NumberField(controller: _parkingSpaces),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _EditSection(
                        title: 'ХҮРТЭЭМЖ',
                        children: [
                          _SwitchRow(
                            label: 'Тэргэнцэртэй хүнд тохиромжтой',
                            enabled: _wheelchairAccessible,
                            onChanged: (value) =>
                                setState(() => _wheelchairAccessible = value),
                          ),
                          _SwitchRow(
                            label: 'Лифттэй',
                            enabled: _hasElevator,
                            onChanged: (value) =>
                                setState(() => _hasElevator = value),
                          ),
                          _SwitchRow(
                            label: 'Хүртээмжтэй ариун цэврийн өрөөтэй',
                            enabled: _accessibleRestroom,
                            onChanged: (value) =>
                                setState(() => _accessibleRestroom = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _EditSection(
                        title: 'ДИЖИТАЛ ҮЙЛЧИЛГЭЭ',
                        children: [
                          _SwitchRow(
                            label: 'Онлайн үйлчилгээтэй',
                            enabled: _onlineService,
                            onChanged: (value) =>
                                setState(() => _onlineService = value),
                          ),
                          _SwitchRow(
                            label: 'Цаг захиалах боломжтой',
                            enabled: _appointmentBooking,
                            onChanged: (value) =>
                                setState(() => _appointmentBooking = value),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      const _BottomInfoNote(),
                    ],
                  ),
                ),
              ),
              _BottomActions(
                primary: 'Өөрчлөлт хадгалах',
                onCancel: () => context.pop(),
                onPrimary: _save,
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

class _TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopBar({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
      child: Row(
        children: [
          Material(
            color: const Color(0xFFF8FAFC),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onBack,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Color(0xFF334155),
                  size: 23,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              softWrap: true,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFE4FF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Энд хадгалсан мэдээлэл dashboard, preview, статистик дээр шууд ашиглагдана.',
              style: TextStyle(
                color: Color(0xFF1D4ED8),
                fontSize: 13,
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

class _EditSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _EditSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEFF3F8)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final double height;
  final int maxLines;
  final IconData? icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _EditField({
    required this.label,
    required this.controller,
    this.height = 52,
    this.maxLines = 1,
    this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            maxLines: maxLines,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              prefixIcon: icon == null
                  ? null
                  : Icon(icon, color: const Color(0xFF94A3B8), size: 17),
              filled: true,
              fillColor: const Color(0xFFFBFCFE),
              constraints: BoxConstraints(minHeight: height),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Color(0xFFDCE3EC)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MapSection extends StatelessWidget {
  final TextEditingController locationController;
  final double latitude;
  final double longitude;
  final VoidCallback onMovePin;

  const _MapSection({
    required this.locationController,
    required this.latitude,
    required this.longitude,
    required this.onMovePin,
  });

  @override
  Widget build(BuildContext context) {
    return _EditSection(
      title: 'ГАЗРЫН ЗУРАГ',
      children: [
        Row(
          children: [
            const Spacer(),
            TextButton.icon(
              onPressed: onMovePin,
              icon: const Icon(Icons.my_location_rounded, size: 16),
              label: const Text('Байршил солих'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                textStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        Container(
          height: 116,
          decoration: BoxDecoration(
            color: const Color(0xFFDCE8EE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: CustomPaint(
            painter: _MiniMapPainter(),
            child: const Center(
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _EditField(
          label: 'Байршлын тайлбар',
          controller: locationController,
          validator: (value) =>
              Validators.required(value, message: 'Байршил шаардлагатай.'),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFE),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE3EC)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Координат',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${latitude.toStringAsFixed(6)} N, ${longitude.toStringAsFixed(6)} E',
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.my_location_rounded,
                color: Color(0xFFCBD5E1),
                size: 18,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withValues(alpha: 0.84)
      ..strokeWidth = 5;
    canvas.drawLine(
      Offset(0, size.height * 0.45),
      Offset(size.width, size.height * 0.45),
      road,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.72),
      Offset(size.width, size.height * 0.72),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.32, 0),
      Offset(size.width * 0.30, size.height),
      road,
    );
    canvas.drawLine(
      Offset(size.width * 0.66, 0),
      Offset(size.width * 0.68, size.height),
      road,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HoursSection extends StatelessWidget {
  final List<BusinessHour> hours;
  final void Function(int index, BusinessHour hour) onChanged;

  const _HoursSection({required this.hours, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return _EditSection(
      title: 'АЖЛЫН ЦАГ',
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEAFBF1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBEEBD1)),
          ),
          child: const Row(
            children: [
              Icon(Icons.schedule_rounded, color: Color(0xFF16A34A), size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ажлын цаг өөрчлөгдвөл preview дээрх нээлттэй төлөв шинэчлэгдэнэ.',
                  style: TextStyle(
                    color: Color(0xFF16A34A),
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (var i = 0; i < hours.length; i++)
          _HourRow(hour: hours[i], onChanged: (value) => onChanged(i, value)),
      ],
    );
  }
}

class _HourRow extends StatelessWidget {
  final BusinessHour hour;
  final ValueChanged<BusinessHour> onChanged;

  const _HourRow({required this.hour, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final times = const ['08:00', '09:00', '10:00', '16:00', '18:00', '20:00'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dayToggle = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch.adaptive(
                value: hour.open,
                onChanged: (value) => onChanged(hour.copyWith(open: value)),
                activeThumbColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              SizedBox(
                width: 68,
                child: Text(
                  hour.day,
                  maxLines: 2,
                  softWrap: true,
                  style: TextStyle(
                    color: hour.open
                        ? AppColors.textDark
                        : const Color(0xFFCBD5E1),
                    fontSize: 13,
                    height: 1.12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
          final timeRange = Row(
            children: [
              Expanded(
                child: _TimeDropdown(
                  value: hour.start,
                  values: times,
                  enabled: hour.open,
                  onChanged: (value) => onChanged(hour.copyWith(start: value)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('-', style: TextStyle(color: Color(0xFFCBD5E1))),
              ),
              Expanded(
                child: _TimeDropdown(
                  value: hour.end,
                  values: times,
                  enabled: hour.open,
                  onChanged: (value) => onChanged(hour.copyWith(end: value)),
                ),
              ),
            ],
          );

          if (constraints.maxWidth < 330) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [dayToggle, const SizedBox(height: 8), timeRange],
            );
          }

          return Row(
            children: [
              dayToggle,
              const SizedBox(width: 8),
              Expanded(child: timeRange),
            ],
          );
        },
      ),
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  final String value;
  final List<String> values;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _TimeDropdown({
    required this.value,
    required this.values,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDCE3EC)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: values.contains(value) ? value : values.first,
          isExpanded: true,
          iconSize: 16,
          onChanged: enabled
              ? (value) {
                  if (value != null) onChanged(value);
                }
              : null,
          items: values
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(item, style: const TextStyle(fontSize: 12)),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.label,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final TextEditingController controller;

  const _NumberField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Зогсоолын тоо',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 92,
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xFFFBFCFE),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFDCE3EC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'зогсоол',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BottomInfoNote extends StatelessWidget {
  const _BottomInfoNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Одоогийн төлөв, хүлээлтийн цаг, статистикийг систем автоматаар тооцоолно.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final String primary;
  final VoidCallback onCancel;
  final VoidCallback onPrimary;

  const _BottomActions({
    required this.primary,
    required this.onCancel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
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
  final VoidCallback onPressed;
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
      fontSize: 16,
      fontWeight: FontWeight.w900,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 54),
      child: primary
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
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
                  horizontal: 14,
                  vertical: 12,
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
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE7ECF3)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.042),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );
}
