import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/pastel_app_background.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/business_models.dart';
import '../providers/business_provider.dart';
import '../widgets/business_text_scale.dart';

class BusinessShellScreen extends StatefulWidget {
  const BusinessShellScreen({super.key});

  @override
  State<BusinessShellScreen> createState() => _BusinessShellScreenState();
}

class _BusinessShellScreenState extends State<BusinessShellScreen> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final message = context.select((BusinessProvider p) => p.lastSyncMessage);
    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
        context.read<BusinessProvider>().clearMessage();
      });
    }

    return BusinessTextScale(
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: PastelAppBackground(
          child: IndexedStack(
            index: _index,
            children: [
              const _HomeTab(),
              const _RewardsTab(),
              const _StatsTab(),
              _ProfileTab(onOpenInfo: () => context.push('/business/info')),
            ],
          ),
        ),
        bottomNavigationBar: _BusinessNav(
          index: _index,
          onTap: (value) => setState(() => _index = value),
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>();
    final profile = business.profile;
    final analytics = business.analytics;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: business.refreshAnalytics,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 30),
              child: _HomeHeader(profile: profile),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 126),
              child: Column(
                children: [
                  _MetricGrid(
                    items: [
                      _Metric(
                        Icons.visibility_outlined,
                        analytics.todayViews.toString(),
                        'Өнөөдрийн үзэлт',
                        AppColors.primary,
                      ),
                      _Metric(
                        Icons.navigation_outlined,
                        analytics.routeEntries.toString(),
                        'Маршрутаас орсон',
                        const Color(0xFF16A34A),
                      ),
                      _Metric(
                        Icons.sell_outlined,
                        business.activePromotions.length.toString(),
                        'Идэвхтэй санал',
                        const Color(0xFFD97706),
                      ),
                      _Metric(
                        Icons.bookmark_border_rounded,
                        analytics.savedUsers.toString(),
                        'Хадгалсан',
                        const Color(0xFF9333EA),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _BlueCard(onRefresh: business.refreshAnalytics),
                  const SizedBox(height: 24),
                  _PreviewCard(
                    profile: profile,
                    promotion: business.activePromotions.isEmpty
                        ? null
                        : business.activePromotions.first,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  final BusinessProfile profile;

  const _HomeHeader({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Байгууллагын нүүр',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontSize: 29,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    profile.organizationName,
                    style: const TextStyle(
                      color: Color(0xFF9AA3B2),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                const _CircleButton(icon: Icons.notifications_none_rounded),
                Positioned(
                  right: 9,
                  top: 10,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 30),
        Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            _Pill(
              Icons.check_circle_outline_rounded,
              _statusLabel(profile.status),
              _statusColor(profile.status),
            ),
            const _Pill(
              Icons.search_rounded,
              'Хайлт дээр идэвхтэй',
              AppColors.primary,
            ),
            _Pill(
              Icons.location_on_outlined,
              profile.location,
              const Color(0xFF9333EA),
            ),
          ],
        ),
      ],
    );
  }
}

class _RewardsTab extends StatelessWidget {
  const _RewardsTab();

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _RewardSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>();
    final promotions = business.promotions;

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: _RewardsHeader(
              activeCount: business.activePromotions.length,
              onCreate: () => _openSheet(context),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEFF3F8)),
          Expanded(
            child: promotions.isEmpty
                ? const _EmptyState(
                    icon: Icons.sell_outlined,
                    title: 'Урамшуулал алга',
                    message: 'Шинэ урамшуулал нийтэлж хэрэглэгчдэд харуулна.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 126),
                    itemCount: promotions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final promo = promotions[index];
                      return _PromoCard(
                        promo: promo,
                        onToggle: () => context
                            .read<BusinessProvider>()
                            .togglePromotion(promo.id),
                        onEdit: () => _openSheet(context),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RewardsHeader extends StatelessWidget {
  final int activeCount;
  final VoidCallback onCreate;

  const _RewardsHeader({required this.activeCount, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Урамшуулал',
          style: TextStyle(
            color: AppColors.textDark,
            fontSize: 24,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          '$activeCount идэвхтэй санал',
          style: const TextStyle(
            color: Color(0xFF9AA3B2),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final button = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: ElevatedButton.icon(
        onPressed: onCreate,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Шинэ урамшуулал',
          maxLines: 2,
          textAlign: TextAlign.center,
          softWrap: true,
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 13,
            height: 1.12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: button),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 14),
            Flexible(child: button),
          ],
        );
      },
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>();
    final analytics = business.analytics;
    final profile = business.profile;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: business.refreshAnalytics,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 104),
          children: [
            const Text(
              'Статистик',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Сүүлийн 7 хоног · ${profile.organizationName}',
              style: const TextStyle(
                color: Color(0xFF8E99AA),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _StatsHero(routeAdds: analytics.routeAdds),
            const SizedBox(height: 8),
            _MetricGrid(
              compact: true,
              items: [
                _Metric(
                  Icons.search_rounded,
                  analytics.searchViews.toString(),
                  'Хайлтад харагдсан',
                  AppColors.primary,
                ),
                _Metric(
                  Icons.navigation_outlined,
                  analytics.routeEntries.toString(),
                  'Маршрутаас орсон',
                  const Color(0xFF16A34A),
                ),
                _Metric(
                  Icons.sell_outlined,
                  analytics.promotionViews.toString(),
                  'Урамшуулал үзсэн',
                  const Color(0xFFD97706),
                ),
                _Metric(
                  Icons.trending_up_rounded,
                  analytics.routeAdds.toString(),
                  'Маршрутад нэмсэн',
                  const Color(0xFF9333EA),
                ),
                _Metric(
                  Icons.bookmark_border_rounded,
                  analytics.savedUsers.toString(),
                  'Хадгалсан хэрэглэгч',
                  const Color(0xFFDB2777),
                ),
                _Metric(
                  Icons.visibility_outlined,
                  analytics.todayViews.toString(),
                  'Өнөөдрийн үзэлт',
                  const Color(0xFF0891B2),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ChartCard(
              title: '7 хоногийн үзэлт',
              child: SizedBox(
                height: 178,
                child: _LineChart(values: analytics.dailyViews),
              ),
            ),
            const SizedBox(height: 8),
            _ChartCard(
              title: 'Идэвхтэй цаг',
              subtitle: 'Хэрэглэгчид хамгийн идэвхтэй хайдаг цаг',
              child: Column(
                children: [
                  SizedBox(
                    height: 146,
                    child: _BarChart(values: analytics.hourlyActivity),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.primary,
                        size: 17,
                      ),
                      const Text(
                        'Хамгийн идэвхтэй цаг:',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        analytics.activeHourLabel,
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _PerformanceCard(promotions: business.promotions),
            const SizedBox(height: 8),
            const _PrivacyNote(),
          ],
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final VoidCallback onOpenInfo;

  const _ProfileTab({required this.onOpenInfo});

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<BusinessProvider>().profile;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 104),
        children: [
          const Text(
            'Байгууллагын профайл',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 22,
              height: 1.08,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          _ProfileSummary(profile: profile),
          const SizedBox(height: 10),
          const _SectionLabel('БАЙГУУЛЛАГА'),
          const SizedBox(height: 4),
          _MenuGroup(
            rows: [
              _MenuRowData(
                Icons.business_rounded,
                'Байгууллагын мэдээлэл',
                onTap: onOpenInfo,
              ),
              const _MenuRowData(
                Icons.verified_user_outlined,
                'Баталгаажуулалтын төлөв',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _SectionLabel('ТОХИРГОО'),
          const SizedBox(height: 4),
          const _MenuGroup(
            rows: [
              _MenuRowData(Icons.notifications_none_rounded, 'Мэдэгдэл'),
              _MenuRowData(Icons.shield_outlined, 'Аюулгүй байдал'),
            ],
          ),
          const SizedBox(height: 8),
          _MenuGroup(
            rows: [
              _MenuRowData(
                Icons.logout_rounded,
                'Гарах',
                danger: true,
                onTap: () => _logout(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'AccessPlan UB v1.0.0 · Байгууллагын эрх',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFFCBD5E1),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardSheet extends StatefulWidget {
  const _RewardSheet();

  @override
  State<_RewardSheet> createState() => _RewardSheetState();
}

class _RewardSheetState extends State<_RewardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _limit = TextEditingController();
  var _isActive = true;
  var _showOnMap = true;
  var _isSponsored = false;
  var _type = 'Урамшуулал';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _start.text = _formatDate(today);
    _end.text = _formatDate(today.add(const Duration(days: 30)));
    _limit.text = '1 хэрэглэгч 1 удаа';
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _start.dispose();
    _end.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) controller.text = _formatDate(picked);
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<BusinessProvider>().addPromotion(
      title: _title.text.trim(),
      type: _type,
      description: _description.text.trim(),
      startDate: _start.text,
      endDate: _end.text,
      limit: _limit.text.trim(),
      isActive: _isActive,
      showOnMap: _showOnMap,
      isSponsored: _isSponsored,
    );
    if (mounted) Navigator.pop(context);
  }

  void _useTestPromotion() {
    final endDate = DateTime.now().add(const Duration(days: 7));
    setState(() {
      _title.text = '2 кофе авбал 1 амттан бэлэгтэй';
      _description.text =
          'Өнөөдөр 18:00 хүртэл 2 кофе худалдан авсан хэрэглэгчдэд 1 амттан бэлэглэнэ.';
      _type = 'promotion';
      _end.text = _formatDate(endDate);
      _isActive = true;
      _showOnMap = true;
      _isSponsored = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: MediaQuery.sizeOf(context).height * 0.86,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Шинэ урамшуулал',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: () => Navigator.pop(context),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F3F7),
                        foregroundColor: const Color(0xFF64748B),
                      ),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEFF3F8)),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _useTestPromotion,
                          icon: const Icon(Icons.card_giftcard_rounded),
                          label: const Text('Use Test Promotion'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _FormLabel('Урамшууллын нэр'),
                      _SheetInput(
                        controller: _title,
                        hint: 'Жишээ: Кофе 10% хямдрал',
                        validator: _required,
                      ),
                      const SizedBox(height: 18),
                      const _FormLabel('Төрөл'),
                      _PromoTypeDropdown(
                        value: _type,
                        onChanged: (value) => setState(() => _type = value),
                      ),
                      const SizedBox(height: 18),
                      _FormLabel('Тайлбар'),
                      _SheetInput(
                        controller: _description,
                        hint: 'Санал, нөхцөлийн тайлбар...',
                        height: 78,
                        maxLines: 3,
                        validator: _required,
                      ),
                      const SizedBox(height: 18),
                      _ResponsiveSheetFieldPair(
                        left: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FormLabel('Эхлэх огноо'),
                            _SheetInput(
                              controller: _start,
                              readOnly: true,
                              onTap: () => _pickDate(_start),
                              trailing: Icons.calendar_today_outlined,
                              validator: _required,
                            ),
                          ],
                        ),
                        right: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FormLabel('Дуусах огноо'),
                            _SheetInput(
                              controller: _end,
                              readOnly: true,
                              onTap: () => _pickDate(_end),
                              trailing: Icons.calendar_today_outlined,
                              validator: _required,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _FormLabel('Хязгаарлалт'),
                      _SheetInput(
                        controller: _limit,
                        hint: 'Жишээ: 1 хэрэглэгч 1 удаа',
                      ),
                      const SizedBox(height: 18),
                      _PromotionSwitch(
                        label: 'Active',
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                      _PromotionSwitch(
                        label: 'Show on map',
                        value: _showOnMap,
                        onChanged: (value) =>
                            setState(() => _showOnMap = value),
                      ),
                      _PromotionSwitch(
                        label: 'Sponsored',
                        value: _isSponsored,
                        onChanged: (value) =>
                            setState(() => _isSponsored = value),
                      ),
                      const SizedBox(height: 18),
                      const _InfoBox(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
                child: SafeArea(
                  top: false,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cancel = _SheetButton(
                        label: 'Болих',
                        onTap: () => Navigator.pop(context),
                      );
                      final publish = _SheetButton(
                        label: 'Нийтлэх',
                        primary: true,
                        onTap: _publish,
                      );

                      if (constraints.maxWidth < 340) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(width: double.infinity, child: publish),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: cancel),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: cancel),
                          const SizedBox(width: 14),
                          Expanded(flex: 2, child: publish),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Заавал бөглөнө.';
    return null;
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _PromoTypeDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _PromoTypeDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E6EE), width: 1.4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: const [
            DropdownMenuItem(value: 'promotion', child: Text('Promotion')),
            DropdownMenuItem(value: 'discount', child: Text('Discount')),
            DropdownMenuItem(
              value: 'announcement',
              child: Text('Announcement'),
            ),
            DropdownMenuItem(value: 'Урамшуулал', child: Text('Урамшуулал')),
            DropdownMenuItem(value: 'Хямдрал', child: Text('Хямдрал')),
            DropdownMenuItem(
              value: 'Эрхийн бичиг',
              child: Text('Эрхийн бичиг'),
            ),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}

class _PromotionSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PromotionSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeThumbColor: AppColors.primary,
      title: Text(
        label,
        style: const TextStyle(
          color: AppColors.textDark,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  final BusinessProfile profile;

  const _ProfileSummary({required this.profile});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF4EA1FF), AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.24),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 46,
                    ),
                  ),
                  Positioned(
                    right: -6,
                    bottom: -4,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF16C55E),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.organizationName,
                      maxLines: 2,
                      softWrap: true,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 20,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _Badge(
                      _statusLabel(profile.status),
                      _statusColor(profile.status),
                      textSize: 12,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF9AA3B2),
                          size: 18,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            profile.location,
                            maxLines: 2,
                            softWrap: true,
                            style: const TextStyle(
                              color: Color(0xFF9AA3B2),
                              fontSize: 12.5,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 320) {
                return Column(
                  children: [
                    _InfoTile(label: 'Ангилал', value: profile.activityType),
                    const SizedBox(height: 12),
                    _InfoTile(label: 'Утас', value: profile.phone),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _InfoTile(
                      label: 'Ангилал',
                      value: profile.activityType,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InfoTile(label: 'Утас', value: profile.phone),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final BusinessPromotion promo;
  final VoidCallback onToggle;
  final VoidCallback onEdit;

  const _PromoCard({
    required this.promo,
    required this.onToggle,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = _promoColor(promo.type);
    final stateColor = promo.active
        ? const Color(0xFF16A34A)
        : const Color(0xFFD97706);
    return _Card(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SoftIcon(_promoIcon(promo.type), typeColor, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promo.title,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 15,
                        height: 1.14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        _Badge(
                          promo.type,
                          typeColor,
                          textSize: 11,
                          horizontalPadding: 9,
                          verticalPadding: 4,
                        ),
                        _Badge(
                          promo.active ? 'Идэвхтэй' : 'Түр зогссон',
                          stateColor,
                          textSize: 11,
                          horizontalPadding: 9,
                          verticalPadding: 4,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            promo.description,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
              height: 1.28,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF9AA3B2),
                size: 14,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  promo.dateRange,
                  style: const TextStyle(
                    color: Color(0xFF9AA3B2),
                    fontSize: 12.5,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${promo.impressions} үзэлт',
                style: const TextStyle(
                  color: Color(0xFF9AA3B2),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final edit = _ActionButton(
                Icons.edit_outlined,
                'Засах',
                onTap: onEdit,
              );
              final toggle = _ActionButton(
                promo.active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                promo.active ? 'Зогсоох' : 'Идэвхжүүлэх',
                color: promo.active
                    ? const Color(0xFFD97706)
                    : const Color(0xFF16A34A),
                onTap: onToggle,
              );

              if (constraints.maxWidth < 330) {
                return Column(
                  children: [
                    SizedBox(width: double.infinity, child: edit),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: toggle),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: edit),
                  const SizedBox(width: 8),
                  Expanded(child: toggle),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<_Metric> items;
  final bool compact;

  const _MetricGrid({required this.items, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = compact ? 8.0 : 12.0;
        final itemWidth = (constraints.maxWidth - spacing) / 2;
        final itemHeight = compact ? 136.0 : 136.0;

        return Wrap(
          spacing: spacing,
          runSpacing: compact ? 6 : 12,
          children: [
            for (final metric in items)
              SizedBox(
                width: itemWidth,
                height: itemHeight,
                child: _MetricCard(metric, compact: compact),
              ),
          ],
        );
      },
    );
  }
}

class _Metric {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _Metric(this.icon, this.value, this.label, this.color);
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;
  final bool compact;

  const _MetricCard(this.metric, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.all(compact ? 14 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SoftIcon(metric.icon, metric.color, size: 38),
          SizedBox(height: compact ? 10 : 14),
          Text(
            metric.value,
            style: TextStyle(
              color: metric.color,
              fontSize: compact ? 21 : 25,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: compact ? 5 : 7),
          Text(
            metric.label,
            maxLines: 2,
            softWrap: true,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: compact ? 11 : 13,
              height: 1.15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlueCard extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _BlueCard({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -56,
            top: -74,
            child: _Decor(
              size: 118,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 29,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      'Таны байгууллага хэрэглэгчдийн маршрутад харагдаж байна',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.5,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Хэрэглэгчид ойролцоох үйлчилгээ хайх үед таны байгууллага санал болж, статистик нь шууд шинэчлэгдэнэ.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.36,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Статистик шинэчлэх'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final BusinessProfile profile;
  final BusinessPromotion? promotion;

  const _PreviewCard({required this.profile, required this.promotion});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Хэрэглэгчдэд харагдах',
                    style: TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _Badge(
                  'Одоо нээлттэй',
                  Color(0xFF16A34A),
                  textSize: 13,
                  horizontalPadding: 14,
                  verticalPadding: 7,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEFF3F8)),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        profile.organizationName,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 18.5,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFF59E0B),
                      size: 21,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      '4.8',
                      style: TextStyle(
                        color: Color(0xFF334155),
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  profile.activityType,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _Inline(Icons.location_on_outlined, '0.4 км'),
                    _Inline(Icons.schedule_rounded, 'Хүлээлт: 10-15 мин'),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    if (profile.hasParking)
                      const _OutlineChip(
                        Icons.local_parking_outlined,
                        'Зогсоолтой',
                      ),
                    if (profile.wheelchairAccessible)
                      const _OutlineChip(
                        Icons.accessible_forward_rounded,
                        'Хүртээмжтэй',
                      ),
                    if (profile.onlineService)
                      const _OutlineChip(Icons.language_rounded, 'Онлайн'),
                  ],
                ),
                if (promotion != null) ...[
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      '% Урамшуулал: ${promotion!.title}',
                      style: const TextStyle(
                        color: Color(0xFF9A4B00),
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsHero extends StatelessWidget {
  final int routeAdds;

  const _StatsHero({required this.routeAdds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -54,
            top: -62,
            child: _Decor(
              size: 118,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.trending_up_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 16),
              Text.rich(
                TextSpan(
                  text: 'Танай байгууллага энэ 7 хоногт ',
                  children: [
                    TextSpan(
                      text: '$routeAdds удаа',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const TextSpan(
                      text:
                          '\nхэрэглэгчийн маршрутын ойролцоо санал болгогдсон.',
                    ),
                  ],
                ),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _ChartCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF9AA3B2),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  final List<int> values;

  const _LineChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _LinePainter(values), size: Size.infinite);
  }
}

class _LinePainter extends CustomPainter {
  final List<int> values;
  final days = const ['Да', 'Мя', 'Лх', 'Пү', 'Ба', 'Бя', 'Ня'];

  _LinePainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 26.0;
    const right = 10.0;
    const top = 6.0;
    const bottom = 28.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxValue = max(120, values.reduce(max));
    final step = (maxValue / 4).ceil();
    final grid = Paint()
      ..color = const Color(0xFFE8EEF6)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = step * i;
      final dy = chart.bottom - (y / (step * 4)) * chart.height;
      canvas.drawLine(Offset(chart.left, dy), Offset(chart.right, dy), grid);
      _text(canvas, '$y', Offset(0, dy - 8), 11);
    }

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final dx = chart.left + (chart.width / (values.length - 1)) * i;
      final dy = chart.bottom - (values[i] / (step * 4)) * chart.height;
      points.add(Offset(dx, dy));
      _text(canvas, days[i], Offset(dx - 8, chart.bottom + 9), 12);
    }

    final fill = Path()
      ..moveTo(points.first.dx, chart.bottom)
      ..lineTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      fill.lineTo(point.dx, point.dy);
    }
    fill
      ..lineTo(points.last.dx, chart.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x332563EB), Color(0x002563EB)],
        ).createShader(chart),
    );

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (final point in points) {
      canvas.drawCircle(point, 3.2, Paint()..color = AppColors.primary);
      canvas.drawCircle(point, 1.4, Paint()..color = Colors.white);
    }
  }

  void _text(Canvas canvas, String text, Offset offset, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: const Color(0xFF94A3B8), fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) =>
      oldDelegate.values != values;
}

class _BarChart extends StatelessWidget {
  final List<int> values;

  const _BarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _BarPainter(values), size: Size.infinite);
  }
}

class _BarPainter extends CustomPainter {
  final List<int> values;
  final labels = const [
    '09:00',
    '',
    '11:00',
    '',
    '13:00',
    '',
    '15:00',
    '',
    '17:00',
  ];

  _BarPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 24.0;
    const right = 8.0;
    const top = 4.0;
    const bottom = 24.0;
    final chart = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    final maxValue = max(80, values.reduce(max));
    final barWidth = chart.width / values.length * 0.64;
    for (var y = 0; y <= maxValue; y += max(20, maxValue ~/ 4)) {
      final dy = chart.bottom - (y / maxValue) * chart.height;
      _text(canvas, '$y', Offset(0, dy - 8), 10.5);
    }
    for (var i = 0; i < values.length; i++) {
      final dx =
          chart.left + (chart.width / values.length) * i + barWidth * 0.18;
      final barHeight = (values[i] / maxValue) * chart.height;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(dx, chart.bottom - barHeight, barWidth, barHeight),
        const Radius.circular(4),
      );
      canvas.drawRRect(rect, Paint()..color = AppColors.primary);
      if (labels[i].isNotEmpty) {
        _text(canvas, labels[i], Offset(dx - 2, chart.bottom + 8), 11);
      }
    }
  }

  void _text(Canvas canvas, String text, Offset offset, double size) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: const Color(0xFF94A3B8), fontSize: size),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _BarPainter oldDelegate) =>
      oldDelegate.values != values;
}

class _PerformanceCard extends StatelessWidget {
  final List<BusinessPromotion> promotions;

  const _PerformanceCard({required this.promotions});

  @override
  Widget build(BuildContext context) {
    if (promotions.isEmpty) {
      return const _Card(
        padding: EdgeInsets.all(18),
        child: Text(
          'Урамшууллын үзүүлэлт урамшуулал нийтэлсний дараа харагдана.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    final maxSeen = promotions
        .map((promo) => promo.impressions)
        .reduce((a, b) => a > b ? a : b);
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Text(
              'Урамшууллын үр дүн',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          for (var i = 0; i < promotions.length; i++)
            _PerformanceRow(
              promotions[i].title,
              '${promotions[i].impressions} дарсан',
              '${promotions[i].routeAdds} маршрутад нэмсэн',
              maxSeen == 0 ? 0 : promotions[i].impressions / maxSeen,
              last: i == promotions.length - 1,
            ),
        ],
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  final String title;
  final String seen;
  final String added;
  final double progress;
  final bool last;

  const _PerformanceRow(
    this.title,
    this.seen,
    this.added,
    this.progress, {
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: last ? Colors.transparent : const Color(0xFFEFF3F8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                seen,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0, 1),
              minHeight: 5,
              backgroundColor: const Color(0xFFEFF3F8),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            added,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF3F8)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Хэрэглэгчийн хувийн маршрут, мэдээлэл байгууллагад харагдахгүй.',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;

  const _BusinessNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(Icons.home_outlined, Icons.home_rounded, 'Нүүр'),
      _NavItem(Icons.sell_outlined, Icons.sell_rounded, 'Санал'),
      _NavItem(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Стат'),
      _NavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Профайл'),
    ];

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (i) {
            final item = items[i];
            final selected = i == index;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: selected ? 42 : 36,
                      height: selected ? 42 : 36,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        selected ? item.active : item.icon,
                        color: selected
                            ? Colors.white
                            : const Color(0xFF9AA3B2),
                        size: selected ? 25 : 23,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: TextStyle(
                        color: selected
                            ? AppColors.primary
                            : const Color(0xFF9AA3B2),
                        fontSize: 11,
                        height: 1.05,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData active;
  final String label;

  const _NavItem(this.icon, this.active, this.label);
}

class _MenuGroup extends StatelessWidget {
  final List<_MenuRowData> rows;

  const _MenuGroup({required this.rows});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _MenuRow(rows[i]),
            if (i != rows.length - 1)
              const Divider(height: 1, color: Color(0xFFEFF3F8)),
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final _MenuRowData data;

  const _MenuRow(this.data);

  @override
  Widget build(BuildContext context) {
    final color = data.danger ? AppColors.error : AppColors.primary;
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: color, size: 25),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                data.title,
                style: TextStyle(
                  color: data.danger
                      ? AppColors.error
                      : const Color(0xFF334155),
                  fontSize: 15.5,
                  height: 1.18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: data.danger
                  ? AppColors.error.withValues(alpha: 0.65)
                  : const Color(0xFFCBD5E1),
              size: 26,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuRowData {
  final IconData icon;
  final String title;
  final bool danger;
  final VoidCallback? onTap;

  const _MenuRowData(this.icon, this.title, {this.danger = false, this.onTap});
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF9AA3B2),
        fontSize: 12.5,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String label;

  const _FormLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SheetInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final double height;
  final int maxLines;
  final bool readOnly;
  final VoidCallback? onTap;
  final IconData? trailing;
  final String? Function(String?)? validator;

  const _SheetInput({
    required this.controller,
    this.hint,
    this.height = 56,
    this.maxLines = 1,
    this.readOnly = false,
    this.onTap,
    this.trailing,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(
        color: AppColors.textDark,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(
          color: Color(0xFFCBD5E1),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        suffixIcon: trailing == null
            ? null
            : Icon(trailing, color: const Color(0xFF9AA3B2), size: 22),
        filled: true,
        fillColor: const Color(0xFFFBFCFE),
        constraints: BoxConstraints(minHeight: height),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE0E6EE), width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}

class _ResponsiveSheetFieldPair extends StatelessWidget {
  final Widget left;
  final Widget right;

  const _ResponsiveSheetFieldPair({required this.left, required this.right});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [left, const SizedBox(height: 18), right],
          );
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

class _InfoBox extends StatelessWidget {
  const _InfoBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFE4FF)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Хэрэглэгчидэд хэзээ харагдах вэ?',
            style: TextStyle(
              color: Color(0xFF1D4ED8),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Урамшуулал нийтлэгдмэгц байгууллагын preview, статистик, performance хэсэгт шууд орно.',
            style: TextStyle(
              color: Color(0xFF1D4ED8),
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _SheetButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: primary
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF374151),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9AA3B2),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value.isEmpty ? 'Оруулаагүй' : value,
            maxLines: 2,
            softWrap: true,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 15,
              height: 1.18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;

  const _CircleButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: const Color(0xFF334155), size: 28),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Pill(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 48,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 3,
              softWrap: true,
              style: TextStyle(
                color: color,
                fontSize: 14.5,
                height: 1.15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final double textSize;
  final double horizontalPadding;
  final double verticalPadding;

  const _Badge(
    this.label,
    this.color, {
    this.textSize = 13,
    this.horizontalPadding = 9,
    this.verticalPadding = 5,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 56,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 2,
        softWrap: true,
        style: TextStyle(
          color: color,
          fontSize: textSize,
          height: 1.15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SoftIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _SoftIcon(this.icon, this.color, {this.size = 50});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton(this.icon, this.label, {required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final active = color ?? const Color(0xFF475569);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 38),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: color == null
              ? const Color(0xFFFAFBFD)
              : active.withValues(alpha: 0.08),
          foregroundColor: active,
          side: BorderSide(
            color: color == null
                ? const Color(0xFFEFF2F6)
                : active.withValues(alpha: 0.22),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 12.5,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                softWrap: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Inline extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Inline(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 56,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 20),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 2,
              softWrap: true,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 15,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OutlineChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OutlineChip(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 56,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE8EEF6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              softWrap: true,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primary, size: 30),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Decor extends StatelessWidget {
  final double size;
  final Color color;

  const _Decor({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'pending':
      return 'Хүлээгдэж байна';
    case 'rejected':
      return 'Татгалзсан';
    default:
      return 'Баталгаажсан';
  }
}

Color _statusColor(String status) {
  switch (status) {
    case 'pending':
      return const Color(0xFFD97706);
    case 'rejected':
      return AppColors.error;
    default:
      return const Color(0xFF16A34A);
  }
}

IconData _promoIcon(String type) {
  switch (type) {
    case 'Хямдрал':
      return Icons.percent_rounded;
    case 'Эрхийн бичиг':
      return Icons.confirmation_number_outlined;
    default:
      return Icons.sell_outlined;
  }
}

Color _promoColor(String type) {
  switch (type) {
    case 'Хямдрал':
      return const Color(0xFFD97706);
    case 'Эрхийн бичиг':
      return const Color(0xFF9333EA);
    default:
      return AppColors.primary;
  }
}
