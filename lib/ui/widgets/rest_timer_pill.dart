import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Píldora flotante del descanso (RF-1/RF-16): sticky sobre el contenido,
/// radio `StadiumBorder`, indicador pulsante de 10 dp con `AnimationController`
/// en bucle (ping, designer §7.7) y botón «+30 s». Solo presenta estado:
/// la lógica del descanso vive en `RestTimer`/`RestNotifier` (spec 002).
class RestTimerPill extends StatefulWidget {
  final String label;
  final String time;
  final bool pulsing;
  final VoidCallback? onAddThirtySeconds;
  final Key? addButtonKey;

  const RestTimerPill({
    super.key,
    required this.label,
    required this.time,
    this.pulsing = true,
    this.onAddThirtySeconds,
    this.addButtonKey,
  });

  @override
  State<RestTimerPill> createState() => _RestTimerPillState();
}

class _RestTimerPillState extends State<RestTimerPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ping = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  @override
  void initState() {
    super.initState();
    _syncPing();
  }

  @override
  void didUpdateWidget(RestTimerPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pulsing != widget.pulsing) _syncPing();
  }

  void _syncPing() {
    if (widget.pulsing) {
      _ping.repeat(reverse: true);
    } else {
      _ping.stop();
      _ping.value = 1;
    }
  }

  @override
  void dispose() {
    _ping.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kSurfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kSurfaceContainerHighest),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _ping,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: kPrimary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            widget.label,
            style: textTheme.labelMedium?.copyWith(
              color: kSecondary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.time,
            style: textTheme.titleMedium?.copyWith(color: kOnSurface),
          ),
          if (widget.onAddThirtySeconds != null) ...[
            const SizedBox(width: 10),
            Material(
              color: kSurfaceBright,
              shape: const StadiumBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                key: widget.addButtonKey,
                onTap: widget.onAddThirtySeconds,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  child: Text(
                    '+30s',
                    style: textTheme.labelMedium?.copyWith(color: kPrimary),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}