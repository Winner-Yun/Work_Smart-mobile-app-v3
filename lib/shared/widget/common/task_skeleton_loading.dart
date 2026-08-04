import 'package:flutter/material.dart';

class TaskSkeletonLoading extends StatefulWidget {
  const TaskSkeletonLoading({super.key});

  @override
  State<TaskSkeletonLoading> createState() => _TaskSkeletonLoadingState();
}

class _TaskSkeletonLoadingState extends State<TaskSkeletonLoading>
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: _SkeletonStatsHeader(
                color: animatedColor,
                opacity: pulse,
                tileCount: 3,
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 6,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _SkeletonTaskItem(
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

class _SkeletonStatsHeader extends StatelessWidget {
  final Color color;
  final double opacity;
  final int tileCount;

  const _SkeletonStatsHeader({
    required this.color,
    required this.opacity,
    required this.tileCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          for (int i = 0; i < tileCount; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 40,
                color: Theme.of(context).dividerColor.withOpacity(0.15),
              ),
            Expanded(
              child: Column(
                children: [
                  _SkeletonBox(
                    width: 28,
                    height: 17,
                    color: color,
                    opacity: opacity,
                    radius: 6,
                  ),
                  const SizedBox(height: 6),
                  _SkeletonBox(
                    width: 44,
                    height: 10,
                    color: color,
                    opacity: opacity,
                    radius: 5,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkeletonTaskItem extends StatelessWidget {
  final Color color;
  final double opacity;

  const _SkeletonTaskItem({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 14),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Opacity(
              opacity: opacity,
              child: Container(
                width: 5,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SkeletonBox(
                  width: 140,
                  height: 15,
                  color: color,
                  opacity: opacity,
                  radius: 7,
                ),
              ),
              const SizedBox(width: 8),
              _SkeletonBox(
                width: 50,
                height: 20,
                color: color,
                opacity: opacity,
                radius: 20,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _SkeletonBox(
            width: double.infinity,
            height: 12,
            color: color,
            opacity: opacity,
            radius: 6,
          ),
          const SizedBox(height: 6),
          _SkeletonBox(
            width: 200,
            height: 12,
            color: color,
            opacity: opacity,
            radius: 6,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SkeletonBox(
                width: 80,
                height: 12,
                color: color,
                opacity: opacity,
                radius: 6,
              ),
              _SkeletonBox(
                width: 70,
                height: 20,
                color: color,
                opacity: opacity,
                radius: 20,
              ),
            ],
          ),
        ],
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
