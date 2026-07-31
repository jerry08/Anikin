import 'dart:async';

import 'package:flutter/material.dart';

class MarqueeText extends StatefulWidget {
  const MarqueeText({
    required this.text,
    this.style,
    this.animate = true,
    this.gap = 32,
    this.pixelsPerSecond = 32,
    this.startDelay = const Duration(milliseconds: 1200),
    this.semanticLabel,
    super.key,
  }) : assert(gap >= 0),
       assert(pixelsPerSecond > 0);

  final String text;
  final TextStyle? style;
  final bool animate;
  final double gap;
  final double pixelsPerSecond;
  final Duration startDelay;
  final String? semanticLabel;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  static const _isTest = bool.fromEnvironment('FLUTTER_TEST');

  late final AnimationController _controller;
  Timer? _startTimer;
  bool? _requestedAnimation;
  double? _requestedDistance;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleAnimation({required bool animate, required double distance}) {
    if (_requestedAnimation == animate &&
        _requestedDistance != null &&
        (_requestedDistance! - distance).abs() < 0.5) {
      return;
    }
    _requestedAnimation = animate;
    _requestedDistance = distance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _requestedAnimation != animate ||
          _requestedDistance != distance) {
        return;
      }
      _startTimer?.cancel();
      _controller
        ..stop()
        ..value = 0;
      if (!animate) {
        return;
      }
      final milliseconds = (distance / widget.pixelsPerSecond * 1000)
          .round()
          .clamp(3500, 60000);
      _controller.duration = Duration(milliseconds: milliseconds);
      _startTimer = Timer(widget.startDelay, () {
        if (mounted && _requestedAnimation == true) {
          _controller.repeat();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: style),
          maxLines: 1,
          textDirection: textDirection,
          textScaler: textScaler,
        )..layout();
        final overflows =
            constraints.maxWidth.isFinite &&
            painter.width > constraints.maxWidth + 0.5;
        final animate =
            widget.animate &&
            overflows &&
            !_isTest &&
            !MediaQuery.disableAnimationsOf(context);
        final distance = painter.width + widget.gap;
        _scheduleAnimation(animate: animate, distance: distance);

        final staticText = Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          overflow: overflows ? TextOverflow.fade : TextOverflow.clip,
          style: style,
        );
        if (!animate) {
          return Semantics(
            label: widget.semanticLabel ?? widget.text,
            excludeSemantics: true,
            child: staticText,
          );
        }

        final alignment = textDirection == TextDirection.ltr
            ? Alignment.centerLeft
            : Alignment.centerRight;
        return Semantics(
          label: widget.semanticLabel ?? widget.text,
          excludeSemantics: true,
          child: SizedBox(
            height: painter.height,
            child: ClipRect(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final direction = textDirection == TextDirection.ltr
                        ? -1.0
                        : 1.0;
                    return Transform.translate(
                      offset: Offset(
                        direction * distance * _controller.value,
                        0,
                      ),
                      child: child,
                    );
                  },
                  child: OverflowBox(
                    alignment: alignment,
                    minWidth: 0,
                    maxWidth: double.infinity,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: textDirection,
                      children: [
                        Text(widget.text, softWrap: false, style: style),
                        SizedBox(width: widget.gap),
                        Text(widget.text, softWrap: false, style: style),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
