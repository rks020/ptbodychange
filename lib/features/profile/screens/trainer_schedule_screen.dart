import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/class_session.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../data/models/profile.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/ambient_background.dart';

class TrainerScheduleScreen extends StatefulWidget {
  const TrainerScheduleScreen({super.key});

  @override
  State<TrainerScheduleScreen> createState() => _TrainerScheduleScreenState();
}

class _TrainerScheduleScreenState extends State<TrainerScheduleScreen> {
  final _repository = ClassRepository();
  
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Map of date -> List of sessions
  Map<DateTime, List<ClassSession>> _events = {};
  List<ClassSession> _selectedDaySessions = [];
  bool _isLoading = true;
  Profile? _currentProfile;
  final _profileRepository = ProfileRepository();

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _selectedDay = _focusedDay;
    _loadMonthSessions(_focusedDay);
  }

  Future<void> _loadCurrentUser() async {
    final profile = await _profileRepository.getProfile();
    if (mounted) {
      setState(() => _currentProfile = profile);
    }
  }

  Future<void> _loadMonthSessions(DateTime month) async {
    setState(() => _isLoading = true);

    // Get 1st day of month to last day
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    try {
      final sessions = await _repository.getSessions(firstDay, lastDay);
      
      final newEvents = <DateTime, List<ClassSession>>{};
      
      for (var session in sessions) {
        // Normalize date to remove time for key
        final date = DateTime(
          session.startTime.year, 
          session.startTime.month, 
          session.startTime.day
        );
        
        if (newEvents[date] == null) newEvents[date] = [];
        newEvents[date]!.add(session);
      }

      if (mounted) {
        setState(() {
          _events = newEvents;
          _isLoading = false;
        });
        _updateSelectedDaySessions(_selectedDay!);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSelectedDaySessions(DateTime day) {
    final normalizedDay = DateTime(day.year, day.month, day.day);
    setState(() {
      _selectedDaySessions = _events[normalizedDay] ?? [];
      // Sort by time
      _selectedDaySessions.sort((a, b) => a.startTime.compareTo(b.startTime));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Eğitmen Programı'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
          // Galaxy Calendar
          GlassCard(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.only(bottom: 8),
            child: TableCalendar(
              firstDay: DateTime.utc(2024, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              startingDayOfWeek: StartingDayOfWeek.monday,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) {
                return isSameDay(_selectedDay, day);
              },
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                  _updateSelectedDaySessions(selectedDay);
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _loadMonthSessions(focusedDay);
              },
              eventLoader: (day) {
                final normalizedDay = DateTime(day.year, day.month, day.day);
                return _events[normalizedDay] ?? [];
              },
              locale: 'tr_TR',
              
              // Styling
              headerStyle: HeaderStyle(
                titleCentered: true,
                formatButtonVisible: false,
                titleTextStyle: AppTextStyles.title3.copyWith(fontWeight: FontWeight.bold),
                leftChevronIcon: const Icon(Icons.chevron_left, color: AppColors.primaryYellow),
                rightChevronIcon: const Icon(Icons.chevron_right, color: AppColors.primaryYellow),
              ),
              calendarStyle: CalendarStyle(
                defaultTextStyle: const TextStyle(color: Colors.white),
                weekendTextStyle: const TextStyle(color: AppColors.textSecondary),
                outsideTextStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.5)),
                selectedDecoration: const BoxDecoration(
                  color: AppColors.primaryYellow,
                  shape: BoxShape.circle,
                ),
                selectedTextStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                todayDecoration: BoxDecoration(
                  color: AppColors.primaryYellow.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                markerDecoration: const BoxDecoration(
                  color: AppColors.accentBlue,
                  shape: BoxShape.circle,
                ),
              ),
              daysOfWeekStyle: DaysOfWeekStyle(
                weekdayStyle: const TextStyle(color: AppColors.textSecondary),
                weekendStyle: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),

          const Divider(color: AppColors.glassBorder),
          
          // Event List
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _selectedDaySessions.isEmpty
                  ? Center(
                      child: Text(
                        'Bu tarihte planlanmış ders yok',
                        style: AppTextStyles.caption1,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(20),
                      itemCount: _selectedDaySessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final session = _selectedDaySessions[index];
                        return _buildSessionItem(session);
                      },
                    ),
          ),
        ],
        ),
      ),
      ),
    );
  }

  Widget _buildSessionItem(ClassSession session) {
    return InkWell(
      onTap: () => _showSessionOptions(session),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Time Column
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat('HH:mm').format(session.startTime),
                  style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('HH:mm').format(session.endTime),
                  style: AppTextStyles.caption2,
                ),
              ],
            ),
            Container(
              height: 40,
              width: 1,
              color: AppColors.glassBorder,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: AppColors.accentBlue),
                      const SizedBox(width: 4),
                      Text(
                        'PT: ${session.trainerName ?? "-"}',
                        style: AppTextStyles.caption1.copyWith(color: AppColors.accentBlue),
                      ),
                    ],
                  ),
                  if (session.status == 'completed') ...[
                     const SizedBox(height: 4),
                     Row(
                      children: [
                        const Icon(Icons.check_circle_outline, size: 14, color: AppColors.accentGreen),
                        const SizedBox(width: 4),
                         Text(
                          'Tamamlandı',
                          style: AppTextStyles.caption2.copyWith(color: AppColors.accentGreen),
                        ),
                      ],
                     ),
                  ]
                ],
              ),
            ),
            // Edit Indicator (only if allowed)
            if (_canEdit(session))
              const Icon(Icons.more_vert, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  bool _canEdit(ClassSession session) {
    if (_currentProfile == null) return false;
    // Allow if Admin OR if Trainer owns the session
    if (_currentProfile!.role == 'admin') return true;
    return session.trainerId == _currentProfile!.id;
  }

  Future<void> _showSessionOptions(ClassSession session) async {
    if (!_canEdit(session)) return;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.accentRed),
              title: const Text('Dersi İptal Et', style: TextStyle(color: AppColors.accentRed)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'delete') {
      _deleteSession(session);
    }
  }

  Future<void> _deleteSession(ClassSession session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Dersi İptal Et', style: AppTextStyles.title3),
        content: const Text('Bu dersi silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hayır', style: AppTextStyles.body),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _repository.deleteSession(session.id!);
        await _loadMonthSessions(_focusedDay); // Reload
        if (mounted) CustomSnackBar.showSuccess(context, 'Ders iptal edildi.');
      } catch (e) {
        if (mounted) CustomSnackBar.showError(context, 'Hata: $e');
        setState(() => _isLoading = false);
      }
    }
  }
}
