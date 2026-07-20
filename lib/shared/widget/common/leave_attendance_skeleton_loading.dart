import 'package:flutter/material.dart';

class LeaveAttendanceSkeletonLoading extends StatefulWidget {
  const LeaveAttendanceSkeletonLoading({super.key});

  @override
  State<LeaveAttendanceSkeletonLoading> createState() =>
      _LeaveAttendanceSkeletonLoadingState();
}

class _LeaveAttendanceSkeletonLoadingState
    extends State<LeaveAttendanceSkeletonLoading>
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _SkeletonBox(
                        width: 120,
                        height: 18,
                        color: animatedColor,
                        opacity: pulse,
                        radius: 8,
                      ),
                      _SkeletonBox(
                        width: 50,
                        height: 16,
                        color: animatedColor,
                        opacity: pulse,
                        radius: 8,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Scrollable list section
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SkeletonRequestItem(
                      color: animatedColor,
                      opacity: pulse,
                    ),
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

class _SkeletonRequestItem extends StatelessWidget {
  final Color color;
  final double opacity;

  const _SkeletonRequestItem({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _SkeletonCircle(size: 40, color: color, opacity: opacity),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(
                  width: 100,
                  height: 15,
                  color: color,
                  opacity: opacity,
                  radius: 7,
                ),
                const SizedBox(height: 8),
                _SkeletonBox(
                  width: 120,
                  height: 13,
                  color: color,
                  opacity: opacity,
                  radius: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SkeletonBox(
            width: 60,
            height: 24,
            color: color,
            opacity: opacity,
            radius: 12,
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
