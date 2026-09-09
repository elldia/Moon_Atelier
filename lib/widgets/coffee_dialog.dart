import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/strings.dart';
import 'glass.dart';

final _buyMeACoffeeUrl = Uri.parse('https://buymeacoffee.com/elldia1222w');

/// A "buy me a coffee" appreciation button — opens the developer's real
/// Buy Me a Coffee page in a new tab. No payment is handled by this app
/// itself; it's just a link out to that external service.
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
                      onPressed: () => launchUrl(
                        _buyMeACoffeeUrl,
                        webOnlyWindowName: '_blank',
                      ),
                      child: Text(tr('coffee_buy')),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(tr('coffee_thanks')),
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
