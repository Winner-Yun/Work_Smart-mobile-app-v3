import 'package:flutter/material.dart';

class HomePageSkeletonLoading extends StatefulWidget {
  const HomePageSkeletonLoading({super.key});

  @override
  State<HomePageSkeletonLoading> createState() =>
      _HomePageSkeletonLoadingState();
}

class _HomePageSkeletonLoadingState extends State<HomePageSkeletonLoading>
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
    final Color baseColor = Theme.of(context).cardTheme.color ?? Colors.white;
    final Color shimmerColor = Theme.of(context).dividerColor.withOpacity(0.45);
    final Color dimmedColor = shimmerColor.withOpacity(0.3);
    final Color brightColor = shimmerColor.withOpacity(0.75);

    return SafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double pulse = 0.45 + (_controller.value * 0.35);
            final Color animatedColor =
                Color.lerp(dimmedColor, brightColor, _controller.value) ??
                shimmerColor;

            return CustomScrollView(
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  automaticallyImplyLeading: false,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  toolbarHeight: 80,
                  titleSpacing: 20,
                  title: Row(
                    children: [
                      _SkeletonCircle(
                        size: 40,
                        color: animatedColor,
                        opacity: pulse,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SkeletonBox(
                              width: 50,
                              height: 10,
                              color: animatedColor,
                              opacity: pulse,
                              radius: 8,
                            ),
                            const SizedBox(height: 8),
                            _SkeletonBox(
                              width: 120,
                              height: 16,
                              color: animatedColor,
                              opacity: pulse,
                              radius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: _SkeletonCircle(
                        size: 36,
                        color: animatedColor,
                        opacity: pulse,
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBox(
                          width: double.infinity,
                          height: 120,
                          color: animatedColor,
                          opacity: pulse,
                          radius: 20,
                        ),
                        const SizedBox(height: 10),
                        _SkeletonDateAndStatusRow(
                          shimmerColor: animatedColor,
                          pulse: pulse,
                        ),

                        const SizedBox(height: 20),
                        _SkeletonTimeRow(
                          color: baseColor,
                          shimmerColor: animatedColor,
                          opacity: pulse,
                        ),
                        const SizedBox(height: 20),
                        _SkeletonMainActionCard(
                          cardColor: baseColor,
                          shimmerColor: animatedColor,
                          pulse: pulse,
                        ),
                        const SizedBox(height: 20),
                        _SkeletonBox(
                          width: 160,
                          height: 18,
                          color: animatedColor,
                          opacity: pulse,
                          radius: 10,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _SkeletonLeaveCard(
                                color: baseColor,
                                shimmerColor: animatedColor,
                                opacity: pulse,
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: _SkeletonLeaveCard(
                                color: baseColor,
                                shimmerColor: animatedColor,
                                opacity: pulse,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SkeletonDateAndStatusRow extends StatelessWidget {
  final Color shimmerColor;
  final double pulse;

  const _SkeletonDateAndStatusRow({
    required this.shimmerColor,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SkeletonBox(
            width: double.infinity,
            height: 14,
            color: shimmerColor,
            opacity: pulse,
            radius: 8,
          ),
        ),
        const SizedBox(width: 10),
        _SkeletonBox(
          width: 100,
          height: 26,
          color: shimmerColor,
          opacity: pulse,
          radius: 20,
        ),
      ],
    );
  }
}

class _SkeletonTimeRow extends StatelessWidget {
  final Color color;
  final Color shimmerColor;
  final double opacity;

  const _SkeletonTimeRow({
    required this.color,
    required this.shimmerColor,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildTimeCardPlaceholder(color, shimmerColor, opacity),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTimeCardPlaceholder(color, shimmerColor, opacity),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTimeCardPlaceholder(color, shimmerColor, opacity),
        ),
      ],
    );
  }

  Widget _buildTimeCardPlaceholder(
    Color color,
    Color shimmerColor,
    double opacity,
  ) {
    return Container(
      height: 110,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonCircle(size: 18, color: shimmerColor, opacity: opacity),
              const SizedBox(width: 6),
              Expanded(
                child: _SkeletonBox(
                  width: double.infinity,
                  height: 10,
                  color: shimmerColor,
                  opacity: opacity,
                  radius: 8,
                ),
              ),
            ],
          ),
          _SkeletonBox(
            width: double.infinity,
            height: 18,
            color: shimmerColor,
            opacity: opacity,
            radius: 8,
          ),
        ],
      ),
    );
  }
}

class _SkeletonMainActionCard extends StatelessWidget {
  final Color cardColor;
  final Color shimmerColor;
  final double pulse;

  const _SkeletonMainActionCard({
    required this.cardColor,
    required this.shimmerColor,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: Container(
                    color: shimmerColor.withOpacity(0.25),
                    width: double.infinity,
                    height: double.infinity,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Opacity(
                            opacity: 0.45,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    shimmerColor.withOpacity(0.18),
                                    shimmerColor.withOpacity(0.05),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          left: 16,
                          child: _SkeletonBox(
                            width: 90,
                            height: 28,
                            color:
                                Theme.of(context).cardTheme.color ??
                                Colors.white,
                            opacity: pulse,
                            radius: 20,
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).cardTheme.color ??
                                  Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _SkeletonCircle(
                                  size: 14,
                                  color: shimmerColor,
                                  opacity: pulse,
                                ),
                                const SizedBox(width: 6),
                                _SkeletonBox(
                                  width: 72,
                                  height: 12,
                                  color: shimmerColor,
                                  opacity: pulse,
                                  radius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.04),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonBox(
                            width: 64,
                            height: 10,
                            color: shimmerColor,
                            opacity: pulse,
                            radius: 8,
                          ),
                          const SizedBox(height: 12),
                          _SkeletonBox(
                            width: 120,
                            height: 16,
                            color: shimmerColor,
                            opacity: pulse,
                            radius: 8,
                          ),
                          const SizedBox(height: 10),
                          _SkeletonBox(
                            width: 84,
                            height: 10,
                            color: shimmerColor,
                            opacity: pulse,
                            radius: 8,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _SkeletonBox(
                            width: 54,
                            height: 10,
                            color: shimmerColor,
                            opacity: pulse,
                            radius: 8,
                          ),
                          const SizedBox(height: 12),
                          _SkeletonBox(
                            width: 70,
                            height: 16,
                            color: shimmerColor,
                            opacity: pulse,
                            radius: 8,
                          ),
                          const SizedBox(height: 10),
                          _SkeletonBox(
                            width: 100,
                            height: 36,
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.25),
                            opacity: pulse,
                            radius: 10,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _SkeletonBox(
                  width: double.infinity,
                  height: 55,
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withOpacity(0.22),
                  opacity: pulse,
                  radius: 16,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLeaveCard extends StatelessWidget {
  final Color color;
  final Color shimmerColor;
  final double opacity;

  const _SkeletonLeaveCard({
    required this.color,
    required this.shimmerColor,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 128,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SkeletonCircle(size: 28, color: shimmerColor, opacity: opacity),
              _SkeletonBox(
                width: 12,
                height: 8,
                color: shimmerColor,
                opacity: opacity,
                radius: 4,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _SkeletonBox(
            width: 70,
            height: 10,
            color: shimmerColor,
            opacity: opacity,
            radius: 8,
          ),
          const SizedBox(height: 8),
          _SkeletonBox(
            width: 36,
            height: 18,
            color: shimmerColor,
            opacity: opacity,
            radius: 8,
          ),
          const SizedBox(height: 12),
          _SkeletonBox(
            width: double.infinity,
            height: 4,
            color: shimmerColor,
            opacity: opacity,
            radius: 4,
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
