import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import 'glass.dart';

/// A small "buy me a coffee" appreciation button — purely a friendly
/// message, no payment processing (that would need a real backend/merchant
/// account this project doesn't have).
class CoffeeButton extends StatelessWidget {
  const CoffeeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'coffee',
      tooltip: tr('coffee_title'),
      onPressed: () => showDialog(
        context: context,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            opacity: 0.8,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('☕', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    tr('coffee_title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr('coffee_body'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(tr('coffee_thanks')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      child: const Text('☕', style: TextStyle(fontSize: 20)),
    );
  }
}
