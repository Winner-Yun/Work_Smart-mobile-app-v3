import 'package:flutter/material.dart';

class AttendanceCalendarSkeletonLoading extends StatefulWidget {
  const AttendanceCalendarSkeletonLoading({super.key});

  @override
  State<AttendanceCalendarSkeletonLoading> createState() =>
      _AttendanceCalendarSkeletonLoadingState();
}

class _AttendanceCalendarSkeletonLoadingState
    extends State<AttendanceCalendarSkeletonLoading>
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

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              // Calendar header — month title + prev/next nav circles.
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(
                          width: 150,
                          height: 24,
                          color: animatedColor,
                          opacity: pulse,
                          radius: 8,
                        ),
                        const SizedBox(height: 8),
                        _SkeletonBox(
                          width: 110,
                          height: 12,
                          color: animatedColor,
                          opacity: pulse,
                          radius: 6,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _SkeletonCircle(
                          size: 36,
                          color: animatedColor,
                          opacity: pulse,
                        ),
                        const SizedBox(width: 15),
                        _SkeletonCircle(
                          size: 36,
                          color: animatedColor,
                          opacity: pulse,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Legend row.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    for (int i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 15),
                      _SkeletonCircle(
                        size: 8,
                        color: animatedColor,
                        opacity: pulse,
                      ),
                      const SizedBox(width: 6),
                      _SkeletonBox(
                        width: 45,
                        height: 12,
                        color: animatedColor,
                        opacity: pulse,
                        radius: 6,
                      ),
                    ],
                  ],
                ),
              ),
              // Calendar grid — weekday row + 5x7 day cells.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        7,
                        (_) => _SkeletonBox(
                          width: 20,
                          height: 11,
                          color: animatedColor,
                          opacity: pulse,
                          radius: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    for (int row = 0; row < 5; row++) ...[
                      if (row > 0) const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(
                          7,
                          (_) => _SkeletonBox(
                            width: 38,
                            height: 38,
                            color: animatedColor,
                            opacity: pulse,
                            radius: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 25),
              // Day detail view.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).cardTheme.color?.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SkeletonBox(
                            width: 140,
                            height: 14,
                            color: animatedColor,
                            opacity: pulse,
                            radius: 6,
                          ),
                          _SkeletonBox(
                            width: 60,
                            height: 20,
                            color: animatedColor,
                            opacity: pulse,
                            radius: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: _SkeletonInfoCard(
                            color: animatedColor,
                            opacity: pulse,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SkeletonInfoCard(
                            color: animatedColor,
                            opacity: pulse,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              _SkeletonCircle(
                                size: 36,
                                color: animatedColor,
                                opacity: pulse,
                              ),
                              const SizedBox(width: 15),
                              _SkeletonBox(
                                width: 110,
                                height: 14,
                                color: animatedColor,
                                opacity: pulse,
                                radius: 6,
                              ),
                            ],
                          ),
                          _SkeletonBox(
                            width: 50,
                            height: 20,
                            color: animatedColor,
                            opacity: pulse,
                            radius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonInfoCard extends StatelessWidget {
  final Color color;
  final double opacity;

  const _SkeletonInfoCard({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonCircle(size: 16, color: color, opacity: opacity),
              const SizedBox(width: 6),
              _SkeletonBox(
                width: 55,
                height: 11,
                color: color,
                opacity: opacity,
                radius: 5,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SkeletonBox(
            width: 70,
            height: 18,
            color: color,
            opacity: opacity,
            radius: 6,
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
