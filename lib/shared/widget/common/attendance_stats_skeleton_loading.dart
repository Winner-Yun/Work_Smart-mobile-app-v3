import 'package:flutter/material.dart';

class AttendanceStatsSkeletonLoading extends StatefulWidget {
  const AttendanceStatsSkeletonLoading({super.key});

  @override
  State<AttendanceStatsSkeletonLoading> createState() =>
      _AttendanceStatsSkeletonLoadingState();
}

class _AttendanceStatsSkeletonLoadingState
    extends State<AttendanceStatsSkeletonLoading>
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
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Circular rate chart skeleton
              _SkeletonBox(
                width: double.infinity,
                height: 200,
                color: animatedColor,
                opacity: pulse,
                radius: 20,
              ),
              const SizedBox(height: 15),
              // Summary stats row
              Row(
                children: [
                  Expanded(
                    child: _SkeletonStatCard(
                      color: animatedColor,
                      opacity: pulse,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SkeletonStatCard(
                      color: animatedColor,
                      opacity: pulse,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SkeletonStatCard(
                      color: animatedColor,
                      opacity: pulse,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Monthly trend section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SkeletonBox(
                          width: 120,
                          height: 16,
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
                    const SizedBox(height: 20),
                    // Bar chart skeleton
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(
                        6,
                        (index) => Column(
                          children: [
                            Container(
                              width: 30,
                              height: 60 + (index * 20).toDouble(),
                              decoration: BoxDecoration(
                                color: animatedColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _SkeletonBox(
                              width: 30,
                              height: 12,
                              color: animatedColor,
                              opacity: pulse,
                              radius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Shift filter row
              Row(
                children: [
                  _SkeletonBox(
                    width: 80,
                    height: 40,
                    color: animatedColor,
                    opacity: pulse,
                    radius: 25,
                  ),
                  const SizedBox(width: 10),
                  _SkeletonBox(
                    width: 60,
                    height: 40,
                    color: animatedColor,
                    opacity: pulse,
                    radius: 25,
                  ),
                  const SizedBox(width: 10),
                  _SkeletonBox(
                    width: 80,
                    height: 40,
                    color: animatedColor,
                    opacity: pulse,
                    radius: 25,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // History section header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _SkeletonBox(
                    width: 140,
                    height: 16,
                    color: animatedColor,
                    opacity: pulse,
                    radius: 8,
                  ),
                  _SkeletonBox(
                    width: 120,
                    height: 12,
                    color: animatedColor,
                    opacity: pulse,
                    radius: 8,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Attendance history list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 5,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SkeletonHistoryItem(
                      color: animatedColor,
                      opacity: pulse,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}

class _SkeletonStatCard extends StatelessWidget {
  final Color color;
  final double opacity;

  const _SkeletonStatCard({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          _SkeletonCircle(size: 24, color: color, opacity: opacity),
          const SizedBox(height: 8),
          _SkeletonBox(
            width: 50,
            height: 12,
            color: color,
            opacity: opacity,
            radius: 6,
          ),
          const SizedBox(height: 8),
          _SkeletonBox(
            width: 40,
            height: 16,
            color: color,
            opacity: opacity,
            radius: 6,
          ),
        ],
      ),
    );
  }
}

class _SkeletonHistoryItem extends StatelessWidget {
  final Color color;
  final double opacity;

  const _SkeletonHistoryItem({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(
                width: 80,
                height: 14,
                color: color,
                opacity: opacity,
                radius: 7,
              ),
              const SizedBox(height: 8),
              _SkeletonBox(
                width: 60,
                height: 12,
                color: color,
                opacity: opacity,
                radius: 6,
              ),
            ],
          ),
          _SkeletonBox(
            width: 80,
            height: 32,
            color: color,
            opacity: opacity,
            radius: 20,
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
