import 'package:flutter/material.dart';

class AppProfileAvatar extends StatelessWidget {
  final String displayName;
  final String imageUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final FontWeight fontWeight;
  final double? fontSize;
  final ImageProvider<Object>? foregroundImage;

  const AppProfileAvatar({
    super.key,
    required this.displayName,
    required this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.fontWeight = FontWeight.w700,
    this.fontSize,
    this.foregroundImage,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = imageUrl.trim();
    final initials = _getInitials(displayName);
    final ImageProvider<Object>? resolvedForegroundImage =
        foregroundImage ??
        (normalizedUrl.isEmpty ? null : NetworkImage(normalizedUrl));

    return CircleAvatar(
      radius: radius,
      backgroundColor:
          backgroundColor ??
          Theme.of(context).colorScheme.primary.withOpacity(0.12),
      foregroundImage: resolvedForegroundImage,
      child: Text(
        initials,
        style: TextStyle(
          color: textColor ?? Theme.of(context).colorScheme.primary,
          fontWeight: fontWeight,
          fontSize: fontSize ?? (radius * 0.48),
        ),
      ),
    );
  }

  String _getInitials(String fullName) {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
        .toUpperCase();
  }
}
