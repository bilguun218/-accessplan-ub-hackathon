import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../map/presentation/screens/map_screen.dart';
import '../widgets/main_bottom_nav.dart';
import 'home_screen.dart';
import 'placeholder_screen.dart';

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddTaskSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomeScreen(
        onAddTask: _showAddTaskSheet,
        onOpenPlanner: () => _go(1),
        onOpenMap: () => _go(2),
        onOpenReports: () => context.push('/reports'),
        onOpenOrganizations: () => context.push('/organizations'),
        onOpenProfile: () => _go(3),
      ),
      const PlaceholderScreen(
        title: 'Төлөвлөгөө',
        message: 'Ажлын төлөвлөгөө модуль удахгүй нэмэгдэнэ.',
        icon: Icons.checklist_rtl,
        showBack: false,
      ),
      const MapScreen(),
      const _ProfileTab(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _index,
        onTap: _go,
      ),
    );
  }
}

class _AddTaskSheet extends StatelessWidget {
  const _AddTaskSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Шинэ ажил нэмэх',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ажил төлөвлөх модуль удахгүй нэмэгдэнэ. Энэ хэсгээс to-do, маршрут, цаг хэмнэлтийг ухаалгаар тооцох болно.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: 'Хаах',
                outlined: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  String _userTypeLabel(String key) =>
      AppStrings.userTypeLabels[key] ?? key;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Профайл',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Хэрэглэгчийн мэдээлэл',
                style: TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
              if (user != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.lightGreenBg,
                            child: Text(
                              user.fullName.isNotEmpty
                                  ? user.fullName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.fullName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                                Text(
                                  user.email,
                                  style: const TextStyle(
                                      color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(
                          height: 24, color: AppColors.border),
                      _Row(
                          label: AppStrings.phone,
                          value: user.phone ?? '—'),
                      _Row(
                        label: AppStrings.userType,
                        value: _userTypeLabel(user.userType),
                      ),
                      _Row(
                        label: AppStrings.district,
                        value: user.district ?? '—',
                      ),
                      _Row(
                        label: AppStrings.language,
                        value: user.preferredLanguage == 'mn'
                            ? 'Монгол'
                            : 'English',
                      ),
                      if (user.createdAt != null)
                        _Row(
                          label: 'Бүртгүүлсэн',
                          value: DateFormat('yyyy-MM-dd')
                              .format(user.createdAt!),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              AppButton(
                label: AppStrings.logout,
                outlined: true,
                icon: Icons.logout,
                loading: auth.isLoading,
                onPressed: () async {
                  await context.read<AuthProvider>().logout();
                  if (context.mounted) context.go('/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
