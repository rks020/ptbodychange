import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/class_session.dart';
import '../../../data/models/class_enrollment.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/repositories/member_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/signature_dialog.dart';
import '../../../features/workouts/repositories/workout_repository.dart';
import '../../../features/workouts/models/workout_model.dart';
import 'dart:typed_data';

class ClassDetailScreen extends StatefulWidget {
  final ClassSession session;

  const ClassDetailScreen({super.key, required this.session});

  @override
  State<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends State<ClassDetailScreen> {
  final _classRepository = ClassRepository();
  final _memberRepository = MemberRepository();
  
  List<ClassEnrollment> _enrollments = [];
  bool _isLoading = true;
  late ClassSession _currentSession; // Güncel session verisi

  @override
  void initState() {
    super.initState();
    _currentSession = widget.session; // Başlangıçta widget'tan al
    _loadSessionAndEnrollments();
  }

  // Session ve enrollments'ı birlikte yükle
  Future<void> _loadSessionAndEnrollments() async {
    setState(() => _isLoading = true);
    try {
      // Session'ı yeniden yükle (workout_id güncellemesi için)
      final response = await Supabase.instance.client
          .from('class_sessions')
          .select('*, profiles(first_name, last_name), workouts(name)')
          .eq('id', widget.session.id!)
          .single();
      
      final updatedSession = ClassSession.fromJson(response);
      
      // Enrollments'ı yükle
      final enrollments = await _classRepository.getEnrollments(widget.session.id!);
      
      if (mounted) {
        setState(() {
          _currentSession = updatedSession;
          _enrollments = enrollments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.showError(context, 'Yüklenirken hata: $e');
      }
    }
  }

  Future<void> _loadEnrollments() async {
    try {
      final enrollments = await _classRepository.getEnrollments(widget.session.id!);
      if (mounted) {
        setState(() {
          _enrollments = enrollments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _enrollMember() async {
    // 1. Fetch active members (filtered by class trainer if available)
    final members = widget.session.trainerId != null 
        ? await _memberRepository.getActiveByTrainer(widget.session.trainerId!)
        : await _memberRepository.getActive();
    
    // Filter out already enrolled members
    
    // Filter out already enrolled members
    final enrolledIds = _enrollments.map((e) => e.memberId).toSet();
    final availableMembers = members.where((m) => !enrolledIds.contains(m.id)).toList();

    if (!mounted) return;

    if (availableMembers.isEmpty) {
      CustomSnackBar.showError(context, 'Eklenecek aktif üye bulunamadı veya hepsi kayıtlı.');
      return;
    }

    // 2. Show selection sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Üye Ekle', style: AppTextStyles.title2),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: availableMembers.length,
                separatorBuilder: (_, __) => const Divider(color: AppColors.glassBorder),
                itemBuilder: (context, index) {
                  final member = availableMembers[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: member.photoPath != null 
                          ? NetworkImage(member.photoPath!) 
                          : null,
                      backgroundColor: AppColors.cardDark,
                      child: member.photoPath == null 
                          ? Text(member.name[0], style: const TextStyle(color: AppColors.primaryYellow))
                          : null,
                    ),
                    title: Text(member.name, style: AppTextStyles.headline),
                    trailing: const Icon(Icons.add_circle, color: AppColors.primaryYellow),
                    onTap: () async {
                      Navigator.pop(context); // Close sheet
                      await _confirmEnroll(member);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEnroll(Member member) async {
    try {
      // Check capacity
      if (_enrollments.length >= widget.session.capacity) {
        CustomSnackBar.showError(context, 'Ders kapasitesi dolu!');
        return;
      }

      await _classRepository.enrollMember(widget.session.id!, member.id);
      CustomSnackBar.showSuccess(context, '${member.name} derse eklendi');
      _loadEnrollments(); // Refresh list
    } catch (e) {
      CustomSnackBar.showError(context, 'Hata: $e');
    }
  }

  Future<void> _toggleAttendance(ClassEnrollment enrollment) async {
    // Cycle: booked -> attended -> absent -> booked
    String newStatus;
    if (enrollment.status == 'booked') {
      newStatus = 'attended';
    } else if (enrollment.status == 'attended') {
      newStatus = 'absent';
    } else {
      newStatus = 'booked';
    }

    try {
      await _classRepository.updateEnrollmentStatus(enrollment.id!, newStatus);
      _loadEnrollments();
    } catch (e) {
      CustomSnackBar.showError(context, 'Güncelleme hatası: $e');
    }
  }

  // İmza özelliği kaldırıldı

  Future<void> _completeClass() async {
    // İmza özelliği kaldırıldı, sadece katılım kontrolü
    try {
      await _classRepository.completeSession(widget.session.id!, null);
      CustomSnackBar.showSuccess(context, 'Ders tamamlandı');
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      CustomSnackBar.showError(context, 'Hata: $e');
    }
  }

  Future<void> _removeMember(ClassEnrollment enrollment) async {
    try {
      await _classRepository.removeEnrollment(enrollment.id!);
      CustomSnackBar.showSuccess(context, 'Üye dersten çıkarıldı');
      _loadEnrollments();
    } catch (e) {
      CustomSnackBar.showError(context, 'Silme hatası: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ders Detayı'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: AppColors.primaryYellow,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.accentRed),
            onPressed: () => _showDeleteConfirmation(context),
          ),
          IconButton(
            icon: const Icon(Icons.access_time_filled_rounded, color: AppColors.primaryYellow),
            tooltip: 'Rötar',
            onPressed: _showDelayDialog,
          ),
        ],
      ),
      body: Stack(
        children: [
           // Background Logo
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Opacity(
                opacity: 0.1, // Subtle opacity
                child: Image.asset(
                  'assets/images/pt_logo.png',
                  width: 300,
                ),
              ),
            ),
          ),
          // Content
          Column(
            children: [
              // Class Info Card
              GlassCard(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.session.title,
                            style: AppTextStyles.title2.copyWith(color: AppColors.primaryYellow),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text('${_enrollments.length}/${widget.session.capacity}', style: AppTextStyles.caption1.copyWith(color: Colors.black)),
                          backgroundColor: AppColors.primaryYellow,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.calendar_today_rounded, '${widget.session.startTime.day}.${widget.session.startTime.month}.${widget.session.startTime.year}'),
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.access_time_rounded, '${_formatTime(widget.session.startTime)} - ${_formatTime(widget.session.endTime)}'),
                    if (widget.session.description != null) ...[
                      const SizedBox(height: 12),
                      Text(widget.session.description!, style: AppTextStyles.caption1),
                    ],
                      const SizedBox(height: 12),
                      const Divider(color: AppColors.glassBorder),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _handleWorkoutAction,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _currentSession.workoutId != null 
                                  ? AppColors.primaryYellow
                                  : Colors.grey,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _currentSession.workoutId != null ? Icons.fitness_center : Icons.add_circle_outline, 
                                size: 24, 
                                color: _currentSession.workoutId != null ? AppColors.primaryYellow : Colors.grey
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _currentSession.workoutName != null 
                                      ? 'Program: ${_currentSession.workoutName}'
                                      : 'Program Seçilmedi (Ata)',
                                  style: AppTextStyles.body.copyWith(
                                    color: _currentSession.workoutId != null ? AppColors.primaryYellow : Colors.grey
                                  ),
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textSecondary),
                            ],
                          ),
                      ),
                    ),
                  ],
                  ),
                ),
              
              Expanded(
                child: GlassCard(
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Katılımcılar', style: AppTextStyles.headline),
                          IconButton(
                            icon: const Icon(Icons.person_add_rounded, color: AppColors.primaryYellow),
                            onPressed: _enrollMember,
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.glassBorder),
                      Expanded(
                        child: _isLoading 
                            ? const Center(child: CircularProgressIndicator())
                            : _enrollments.isEmpty 
                                ? Center(child: Text('Henüz katılımcı yok', style: AppTextStyles.caption1))
                                : ListView.separated(
                                    itemCount: _enrollments.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                                    itemBuilder: (context, index) => _buildEnrollmentItem(_enrollments[index]),
                                  ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.session.status != 'completed')
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: CustomButton(
                    text: 'Dersi Tamamla',
                    onPressed: _completeClass,
                    icon: Icons.check_circle_outline_rounded,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEnrollmentItem(ClassEnrollment enrollment) {
    if (enrollment.member == null) return const SizedBox.shrink();
    
    final isAttended = enrollment.status == 'attended';
    
    return Dismissible(
      key: Key(enrollment.id!),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.accentRed,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => _removeMember(enrollment),
      confirmDismiss: (_) async => await _confirmRemove(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage: enrollment.member!.photoPath != null 
                  ? NetworkImage(enrollment.member!.photoPath!) 
                  : null,
              child: enrollment.member!.photoPath == null 
                  ? Text(enrollment.member!.name[0]) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(enrollment.member!.name, style: AppTextStyles.body),
            ),
            // İmza butonu kaldırıldı
            IconButton(
              tooltip: enrollment.status == 'absent' ? 'Gelmedi' : (isAttended ? 'Geldi' : 'Bekliyor'),
              icon: Icon(
                enrollment.status == 'absent' 
                    ? Icons.cancel 
                    : (isAttended ? Icons.check_circle : Icons.check_circle_outline),
                color: enrollment.status == 'absent' 
                    ? AppColors.accentRed 
                    : (isAttended ? AppColors.accentGreen : AppColors.textSecondary),
              ),
              onPressed: () => _toggleAttendance(enrollment),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(text, style: AppTextStyles.body),
      ],
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<bool> _confirmRemove() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Sil?', style: TextStyle(color: Colors.white)),
        content: const Text('Üyeyi dersten çıkarmak istediğinize emin misiniz?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
  }
  
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Dersi Sil', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Bu işlemi nasıl uygulamak istersiniz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (widget.session.id != null) {
                await _classRepository.deleteSession(widget.session.id!);
                if (mounted) Navigator.pop(context, true);
              }
            },
            child: const Text('Sadece Bu Dersi', style: TextStyle(color: AppColors.accentRed)),
          ),
          if (widget.session.trainerId != null)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _classRepository.deleteSeries(
                  widget.session.title,
                  widget.session.trainerId!,
                );
                if (mounted) Navigator.pop(context, true);
              },
              child: const Text('Tüm Programı', style: TextStyle(color: AppColors.accentRed, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }
  Future<void> _showDelayDialog() async {
    if (widget.session.status == 'completed') {
      CustomSnackBar.showError(context, 'Tamamlanmış derste değişiklik yapamazsınız');
      return;
    }

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(widget.session.startTime),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryYellow,
              onPrimary: Colors.black,
              surface: AppColors.surfaceDark,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      final newStart = DateTime(
        widget.session.startTime.year,
        widget.session.startTime.month,
        widget.session.startTime.day,
        picked.hour,
        picked.minute,
      );
      
      // Calculate original duration to preserve it
      final duration = widget.session.durationMinutes;
      final newEnd = newStart.add(Duration(minutes: duration));

      try {
        await _classRepository.updateSessionTime(widget.session.id!, newStart, newEnd);
        CustomSnackBar.showSuccess(context, 'Ders saati güncellendi');
        if (mounted) Navigator.pop(context, true); // Close and refresh
      } catch (e) {
        CustomSnackBar.showError(context, 'Güncelleme hatası: $e');
      }
    }
  }

  void _handleWorkoutAction() {
    if (_currentSession.workoutId != null) {
      _showWorkoutDetails(_currentSession.workoutId!);
    } else {
      _showAssignDialog();
    }
  }

  Future<void> _showAssignDialog() async {
    try {
      // Load workouts
      final workoutRepo = WorkoutRepository();
      final workouts = await workoutRepo.getWorkouts();
      
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Program Ata', style: AppTextStyles.title2),
              const SizedBox(height: 16),
              if (workouts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text('Kayıtlı program bulunamadı.', style: TextStyle(color: Colors.grey))),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: workouts.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final w = workouts[index];
                      return ListTile(
                        title: Text(w.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('${w.exercises.length} Hareket', style: const TextStyle(color: Colors.grey)),
                        onTap: () async {
                          Navigator.pop(context);
                          await _assignWorkout(w);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );

    } catch (e) {
      CustomSnackBar.showError(context, 'Programlar yüklenirken hata oluştu: $e');
    }
  }

  Future<void> _assignWorkout(Workout workout) async {
    try {
      await _classRepository.updateSessionWorkout(widget.session.id!, workout.id);
      
      // Session'ı tekrar yükle ki güncel workout bilgisi gösterilsin
      await _loadSessionAndEnrollments();
      
      CustomSnackBar.showSuccess(context, 'Program atandı');
    } catch (e) {
      CustomSnackBar.showError(context, 'Program atama hatası: $e');
    }
  }

  Future<void> _showWorkoutDetails(String workoutId) async {
    try {
      final workoutRepo = WorkoutRepository(); 
      final workout = await workoutRepo.getWorkout(workoutId);
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          title: Text(workout.name, style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow)),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.separated(
              itemCount: workout.exercises.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10),
              itemBuilder: (context, index) {
                final ex = workout.exercises[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ex.exercise?.name ?? 'Hareket ${index+1}', style: const TextStyle(color: Colors.white)),
                  subtitle: Text(
                    '${ex.sets} Set x ${ex.reps} Tekrar • ${ex.restSeconds}sn Dinlenme', 
                    style: const TextStyle(color: Colors.grey)
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _showAssignDialog();
              },
              child: const Text('Değiştir', style: TextStyle(color: AppColors.primaryYellow)),
            ),
             TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat', style: TextStyle(color: Colors.white))),
          ],
        ),
      );
    } catch (e) {
      CustomSnackBar.showError(context, 'Program detayları yüklenemedi: $e');
    }
  }
}
