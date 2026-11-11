import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class ActivityLogScreen extends StatelessWidget {
  final String caseId;

  const ActivityLogScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'ประวัติการใช้งาน',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ActivityLogTabWidget(caseId: caseId),
    );
  }
}

class ActivityLogTabWidget extends StatelessWidget {
  final String caseId;

  const ActivityLogTabWidget({super.key, required this.caseId});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final caseObj = appState.cases.firstWhere(
      (c) => c.id == caseId,
      orElse: () => appState.cases.first,
    );

    final logs = caseObj.activityLogs;

    return logs.isEmpty
        ? const Center(
            child: Text(
              'ไม่มีประวัติการใช้งาน',
              style: TextStyle(color: AppColors.textMuted),
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              final isLast = index == logs.length - 1;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline Icon & Line
                  Column(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: log.iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(log.icon, size: 18, color: log.iconColor),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 40,
                          color: const Color(0xFFCBD5E1),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  // Log Detail Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.dateText,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                              children: [
                                TextSpan(
                                  text: '${log.title} ',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const TextSpan(
                                  text: 'โดย ',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                                TextSpan(
                                  text: log.authorName,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
  }
}
