import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../controllers/navigation_controller.dart';

class NavigationTabPills extends ConsumerWidget {
  const NavigationTabPills({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navigationIndexProvider);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPill(
            context: context,
            ref: ref,
            index: 0,
            currentIndex: currentIndex,
            label: 'Dashboard',
            icon: Icons.dashboard_rounded,
          ),
          const SizedBox(width: 4),
          _buildPill(
            context: context,
            ref: ref,
            index: 1,
            currentIndex: currentIndex,
            label: 'Invoices',
            icon: Icons.receipt_long_rounded,
          ),
          const SizedBox(width: 4),
          _buildPill(
            context: context,
            ref: ref,
            index: 2,
            currentIndex: currentIndex,
            label: 'Clients',
            icon: Icons.people_alt_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required BuildContext context,
    required WidgetRef ref,
    required int index,
    required int currentIndex,
    required String label,
    required IconData icon,
  }) {
    final isSelected = index == currentIndex;

    return InkWell(
      onTap: () {
        ref.read(navigationIndexProvider.notifier).state = index;
      },
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.primaryBlack
                  : AppColors.primaryBlack.withValues(alpha: 0.8),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? AppColors.primaryBlack
                    : AppColors.primaryBlack.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

