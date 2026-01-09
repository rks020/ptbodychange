import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/class_session.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../widgets/conflict_warning_dialog.dart';

class CreateScheduleScreen extends StatefulWidget {
  final Member member;

  const CreateScheduleScreen({super.key, required this.member});

  @override
  State<CreateScheduleScreen> createState() => _CreateScheduleScreenState();
}

class _CreateScheduleScreenState extends State<CreateScheduleScreen> {
  final _repository = ClassRepository();
  bool _isLoading = false;

  late DateTime _startDate;
  late DateTime _endDate;
  final Set<int> _selectedDays = {}; // 1 = Mon, 7 = Sun
  final Map<int, TimeOfDay> _dayTimes = {};
  int _durationMinutes = 60;
  final _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = now.add(const Duration(days: 30));
    _titleController.text = '${widget.member.name} PT Seansı';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createSchedule() async {
    if (_selectedDays.isEmpty) {
      CustomSnackBar.showError(context, 'Lütfen en az bir gün seçin');
      return;
    }

    setState(() => _isLoading = true);
    int createdCount = 0;
    int conflictCount = 0;
    int trainerConflicts = 0;
    int memberConflicts = 0;
    bool userCancelled = false;

    try {
      final int remainingRights = widget.member.sessionCount ?? 0;
      if (remainingRights <= 0) {
        CustomSnackBar.showError(context, 'Üyenin ders hakkı bulunmamaktadır.');
        setState(() => _isLoading = false);
        return;
      }

      // Loop through dates
      for (var d = _startDate;
          d.isBefore(_endDate.add(const Duration(days: 1)));
          d = d.add(const Duration(days: 1))) {
        
        if (createdCount >= remainingRights) break; // Enforce limit

        if (_selectedDays.contains(d.weekday)) {
          // Get specific time for this day, default to 10:00 if missing
          final time = _dayTimes[d.weekday] ?? const TimeOfDay(hour: 10, minute: 0);

          // Construct Session
          final startDateTime = DateTime(d.year, d.month, d.day, time.hour, time.minute);
          
          // if (startDateTime.isBefore(DateTime.now())) continue; // Allow past times for today

          final endDateTime = startDateTime.add(Duration(minutes: _durationMinutes));

          // Check conflict with details
          final currentTrainerId = Supabase.instance.client.auth.currentUser?.id;
          final conflicts = await _repository.findConflictsWithDetails(
            startDateTime,
            endDateTime,
            excludeTrainerId: currentTrainerId,
          );

          if (conflicts.isNotEmpty) {
            // Check if member has conflicting enrollment
            bool hasMemberConflict = false;
            for (final conflict in conflicts) {
              final enrollments = conflict['class_enrollments'] as List<dynamic>? ?? [];
              for (final enrollment in enrollments) {
                if (enrollment['member_id'] == widget.member.id) {
                  hasMemberConflict = true;
                  break;
                }
              }
              if (hasMemberConflict) break;
            }

            if (hasMemberConflict) {
              memberConflicts++;
            } else {
              trainerConflicts++;
            }

            // Find smart alternative
            DateTime? alternativeStart;
            DateTime? alternativeEnd;
            try {
              alternativeStart = await _repository.findNextAvailableSlot(
                startDateTime, 
                _durationMinutes
              );
              if (alternativeStart != null) {
                alternativeEnd = alternativeStart.add(Duration(minutes: _durationMinutes));
              }
            } catch (_) {}

            // Show conflict dialog with alternative
            final action = await showDialog<ConflictAction>(
              context: context,
              builder: (context) => ConflictWarningDialog(
                conflicts: conflicts,
                proposedStartTime: startDateTime,
                proposedEndTime: endDateTime,
                alternativeStartTime: alternativeStart,
                alternativeEndTime: alternativeEnd,
              ),
            );

            if (action == ConflictAction.acceptAlternative && alternativeStart != null) {
               // Update time for this day to the alternative time
               if (mounted) {
                 final newTime = TimeOfDay.fromDateTime(alternativeStart);
                 setState(() {
                   _dayTimes[d.weekday] = newTime;
                 });
                 // Retry with new time - go back one day to reprocess
                 d = d.subtract(const Duration(days: 1));
                 continue;
               }
            } else if (action == ConflictAction.modifyTime) {
              // Show time picker for this day
              if (mounted) {
                final newTime = await showTimePicker(
                  context: context,
                  initialTime: time,
                );
                if (newTime != null) {
                  setState(() {
                    _dayTimes[d.weekday] = newTime;
                  });
                  // Retry with new time - go back one day to reprocess
                  d = d.subtract(const Duration(days: 1));
                  continue;
                }
              }
            } else if (action == ConflictAction.cancel) {
              userCancelled = true;
              break;
            }
            // If skip, just continue to next iteration
            conflictCount++;
            continue;
          }

          // Create
          final session = ClassSession(
            title: _titleController.text,
            startTime: startDateTime,
            endTime: endDateTime,
            capacity: 1, // Private session
            trainerId: Supabase.instance.client.auth.currentUser?.id,
          );

          final createdSession = await _repository.createSession(session);
          
          if (createdSession.id != null) {
            await _repository.enrollMember(createdSession.id!, widget.member.id);
            // Schedule Notification to 5 minutes before
            // Use hashCode of session ID string as notification ID (simple way)
            await NotificationService().scheduleClassReminder(
              createdSession.id.hashCode,
              _titleController.text,
              createdSession.startTime,
            );
          }
          
          createdCount++;
        }
      }

      if (mounted) {
        if (userCancelled) {
          CustomSnackBar.showWarning(context, 'Program oluşturma iptal edildi.');
        } else if (createdCount > 0) {
          String msg = '$createdCount ders oluşturuldu.';
          if (createdCount >= remainingRights) {
            msg += ' (Paket limiti doldu)';
          } else if (conflictCount > 0) {
            List<String> conflicts = [];
            if (trainerConflicts > 0) conflicts.add('$trainerConflicts antrenör');
            if (memberConflicts > 0) conflicts.add('$memberConflicts üye');
            msg += ' (${conflicts.join(", ")} çakışması atlandı)';
          }
          CustomSnackBar.showSuccess(context, msg);
          Navigator.pop(context, true);
        } else {
          CustomSnackBar.showError(context, 'Ders oluşturulamadı. (Çakışma veya geçmiş tarih)');
        }
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Hata yakalandı: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Program Oluştur'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryYellow),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Öğrenci: ${widget.member.name}', style: AppTextStyles.headline),
            const SizedBox(height: 24),

             // Days Selector
            Text('Günler', style: AppTextStyles.title3.copyWith(color: AppColors.primaryYellow)),
            const SizedBox(height: 12),
            GlassCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final dayIndex = index + 1; // 1=Mon
                  final isSelected = _selectedDays.contains(dayIndex);
                  final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                  return FilterChip(
                    label: Text(dayNames[index]),
                    selected: isSelected,
                    selectedColor: AppColors.primaryYellow,
                    checkmarkColor: Colors.black,
                     labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedDays.add(dayIndex);
                          // Default to 10:00 or copy generic time
                          if (!_dayTimes.containsKey(dayIndex)) {
                             // Use current time if today is selected
                             if (dayIndex == DateTime.now().weekday) {
                               _dayTimes[dayIndex] = TimeOfDay.now();
                             } else {
                               _dayTimes[dayIndex] = const TimeOfDay(hour: 10, minute: 0);
                             }
                          }
                        } else {
                          _selectedDays.remove(dayIndex);
                        }
                      });
                    },
                    backgroundColor: AppColors.surfaceDark,
                  );
                }),
              ),
            ),

            const SizedBox(height: 24),

            // Date Range
            Text('Tarih Aralığı', style: AppTextStyles.title3.copyWith(color: AppColors.primaryYellow)),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  _buildDateRow('Başlangıç', _startDate, (d) => setState(() => _startDate = d)),
                  const Divider(color: AppColors.glassBorder),
                  _buildDateRow('Bitiş', _endDate, (d) => setState(() => _endDate = d)),
                ],
              ),
            ),

            const SizedBox(height: 24),
            
            // Time & Duration
             Text('Saat & Süre', style: AppTextStyles.title3.copyWith(color: AppColors.primaryYellow)),
             const SizedBox(height: 12),
             GlassCard(
               child: Column(
                 children: [
                   ListTile(
                     title: Text('Süre (dk)', style: AppTextStyles.body),
                     trailing: DropdownButton<int>(
                       value: _durationMinutes,
                       dropdownColor: AppColors.cardDark,
                       underline: const SizedBox(),
                       items: [30, 45, 60, 90].map((e) => DropdownMenuItem(value: e, child: Text('$e'))).toList(),
                       onChanged: (v) => setState(() => _durationMinutes = v!),
                       style: AppTextStyles.headline,
                     ),
                   ),
                   if (_selectedDays.isNotEmpty) ...[
                      const Divider(color: AppColors.glassBorder),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text("Ders Saatleri", style: AppTextStyles.subheadline),
                      ),
                      ..._selectedDays.map((dayIndex) {
                        final dayNames = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                        final time = _dayTimes[dayIndex] ?? const TimeOfDay(hour: 10, minute: 0);
                        return ListTile(
                          dense: true,
                          title: Text(dayNames[dayIndex - 1], style: AppTextStyles.body),
                          trailing: Text(time.format(context), style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow)),
                          onTap: () async {
                            final t = await showTimePicker(context: context, initialTime: time);
                            if (t != null) {
                              setState(() {
                                _dayTimes[dayIndex] = t;
                              });
                            }
                          },
                        );
                      }).toList(),
                   ] else ...[
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text("Lütfen gün seçiniz.", style: TextStyle(color: Colors.white54)),
                      )
                   ]
                 ],
               ),
             ),

            const SizedBox(height: 32),
            CustomButton(
              text: 'Programı Oluştur',
              onPressed: _createSchedule,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow(String label, DateTime date, Function(DateTime) onChanged) {
    return ListTile(
      title: Text(label, style: AppTextStyles.body),
      trailing: Text(DateFormat('dd.MM.yyyy').format(date), style: AppTextStyles.headline),
      onTap: () async {
        final d = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
           builder: (context, child) => Theme(data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: AppColors.primaryYellow, surface: AppColors.surfaceDark)), child: child!),
        );
        if (d != null) onChanged(d);
      },
    );
  }
}
