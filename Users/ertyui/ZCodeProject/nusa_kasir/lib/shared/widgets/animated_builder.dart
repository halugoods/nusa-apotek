import 'package:flutter/material.dart';

/// Local AnimatedBuilder that works across Flutter versions.
///
/// Named NusaAnimatedBuilder to avoid name collision with Flutter's
/// built-in AnimatedBuilder class.
class NusaAnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const NusaAnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
    this.child,
  }) : super(listenable: animation);

  Animation<double> get animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) => builder(context, child);
}
