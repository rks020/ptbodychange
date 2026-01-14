import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;
  final VoidCallback? onTap;
  final String? backgroundImage;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
    this.onTap,
    this.backgroundImage,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: EdgeInsets.zero, // Padding handled inside content
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          if (backgroundImage != null)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: backgroundImage!.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: backgroundImage!,
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.6),
                        colorBlendMode: BlendMode.darken,
                      )
                    : Image.asset(
                        backgroundImage!,
                        fit: BoxFit.cover,
                        color: Colors.black.withOpacity(0.6),
                        colorBlendMode: BlendMode.darken,
                      ),
              ),
            ),
          
          // Gradient Overlay (Extra readability)
          if (backgroundImage != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: backgroundImage != null 
                            ? Colors.black.withOpacity(0.4) 
                            : color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        color: backgroundImage != null ? Colors.white : color,
                        size: 20,
                      ),
                    ),
                    if (subtitle != null)
                      Flexible(
                        child: Text(
                          subtitle!,
                          style: AppTextStyles.caption2.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  style: AppTextStyles.caption1.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AppTextStyles.title2.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
