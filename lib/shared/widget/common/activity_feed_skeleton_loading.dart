import 'package:flutter/material.dart';

class ActivityFeedSkeletonLoading extends StatefulWidget {
  const ActivityFeedSkeletonLoading({super.key});

  @override
  State<ActivityFeedSkeletonLoading> createState() =>
      _ActivityFeedSkeletonLoadingState();
}

class _ActivityFeedSkeletonLoadingState
    extends State<ActivityFeedSkeletonLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color shimmerColor = Theme.of(context).dividerColor.withOpacity(0.45);
    final Color dimmedColor = shimmerColor.withOpacity(0.3);
    final Color brightColor = shimmerColor.withOpacity(0.75);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double pulse = 0.45 + (_controller.value * 0.35);
        final Color animatedColor =
            Color.lerp(dimmedColor, brightColor, _controller.value) ??
            shimmerColor;

        return Column(
          children: [
            // Search bar and sort button
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _SkeletonBox(
                      width: double.infinity,
                      height: 44,
                      color: animatedColor,
                      opacity: pulse,
                      radius: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _SkeletonBox(
                    width: 44,
                    height: 44,
                    color: animatedColor,
                    opacity: pulse,
                    radius: 12,
                  ),
                ],
              ),
            ),
            // Activity feed items list
            Expanded(
              child: ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _SkeletonActivityItem(
                    color: animatedColor,
                    opacity: pulse,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SkeletonActivityItem extends StatelessWidget {
  final Color color;
  final double opacity;

  const _SkeletonActivityItem({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle placeholder
          _SkeletonCircle(size: 34, color: color, opacity: opacity),
          const SizedBox(width: 10),
          // Title and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(
                  width: 120,
                  height: 14,
                  color: color,
                  opacity: opacity,
                  radius: 8,
                ),
                const SizedBox(height: 6),
                _SkeletonBox(
                  width: double.infinity,
                  height: 12,
                  color: color,
                  opacity: opacity,
                  radius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Time label
          _SkeletonBox(
            width: 45,
            height: 12,
            color: color,
            opacity: opacity,
            radius: 8,
          ),
        ],
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _SkeletonCircle({
    required this.size,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  final double opacity;
  final double radius;

  const _SkeletonBox({
    required this.width,
    required this.height,
    required this.color,
    required this.opacity,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: LimitedBox(
        maxWidth: width,
        child: Container(
          width: width == double.infinity ? double.infinity : null,
          constraints: BoxConstraints(maxWidth: width),
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}
