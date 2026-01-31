import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class CustomTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;

  const CustomTimePicker({
    super.key,
    required this.initialTime,
  });

  @override
  State<CustomTimePicker> createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<CustomTimePicker> {
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;
  late int _selectedHour;
  late int _selectedMinute;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(initialItem: _selectedHour);
    _minuteController = FixedExtentScrollController(initialItem: _selectedMinute ~/ 5);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              'Uhrzeit auswählen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),

            // Time picker
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // Hours
                  Expanded(
                    child: ListWheelScrollView(
                      controller: _hourController,
                      itemExtent: 50,
                      diameterRatio: 1.5,
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedHour = index);
                      },
                      children: List.generate(
                        24,
                        (index) => Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: index == _selectedHour
                                  ? AppColors.primaryButtonBackground
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Divider
                  Text(
                    ':',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.primaryButtonBackground,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  // Minutes
                  Expanded(
                    child: ListWheelScrollView(
                      controller: _minuteController,
                      itemExtent: 50,
                      diameterRatio: 1.5,
                      onSelectedItemChanged: (index) {
                        setState(() => _selectedMinute = index * 5);
                      },
                      children: List.generate(
                        12,
                        (index) => Center(
                          child: Text(
                            (index * 5).toString().padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: index * 5 == _selectedMinute
                                  ? AppColors.primaryButtonBackground
                                  : Colors.grey[400],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Selected time display
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.primaryButtonBackground.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.primaryButtonBackground,
                  width: 1,
                ),
              ),
              child: Text(
                '${_selectedHour.toString().padLeft(2, '0')}:${_selectedMinute.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryButtonBackground,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abbrechen'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryButtonBackground,
                    foregroundColor: AppColors.primaryButtonForeground,
                  ),
                  onPressed: () {
                    final selectedTime = TimeOfDay(
                      hour: _selectedHour,
                      minute: _selectedMinute,
                    );
                    Navigator.pop(context, selectedTime);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
