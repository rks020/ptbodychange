import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import '../../core/theme/colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final BoxBorder? border;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.borderRadius,
    this.border,
    this.margin,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // Android Optimization: Disable blur for performance
    final isAndroid = Platform.isAndroid;

    final innerChild = Container(
      width: width,
      height: height,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isAndroid 
            ? (backgroundColor ?? const Color(0xFF1E1E1E).withOpacity(0.95))
            : (backgroundColor ?? AppColors.glassBackground),
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: border ?? Border.all(
          color: AppColors.glassBorder,
          width: 1,
        ),
      ),
      child: child,
    );

    final content = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      child: isAndroid
          ? innerChild
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: innerChild,
            ),
    );

    if (margin != null) {
      return Padding(
        padding: margin!,
        child: onTap != null
            ? Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: borderRadius ?? BorderRadius.circular(16),
                  child: content,
                ),
              )
            : content,
      );
    }

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius ?? BorderRadius.circular(16),
          child: content,
        ),
      );
    }

    return content;
  }
}
