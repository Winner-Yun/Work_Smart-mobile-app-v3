import 'package:flutter/material.dart';
import 'package:flutter_worksmart_app/core/constants/appcolor.dart';

class DataEmptyState extends StatelessWidget {
  final String message;
  final String? imageAsset;
  final IconData? icon;
  final Color? iconColor;
  final double imageWidthFactor;
  final double iconSize;
  final double spacing;
  final TextStyle? textStyle;
  final Axis axis;

  const DataEmptyState({
    super.key,
    required this.message,
    this.imageAsset,
    this.icon,
    this.iconColor,
    this.imageWidthFactor = 0.6,
    this.iconSize = 80,
    this.spacing = 20,
    this.textStyle,
    this.axis = Axis.vertical,
  }) : assert(
         imageAsset != null || icon != null,
         'Provide either imageAsset or icon for DataEmptyState.',
       );

  @override
  Widget build(BuildContext context) {
    final Widget visual = imageAsset != null
        ? Image.asset(
            imageAsset!,
            width: MediaQuery.of(context).size.width * imageWidthFactor,
            fit: BoxFit.contain,
          )
        : Icon(icon, size: iconSize, color: iconColor ?? Colors.grey);

    final Widget label = Text(
      message,
      style:
          textStyle ?? const TextStyle(color: AppColors.textGrey, fontSize: 16),
    );

    return Center(
      child: axis == Axis.horizontal
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                visual,
                SizedBox(width: spacing),
                label,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                visual,
                SizedBox(height: spacing),
                label,
              ],
            ),
    );
  }
}
