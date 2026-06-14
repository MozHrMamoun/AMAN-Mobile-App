import 'package:flutter/material.dart';

import '../register_page.dart';
import 'app_session.dart';

Future<void> showGuestLoginPrompt(
  BuildContext context, {
  bool replaceCurrentPage = false,
  bool popBlockedPageOnCancel = false,
}) async {
  final shouldRegister = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Registration required'),
        content: const Text(
          'This feature is not available in guest mode. Please register to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Register'),
          ),
        ],
      );
    },
  );

  if (!context.mounted) return;

  if (shouldRegister == true) {
    AppSession.clearGuestMode();
    final route = MaterialPageRoute(builder: (_) => const RegisterPage());
    if (replaceCurrentPage) {
      Navigator.of(context).pushReplacement(route);
    } else {
      Navigator.of(context).push(route);
    }
    return;
  }

  if (popBlockedPageOnCancel) {
    Navigator.of(context).maybePop();
  }
}
