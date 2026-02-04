import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _loadEnrollments();
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
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: widget.session.workoutId != null 
                                  ? AppColors.primaryYellow.withOpacity(0.3)
                                  : Colors.grey.withOpacity(0.3)
                            )
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.session.workoutId != null ? Icons.fitness_center : Icons.add_circle_outline, 
                                size: 16, 
                                color: widget.session.workoutId != null ? AppColors.primaryYellow : Colors.grey
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.session.workoutName != null 
                                      ? 'Program: ${widget.session.workoutName}'
                                      : 'Program Seçilmedi (Ata)',
                                  style: AppTextStyles.headline.copyWith(
                                    color: widget.session.workoutId != null ? AppColors.primaryYellow : Colors.grey
                                  ),
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
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
    if (widget.session.workoutId != null) {
      _showWorkoutDetails(widget.session.workoutId!);
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
      // Create updated session manually since we don't have copyWith
      // IMPORTANT: Preserving all existing fields
      final updatedSession = ClassSession(
        id: widget.session.id,
        title: widget.session.title,
        description: widget.session.description,
        startTime: widget.session.startTime,
        endTime: widget.session.endTime,
        capacity: widget.session.capacity,
        trainerId: widget.session.trainerId,
        status: widget.session.status,
        isCancelled: widget.session.isCancelled,
        createdAt: widget.session.createdAt,
        trainerSignatureUrl: widget.session.trainerSignatureUrl,
        workoutId: workout.id, // NEW
        workoutName: workout.name, 
        currentEnrollments: widget.session.currentEnrollments,
      );

      await _classRepository.updateSession(updatedSession);
      CustomSnackBar.showSuccess(context, 'Program atandı: ${workout.name}');
      
      // Need to reload the screen -> Assuming parent can rebuild or we navigate replacement
      // For now, simpler: Pop with result true to indicate update, or just use setState if we can update widget.session locally?
      // widget.session is final. We should probably pop(true) or use a local state wrapper.
      // Easiest is to pop(true) and let previous screen reload, OR navigate replacement to self.
      // Better yet: Just Pop(true) and let the previous screen handle refresh? 
      // User is ON this screen. They want to see the change.
      // I cannot update `widget.session`. 
      // Solution: Convert `ClassDetailScreen` to fetch its own session or wrap session in State.
      // OR: Navigate Replace to self.
      if (mounted) {
         Navigator.pushReplacement(
           context, 
           MaterialPageRoute(builder: (_) => ClassDetailScreen(session: updatedSession))
         );
      }

    } catch (e) {
      CustomSnackBar.showError(context, 'Atama hatası: $e');
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
