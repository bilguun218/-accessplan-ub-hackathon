import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../widgets/citizen_report_card.dart';
import '../widgets/home_header.dart';
import '../widgets/insight_card.dart';
import '../widgets/planning_status_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/smart_summary_card.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback? onAddTask;
  final VoidCallback? onOpenPlanner;
  final VoidCallback? onOpenMap;
  final VoidCallback? onOpenReports;
  final VoidCallback? onOpenOrganizations;
  final VoidCallback? onOpenProfile;

  const HomeScreen({
    super.key,
    this.onAddTask,
    this.onOpenPlanner,
    this.onOpenMap,
    this.onOpenReports,
    this.onOpenOrganizations,
    this.onOpenProfile,
  });

  String _userName(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final name = user?.fullName.trim() ?? '';
    return name.isEmpty ? 'Хэрэглэгч' : name.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    final userName = _userName(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            HomeHeader(userName: userName, onAvatarTap: onOpenProfile),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SmartSummaryCard(onAddTask: onAddTask),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Шуурхай үйлдэл'),
            const SizedBox(height: 12),
            _QuickActionsGrid(
              onPlanner: onOpenPlanner,
              onMap: onOpenMap,
              onReports: onOpenReports,
              onOrganizations: onOpenOrganizations,
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Өнөөдрийн зөвлөмж'),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: InsightCard(
                        icon: Icons.lightbulb_outline,
                        accent: AppColors.primary,
                        message:
                            'Онлайнаар шийдэх боломжтой ажлуудыг эхэлж шалгаарай.',
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: InsightCard(
                        icon: Icons.alt_route,
                        accent: AppColors.primary,
                        message:
                            'Зайлшгүй очих маршрутыг нэгтгэвэл цаг хэмнэнэ.',
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: InsightCard(
                        icon: Icons.error_outline,
                        accent: AppColors.primary,
                        message:
                            'Маршрутын ойролцоох эвдрэл, саадыг шалгах боломжтой.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Төлөвлөлтийн төлөв'),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: PlanningStatusCard(
                items: [
                  PlanningStatusItem(
                    icon: Icons.cloud_done_outlined,
                    accent: AppColors.primary,
                    label: 'Онлайнаар шийдэх',
                    value: '0',
                    description: 'Гадуур гарахгүйгээр хийх боломжтой ажил',
                  ),
                  PlanningStatusItem(
                    icon: Icons.directions_walk,
                    accent: AppColors.primary,
                    label: 'Заавал очих',
                    value: '0',
                    description: 'Биечлэн очих шаардлагатай ажил',
                  ),
                  PlanningStatusItem(
                    icon: Icons.swap_horiz,
                    accent: AppColors.warning,
                    label: 'Сонголттой',
                    value: '0',
                    description: 'Хүргэлт эсвэл онлайн хувилбартай ажил',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('Иргэний оролцоо'),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CitizenReportCard(onReport: onOpenReports),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback? onPlanner;
  final VoidCallback? onMap;
  final VoidCallback? onReports;
  final VoidCallback? onOrganizations;

  const _QuickActionsGrid({
    this.onPlanner,
    this.onMap,
    this.onReports,
    this.onOrganizations,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.1,
        children: [
          QuickActionCard(
            icon: Icons.checklist_rtl,
            title: 'Ажил төлөвлөх',
            subtitle: 'To-do оруулж маршрут тооцох',
            accent: AppColors.primary,
            onTap: onPlanner,
          ),
          QuickActionCard(
            icon: Icons.location_on_outlined,
            title: 'Газрын зураг',
            subtitle: 'Байршил, түгжрэл харах',
            accent: AppColors.primary,
            onTap: onMap,
          ),
          QuickActionCard(
            icon: Icons.chat_bubble_outline,
            title: 'Санал, гомдол',
            subtitle: 'Хот тохижилтын асуудал мэдээлэх',
            accent: AppColors.primary,
            onTap: onReports,
          ),
          QuickActionCard(
            icon: Icons.apartment,
            title: 'Байгууллага',
            subtitle: 'Үйлчилгээний газар хайх',
            accent: AppColors.primary,
            onTap: onOrganizations,
          ),
        ],
      ),
    );
  }
}
