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
            children: [
              const SizedBox(height: 20),
              // Avatar skeleton
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    _SkeletonCircle(
                      size: 120,
                      color: animatedColor,
                      opacity: pulse,
                    ),
                    _SkeletonCircle(
                      size: 36,
                      color: animatedColor,
                      opacity: pulse,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 15),
              // Name skeleton
              _SkeletonBox(
                width: 160,
                height: 22,
                color: animatedColor,
                opacity: pulse,
                radius: 8,
              ),
              const SizedBox(height: 8),
              // Role title skeleton
              _SkeletonBox(
                width: 120,
                height: 14,
                color: animatedColor,
                opacity: pulse,
                radius: 8,
              ),
              const SizedBox(height: 30),
              // Info card skeleton
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Office row
                    _buildInfoRowSkeleton(animatedColor, pulse),
                    const Divider(height: 30, thickness: 0.5),
                    // Department row
                    _buildInfoRowSkeleton(animatedColor, pulse),
                    const Divider(height: 30, thickness: 0.5),
                    // Email row
                    _buildInfoRowSkeleton(animatedColor, pulse),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Change password action tile
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.01),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _SkeletonCircle(
                      size: 24,
                      color: animatedColor,
                      opacity: pulse,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: _SkeletonBox(
                        width: 120,
                        height: 14,
                        color: animatedColor,
                        opacity: pulse,
                        radius: 7,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              // Logout button skeleton
              _SkeletonBox(
                width: double.infinity,
                height: 55,
                color: animatedColor,
                opacity: pulse,
                radius: 15,
              ),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRowSkeleton(Color color, double opacity) {
    return Row(
      children: [
        _SkeletonCircle(size: 40, color: color, opacity: opacity),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonBox(
                width: 60,
                height: 12,
                color: color,
                opacity: opacity,
                radius: 6,
              ),
              const SizedBox(height: 8),
              _SkeletonBox(
                width: double.infinity,
                height: 14,
                color: color,
                opacity: opacity,
                radius: 7,
              ),
            ],
          ),
        ),
      ],
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
