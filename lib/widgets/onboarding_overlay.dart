import 'package:flutter/material.dart';

import '../data/onboarding_store.dart';
import '../l10n/strings.dart';
import 'glass.dart';

/// One step of the onboarding walkthrough. If [targetKey] resolves to a
/// currently-laid-out widget, that widget gets a glowing spotlight outline
/// and the description card anchors near it; otherwise the card is shown
/// centered as a plain info step (for things — like "drag to highlight
/// while reading" — that don't correspond to a button on the current
/// screen).
class OnboardingStep {
  final GlobalKey? targetKey;
  final IconData icon;
  final String titleKey;
  final String descKey;

  const OnboardingStep({
    this.targetKey,
    required this.icon,
    required this.titleKey,
    required this.descKey,
  });
}

/// Shows the first-run walkthrough as a translucent overlay on top of the
/// real screen, spotlighting each real button in turn, if [steps] hasn't
/// been marked seen yet. Safe to call on every load — no-ops after the
/// first time the user picks "다신 안 보기".
Future<void> maybeShowOnboardingOverlay(
  BuildContext context,
  List<OnboardingStep> steps,
) async {
  if (OnboardingStore.hasSeen) return;
  if (!context.mounted) return;
  await Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, _) => FadeTransition(
        opacity: animation,
        child: _OnboardingOverlayView(steps: steps),
      ),
    ),
  );
}

class _OnboardingOverlayView extends StatefulWidget {
  final List<OnboardingStep> steps;
  const _OnboardingOverlayView({required this.steps});

  @override
  State<_OnboardingOverlayView> createState() => _OnboardingOverlayViewState();
}

class _OnboardingOverlayViewState extends State<_OnboardingOverlayView> {
  int _index = 0;

  Rect? _targetRect(GlobalKey? key) {
    final ctx = key?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _next() {
    if (_index >= widget.steps.length - 1) return;
    setState(() => _index++);
  }

  Future<void> _finish({required bool showAgainNextTime}) async {
    if (!showAgainNextTime) await OnboardingStore.markSeen();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final step = widget.steps[_index];
    final rect = _targetRect(step.targetKey);
    final isLast = _index == widget.steps.length - 1;

    const cardWidth = 340.0;
    final cardLeft = rect == null
        ? (size.width - cardWidth) / 2
        : (rect.left).clamp(16.0, size.width - cardWidth - 16.0);
    final cardTop = rect == null
        ? size.height / 2 - 110
        : (rect.bottom + 16 <= size.height - 240)
        ? rect.bottom + 16
        : (rect.top - 240).clamp(60.0, size.height - 260);

    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isLast ? null : _next,
            ),
          ),
          if (rect != null)
            Positioned(
              left: rect.left - 8,
              top: rect.top - 8,
              width: rect.width + 16,
              height: rect.height + 16,
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.55),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: cardLeft,
            top: cardTop,
            width: cardWidth,
            child: GlassCard(
              opacity: 0.92,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(step.icon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr(step.titleKey),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(tr(step.descKey)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_index + 1} / ${widget.steps.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (!isLast)
                          FilledButton(
                            onPressed: _next,
                            child: Text(tr('onb_next')),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _finish(showAgainNextTime: true),
                                child: Text(tr('onb_show_again')),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    _finish(showAgainNextTime: false),
                                child: Text(tr('onb_never_show')),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
