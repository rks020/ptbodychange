import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/class_session.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import 'add_class_screen.dart';
import 'class_detail_screen.dart';

class ClassScheduleScreen extends StatefulWidget {
  const ClassScheduleScreen({super.key});

  @override
  State<ClassScheduleScreen> createState() => _ClassScheduleScreenState();
}

class _ClassScheduleScreenState extends State<ClassScheduleScreen> {
  final _repository = ClassRepository();
  DateTime _selectedDate = DateTime.now();
  List<ClassSession> _classes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    setState(() => _isLoading = true);
    
    // Set range to full day
    final startOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      0, 0, 0
    );
    final endOfDay = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      23, 59, 59
    );

    try {
      final classes = await _repository.getSessions(startOfDay, endOfDay);
      if (mounted) {
        setState(() {
          _classes = classes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() => _selectedDate = date);
    await _loadClasses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Logo
          Positioned.fill(
            child: Align(
              alignment: const Alignment(0, 0.3),
              child: Opacity(
                opacity: 0.1,
                child: Image.asset(
                  'assets/images/pt_logo.png',
                  width: 300,
                ),
              ),
            ),
          ),
          // Content
          SafeArea(
            child: Column(
              children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Dersler',
                        style: AppTextStyles.largeTitle,
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: AppColors.primaryYellow),
                        onPressed: _loadClasses,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date Selector
                  SizedBox(
                    height: 80,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: 90, // Show 3 months
                      separatorBuilder: (context, index) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final date = DateTime.now().add(Duration(days: index));
                        final isSelected = _isSameDay(date, _selectedDate);
                        
                        return GestureDetector(
                          onTap: () => _onDateSelected(date),
                          child: Container(
                            width: 60,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryYellow
                                  : AppColors.surfaceDark,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryYellow
                                    : AppColors.glassBorder,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _getDayName(date.weekday),
                                  style: AppTextStyles.caption1.copyWith(
                                    color: isSelected
                                        ? Colors.black
                                        : AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${date.day}',
                                  style: AppTextStyles.title3.copyWith(
                                    color: isSelected
                                        ? Colors.black
                                        : AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Classes List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _classes.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _classes.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) => _buildClassItem(_classes[index]),
                        ),
            ),
          ],
        ),
      ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddClassScreen(initialDate: _selectedDate),
            ),
          );
          if (result == true) {
            _loadClasses();
          }
        },
        backgroundColor: AppColors.primaryYellow,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text('Ders Ekle', style: AppTextStyles.headline.copyWith(color: Colors.black)),
      ),
    );
  }

  Widget _buildClassItem(ClassSession session) {
    return GestureDetector(
      onTap: () async {
        final currentUser = Supabase.instance.client.auth.currentUser;
        
        // Ownership check
        if (session.trainerId != null && currentUser?.id != session.trainerId) {
          CustomSnackBar.showError(context, 'Lütfen Eğitmen ile iletişime geçin');
          return;
        }

        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ClassDetailScreen(session: session)),
        );
        if (result == true) {
          _loadClasses();
        }
      },
      child: GlassCard(
        backgroundColor: session.status == 'completed' 
            ? AppColors.accentGreen.withOpacity(0.2) 
            : null,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  _formatTime(session.startTime),
                  style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow),
                ),
                Text(
                  '${session.durationMinutes} dk',
                  style: AppTextStyles.caption1,
                ),
              ],
            ),
            Container(
              height: 40,
              width: 1,
              color: AppColors.glassBorder,
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.title,
                    style: AppTextStyles.headline,
                  ),
                  if (session.trainerName != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.person, size: 14, color: AppColors.primaryYellow),
                        const SizedBox(width: 4),
                        Text(
                          session.trainerName!,
                          style: AppTextStyles.caption1.copyWith(color: AppColors.primaryYellow),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Kapasite: ${session.capacity}',
                        style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_rounded, size: 64, color: AppColors.textSecondary.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Bu tarihte ders yok',
            style: AppTextStyles.headline.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Yeni bir ders eklemek için "+" butonuna basın',
            style: AppTextStyles.caption1,
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDayName(int weekday) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[weekday - 1];
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
