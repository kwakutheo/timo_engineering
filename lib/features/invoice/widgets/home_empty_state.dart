import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key, required this.onCreateNew});

  final VoidCallback onCreateNew;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryYellow.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long_outlined,
                size: 60, color: AppColors.yellowDark),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Invoices Yet',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the button below to create\nyour first invoice.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.textGrey),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: onCreateNew,
            icon: const Icon(Icons.add),
            label: const Text('Create First Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryYellow,
              foregroundColor: AppColors.primaryBlack,
              padding:
                  const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
