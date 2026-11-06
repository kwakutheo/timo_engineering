import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Returns `true` to include the service report, `false` for an invoice-only
/// document, or `null` when the user cancels.
Future<bool?> choosePdfDocumentContents(
  BuildContext context, {
  required String action,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Choose document',
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'Would you like to include the Generator Service Report & Technical Remarks?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBlack,
            side: const BorderSide(color: AppColors.primaryBlack),
          ),
          child: const Text('Invoice Only'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlack,
            foregroundColor: Colors.white,
          ),
          child: Text(action),
        ),
      ],
    ),
  );
}
