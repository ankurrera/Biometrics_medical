import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class VitalsSummaryCard extends StatelessWidget {
  const VitalsSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Patient Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMain,
                ),
              ),
              Text(
                'See All',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.softPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildVitalChip(
              context,
              label: 'Heart Rate',
              value: '72',
              unit: 'bpm',
              icon: Icons.favorite_rounded,
              color: const Color(0xFFF472B6), // Pink 400
              bgColor: AppColors.softPink,
            ),
            const SizedBox(width: 12),
            _buildVitalChip(
              context,
              label: 'Blood Pressure',
              value: '120/80',
              unit: '',
              icon: Icons.water_drop_rounded,
              color: const Color(0xFFA78BFA), // Purple 400
              bgColor: AppColors.softPurple,
            ),
            const SizedBox(width: 12),
            _buildVitalChip(
              context,
              label: 'Weight',
              value: '70.5',
              unit: 'kg',
              icon: Icons.monitor_weight_rounded,
              color: const Color(0xFF60A5FA), // Blue 400
              bgColor: AppColors.softBlue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalChip(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(24),
          // No shadow, flat pastel look like reference
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMain.withValues(alpha: 0.7),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18, // Large number
                fontWeight: FontWeight.w800,
                color: AppColors.textMain,
                letterSpacing: -0.5,
              ),
            ),
             if (unit.isNotEmpty)
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMain.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
