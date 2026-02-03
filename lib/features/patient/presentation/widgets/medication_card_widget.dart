import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../models/prescription_input_models.dart';

/// Reusable medication card for entering medication details
class MedicationCardWidget extends StatefulWidget {
  final int index;
  final VoidCallback onRemove;
  final Function(MedicationDetails) onChanged;
  final MedicationDetails? initialData;

  const MedicationCardWidget({
    super.key,
    required this.index,
    required this.onRemove,
    required this.onChanged,
    this.initialData,
  });

  @override
  State<MedicationCardWidget> createState() => _MedicationCardWidgetState();
}

class _MedicationCardWidgetState extends State<MedicationCardWidget> {
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _durationController;
  late final TextEditingController _quantityController;
  late final TextEditingController _instructionsController;

  String? _selectedFrequency;
  MedicineType? _medicineType;
  RouteOfAdministration? _route;
  FoodTiming? _foodTiming;

  // Frequency mapping for auto-calculation
  // All frequencies are daily-based (times per day)
  static const Map<String, int> frequencyMap = {
    "Once a day": 1,
    "Twice a day": 2,
    "Thrice a day": 3,
    "Four times a day": 4,
    "Every 8 hours": 3,
    "Every 12 hours": 2,
  };

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData?.medicineName);
    _dosageController = TextEditingController(text: widget.initialData?.dosage);
    _selectedFrequency = widget.initialData?.frequency;
    _durationController = TextEditingController(text: widget.initialData?.duration);
    _quantityController = TextEditingController(
      text: (widget.initialData?.quantity ?? 0) > 0 
          ? widget.initialData!.quantity.toString() 
          : '',
    );
    _instructionsController = TextEditingController(text: widget.initialData?.instructions);
    _medicineType = widget.initialData?.medicineType;
    _route = widget.initialData?.route;
    _foodTiming = widget.initialData?.foodTiming;

    // Add listeners to notify parent of changes
    _nameController.addListener(_notifyChange);
    _dosageController.addListener(_notifyChange);
    _durationController.addListener(_calculateQuantity);
    _instructionsController.addListener(_notifyChange);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _durationController.dispose();
    _quantityController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  /// Auto-calculate quantity based on Duration × Frequency
  void _calculateQuantity() {
    if (_durationController.text.isEmpty || _selectedFrequency == null) {
      _quantityController.text = '';
      _notifyChange();
      return;
    }

    // Parse duration as integer (days)
    // Input is numeric-only via FilteringTextInputFormatter
    final int? duration = int.tryParse(_durationController.text.trim());
    
    if (duration == null) {
      _quantityController.text = '';
      _notifyChange();
      return;
    }

    final int frequencyPerDay = frequencyMap[_selectedFrequency] ?? 1;

    final int calculatedQuantity = duration * frequencyPerDay;

    _quantityController.text = calculatedQuantity.toString();
    _notifyChange();
  }

  void _notifyChange() {
    final quantity = int.tryParse(_quantityController.text) ?? 0;
    final medication = MedicationDetails(
      medicineName: _nameController.text,
      dosage: _dosageController.text,
      frequency: _selectedFrequency ?? '',
      duration: _durationController.text,
      quantity: quantity,
      medicineType: _medicineType,
      route: _route,
      foodTiming: _foodTiming,
      instructions: _instructionsController.text.isNotEmpty 
          ? _instructionsController.text 
          : null,
    );
    widget.onChanged(medication);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.pharmacist.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      color: AppColors.pharmacist,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Text(
                'Medication',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.close_rounded, size: 20),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Medicine Name *
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Medicine Name *',
              hintText: 'e.g., Paracetamol',
              prefixIcon: Icon(Icons.medication_outlined, size: 20),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Medicine name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Dosage * and Frequency * (Row)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dosageController,
                  decoration: const InputDecoration(
                    labelText: 'Dosage *',
                    hintText: 'e.g., 500mg',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency *',
                    hintText: 'Select',
                  ),
                  items: frequencyMap.keys.map((frequency) {
                    return DropdownMenuItem(
                      value: frequency,
                      child: Text(frequency),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedFrequency = value);
                    _calculateQuantity();
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Duration * and Quantity * (Row)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Duration (Days) *',
                    hintText: 'e.g., 7',
                    helperText: 'Number of days',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }
                    final days = int.tryParse(value);
                    if (days == null || days <= 0) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Semantics(
                  label: _quantityController.text.isNotEmpty 
                      ? 'Auto-calculated quantity: ${_quantityController.text}'
                      : 'Quantity will be calculated automatically',
                  readOnly: true,
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity *',
                      hintText: 'Auto-calculated',
                      helperText: 'Auto-calculated',
                    ),
                    readOnly: true,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }
                      final qty = int.tryParse(value);
                      if (qty == null || qty <= 0) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Medicine Type * (Required dropdown)
          DropdownButtonFormField<MedicineType>(
            value: _medicineType,
            decoration: const InputDecoration(
              labelText: 'Medicine Type *',
              hintText: 'Select type',
            ),
            items: MedicineType.values.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type.displayName),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _medicineType = value);
              _notifyChange();
            },
            validator: (value) {
              if (value == null) {
                return 'Required';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.sm),

          // Route * and Food Timing * (Row)
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<RouteOfAdministration>(
                  value: _route,
                  decoration: const InputDecoration(
                    labelText: 'Route *',
                    hintText: 'Select',
                  ),
                  items: RouteOfAdministration.values.map((route) {
                    return DropdownMenuItem(
                      value: route,
                      child: Text(route.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _route = value);
                    _notifyChange();
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<FoodTiming>(
                  value: _foodTiming,
                  decoration: const InputDecoration(
                    labelText: 'Food Timing *',
                    hintText: 'Select',
                  ),
                  items: FoodTiming.values.map((timing) {
                    return DropdownMenuItem(
                      value: timing,
                      child: Text(timing.displayName),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _foodTiming = value);
                    _notifyChange();
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Required';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Instructions (Optional)
          TextFormField(
            controller: _instructionsController,
            decoration: const InputDecoration(
              labelText: 'Instructions',
              hintText: 'e.g., Take after meals with water',
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
