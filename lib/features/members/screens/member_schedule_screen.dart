import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/glass_card.dart';

class MemberScheduleScreen extends StatefulWidget {
  const MemberScheduleScreen({super.key});

  @override
  State<MemberScheduleScreen> createState() => _MemberScheduleScreenState();
}

class _MemberScheduleScreenState extends State<MemberScheduleScreen> {
  final _supabase = Supabase.instance.client;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<dynamic>> _events = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadMyClasses();
  }

  Future<void> _loadMyClasses() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Ensure we get only this member's sessions
      // RLS should enforce it if we query by member_id or if policy is "View Own"
      // But let's be explicit
      final response = await _supabase
          .from('class_sessions')
          .select('*, profiles:trainer_id(first_name, last_name)')
          .eq('member_id', user.id) // Only my classes
          .order('start_time');

      final Map<DateTime, List<dynamic>> events = {};

      for (var session in (response as List)) {
        final startTime = DateTime.parse(session['start_time']).toLocal();
        final date = DateTime(startTime.year, startTime.month, startTime.day);

        if (events[date] == null) events[date] = [];
        events[date]!.add(session);
      }

      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _events[DateTime(day.year, day.month, day.day)] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Ders Programım',
                    style: AppTextStyles.title1.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                GlassCard(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: TableCalendar(
                    firstDay: DateTime.utc(2024, 1, 1),
                    lastDay: DateTime.utc(2026, 12, 31),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    calendarFormat: CalendarFormat.week,
                    availableCalendarFormats: const {
                      CalendarFormat.week: 'Haftalık',
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    eventLoader: _getEventsForDay,
                    calendarStyle: CalendarStyle(
                      defaultTextStyle: const TextStyle(color: Colors.white),
                      weekendTextStyle: const TextStyle(color: AppColors.accentOrange),
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
                        color: AppColors.neonCyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: HeaderStyle(
                      titleCentered: true,
                      formatButtonVisible: false,
                      titleTextStyle: AppTextStyles.headline,
                      leftChevronIcon: const Icon(Icons.chevron_left, color: Colors.white),
                      rightChevronIcon: const Icon(Icons.chevron_right, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _getEventsForDay(_selectedDay!).length,
                    itemBuilder: (context, index) {
                      final session = _getEventsForDay(_selectedDay!)[index];
                      return _buildClassCard(session);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildClassCard(dynamic session) {
    final startTime = DateTime.parse(session['start_time']).toLocal();
    final endTime = DateTime.parse(session['end_time']).toLocal();
    final trainer = session['profiles'];
    final trainerName = trainer != null 
        ? '${trainer['first_name']} ${trainer['last_name']}' 
        : 'Eğitmen';
    
    final status = session['status'] ?? 'scheduled';
    Color statusColor = AppColors.primaryYellow;
    String statusText = 'Planlandı';

    if (status == 'completed') {
      statusColor = AppColors.accentGreen;
      statusText = 'Tamamlandı';
    } else if (status == 'cancelled') {
      statusColor = AppColors.accentRed;
      statusText = 'İptal';
    }

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      border: Border.all(color: statusColor.withOpacity(0.5)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('HH:mm').format(startTime),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  DateFormat('HH:mm').format(endTime),
                  style: TextStyle(
                    color: statusColor.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trainerName,
                  style: AppTextStyles.headline,
                ),
                const SizedBox(height: 4),
                Text(
                  session['notes'] ?? 'Ders notu bulunmuyor',
                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: statusColor.withOpacity(0.3)),
            ),
            child: Text(
              statusText,
              style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
