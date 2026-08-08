import 'package:flutter/material.dart';

/// Pins [child] to a fixed [height] at the top of a CustomScrollView, like an
/// app bar, instead of letting it scroll away with the rest of the content.
class SliverPinnedHeaderDelegate extends SliverPersistentHeaderDelegate {
  const SliverPinnedHeaderDelegate({required this.child, required this.height});

  final Widget child;
  final double height;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Align(alignment: Alignment.topCenter, child: child);
  }

  @override
  bool shouldRebuild(covariant SliverPinnedHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}
