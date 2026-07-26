import 'package:flutter/material.dart';

class ProfileSkeletonLoading extends StatefulWidget {
  const ProfileSkeletonLoading({super.key});

  @override
  State<ProfileSkeletonLoading> createState() => _ProfileSkeletonLoadingState();
}

class _ProfileSkeletonLoadingState extends State<ProfileSkeletonLoading>
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
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              // Profile header card skeleton
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            _SkeletonCircle(
                              size: 76,
                              color: animatedColor,
                              opacity: pulse,
                            ),
                            _SkeletonCircle(
                              size: 22,
                              color: animatedColor,
                              opacity: pulse,
                            ),
                          ],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SkeletonBox(
                                width: 140,
                                height: 18,
                                color: animatedColor,
                                opacity: pulse,
                                radius: 8,
                              ),
                              const SizedBox(height: 8),
                              _SkeletonBox(
                                width: 100,
                                height: 13,
                                color: animatedColor,
                                opacity: pulse,
                                radius: 7,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Divider(
                      height: 1,
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                    const SizedBox(height: 14),
                    _buildContactLineSkeleton(animatedColor, pulse, 180),
                    const SizedBox(height: 12),
                    _buildContactLineSkeleton(animatedColor, pulse, 120),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              // "General" section
              _SkeletonBox(
                width: 90,
                height: 12,
                color: animatedColor,
                opacity: pulse,
                radius: 6,
              ),
              const SizedBox(height: 10),
              _buildGroupSkeleton(animatedColor, pulse, rows: 3, trailingIsSwitch: true),
              const SizedBox(height: 22),
              // "Support" section
              _SkeletonBox(
                width: 90,
                height: 12,
                color: animatedColor,
                opacity: pulse,
                radius: 6,
              ),
              const SizedBox(height: 10),
              _buildGroupSkeleton(animatedColor, pulse, rows: 4, trailingIsSwitch: false),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactLineSkeleton(Color color, double opacity, double width) {
    return Row(
      children: [
        Opacity(
          opacity: opacity,
          child: Icon(Icons.circle, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        _SkeletonBox(
          width: width,
          height: 14,
          color: color,
          opacity: opacity,
          radius: 7,
        ),
      ],
    );
  }

  Widget _buildGroupSkeleton(
    Color color,
    double opacity, {
    required int rows,
    required bool trailingIsSwitch,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12),
        ],
      ),
      child: Column(
        children: List.generate(rows, (index) {
          final bool isLast = index == rows - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    _SkeletonBox(
                      width: 40,
                      height: 40,
                      color: color,
                      opacity: opacity,
                      radius: 12,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _SkeletonBox(
                        width: 130,
                        height: 14,
                        color: color,
                        opacity: opacity,
                        radius: 7,
                      ),
                    ),
                    const SizedBox(width: 15),
                    trailingIsSwitch
                        ? _SkeletonBox(
                            width: 40,
                            height: 22,
                            color: color,
                            opacity: opacity,
                            radius: 12,
                          )
                        : _SkeletonBox(
                            width: 16,
                            height: 16,
                            color: color,
                            opacity: opacity,
                            radius: 4,
                          ),
                  ],
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor.withOpacity(0.1),
                  indent: 70,
                  endIndent: 20,
                ),
            ],
          );
        }),
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
