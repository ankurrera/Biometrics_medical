import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/patient_provider.dart';
import '../../models/prescription.dart'; 

class DailyMedicationSchedule extends ConsumerWidget {
  const DailyMedicationSchedule({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prescriptionsAsync = ref.watch(patientPrescriptionsProvider);

    return prescriptionsAsync.when(
      data: (prescriptions) {
        final activeMeds = prescriptions.where((p) {
          return p.validUntil?.isAfter(DateTime.now()) ?? true; 
        }).toList();

        if (activeMeds.isEmpty) return _buildEmptyState(context);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Schedule",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMain,
                    ),
                  ),
                  Icon(Icons.calendar_today_rounded, 
                      size: 18, color: AppColors.textSub),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: activeMeds.length > 3 ? 3 : activeMeds.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final prescription = activeMeds[index];
                if (prescription.items.isEmpty) return const SizedBox.shrink();
                
                return Column(
                  children: prescription.items.map((item) => _MedicationTimelineItem(
                    medicineName: item.medicineName,
                    dosage: item.dosage,
                    frequency: item.frequency,
                    timeSlot: _inferTimeSlot(item.frequency), 
                    time: _inferTime(item.frequency),
                  )).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: CircularProgressIndicator(),
      )),
      error: (err, _) => const SizedBox.shrink(),
    );
  }

  String _inferTimeSlot(String frequency) {
    if (frequency.contains('1-0-0')) return 'Morning';
    if (frequency.contains('0-1-0')) return 'Afternoon';
    if (frequency.contains('0-0-1')) return 'Evening';
    return 'Daily';
  }

  String _inferTime(String frequency) {
    if (frequency.contains('1-0-0')) return '08:00 AM';
    if (frequency.contains('0-1-0')) return '02:00 PM';
    if (frequency.contains('0-0-1')) return '09:00 PM';
    if (frequency.contains('0-0-1')) return '09:00 PM';
    return 'All Day';
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSoft.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'No medications scheduled.',
          style: TextStyle(color: AppColors.textSub),
        ),
      ),
    );
  }
}

class _MedicationTimelineItem extends StatelessWidget {
  final String medicineName;
  final String dosage;
  final String frequency;
  final String timeSlot;
  final String time;

  const _MedicationTimelineItem({
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.timeSlot,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Column
        Container(
          width: 50,
          padding: const EdgeInsets.only(top: 12),
          child: Column(
            children: [
              Text(
                time.split(' ')[0],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textMain,
                ),
              ),
              Text(
                time.contains(' ') ? time.split(' ')[1] : '',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 10,
                  color: AppColors.textSub,
                ),
              ),
            ],
          ),
        ),
        
        // Card
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 4), // Spacing
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowSoft.withValues(alpha: 0.6), // Soft shadow
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.softYellow, // Pastel Yellow for pills
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.medication_rounded, 
                        color: Colors.orangeAccent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medicineName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textMain,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$dosage • $timeSlot',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Checkbox/Status (Static for UI demo)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderSoft, width: 2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
