// lib/widgets/notification_sheet.dart
//
// Shared notifications bottom sheet used by both Home and Settings (Profile).

import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../services/user_session.dart';
import '../services/link_opener.dart';

class NotificationItem {
  final IconData icon;
  final String title;
  final String body;
  final String time;
  final bool isNew;
  final String? url;
  const NotificationItem(
    this.icon,
    this.title,
    this.body,
    this.time,
    this.isNew, {
    this.url,
  });
}

class NotificationSheet extends StatelessWidget {
  const NotificationSheet({super.key});

  List<NotificationItem> _buildNotifs() {
    final bill = UserSession.instance.monthlyBillInr;
    final billStr = bill == null
        ? 'your current bill'
        : '₹${bill.toStringAsFixed(0)}';
    return [
      const NotificationItem(
        Icons.wb_sunny_outlined,
        'Solar Tip',
        'Today is sunny — ideal for running your high-power appliances to save on bills.',
        '2 min ago',
        true,
      ),
      const NotificationItem(
        Icons.account_balance_outlined,
        'PM Surya Ghar',
        'Central subsidy up to ₹78,000 for 3kW+ systems is now open.',
        '1 hr ago',
        true,
        url: 'https://pmsuryaghar.gov.in',
      ),
      const NotificationItem(
        Icons.bar_chart_outlined,
        'Report Ready',
        'Your last AR scan analysis has been processed. Tap to view.',
        '3 hrs ago',
        false,
      ),
      NotificationItem(
        Icons.bolt_outlined,
        'Energy Alert',
        'Your estimated monthly bill of $billStr can be reduced by up to 72% with solar.',
        'Yesterday',
        false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final notifs = _buildNotifs();
    final c = AppColors.of(context);
    final tt = Theme.of(context).textTheme;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      builder: (ctx, scrollController) => Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: c.onSurface,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: c.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '2 new',
                      style: TextStyle(
                        color: AppColors.primaryDeep,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifs.length,
                separatorBuilder: (context, index) =>
                    Divider(indent: 72, endIndent: 16, height: 1),
                itemBuilder: (_, i) {
                  final n = notifs[i];
                  return ListTile(
                    onTap: n.url == null
                        ? null
                        : () => openExternalLink(
                            n.url!,
                            context: context,
                            label: n.title,
                          ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (n.isNew ? c.primarySoft : c.surfaceMuted),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        n.icon,
                        color: n.isNew
                            ? AppColors.primaryDeep
                            : c.onSurfaceMuted,
                        size: 22,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          n.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: n.isNew
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: c.onSurface,
                          ),
                        ),
                        if (n.isNew) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 3),
                        Text(
                          n.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: c.onSurfaceMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          n.time,
                          style: TextStyle(
                            fontSize: 11,
                            color: c.primary.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    tileColor: n.isNew
                        ? c.primarySoft.withValues(alpha: 0.35)
                        : Colors.transparent,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience opener used by Home + Profile.
void showNotificationsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const NotificationSheet(),
  );
}
