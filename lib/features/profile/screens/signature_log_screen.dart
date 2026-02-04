import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ambient_background.dart';

class SignatureLogScreen extends StatefulWidget {
  const SignatureLogScreen({super.key});

  @override
  State<SignatureLogScreen> createState() => _SignatureLogScreenState();
}

class _SignatureLogScreenState extends State<SignatureLogScreen> {
  final _repository = ClassRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _sessions = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      // Determine role first
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      
      final role = profile['role'] as String?;
      List<Map<String, dynamic>> data;

      if (role == 'trainer' || role == 'owner' || role == 'admin') {
        data = await _repository.getCompletedHistoryWithDetails(trainerId: userId);
      } else {
        // Assume member
        data = await _repository.getMemberCompletedHistory(userId);
      }

      if (mounted) {
        setState(() {
          _sessions = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  void _showSignatureDialog(String title, String? url) {
    if (url == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: AppTextStyles.headline),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: url,
                  placeholder: (context, url) => const CircularProgressIndicator(),
                  errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Kapat', style: AppTextStyles.callout),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Ders Kaydı Defteri'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sessions.isEmpty
              ? Center(
                  child: Text(
                    'Henüz tamamlanmış ders yok.',
                    style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _sessions.length,
                  itemBuilder: (context, index) {
                    final session = _sessions[index];
                    // Use updated_at as the signing time, fall back to start_time
                    final displayTime = session['updated_at'] != null 
                        ? DateTime.parse(session['updated_at']) 
                        : DateTime.parse(session['start_time']);
                    
                    final enrollments = (session['class_enrollments'] as List?) ?? [];
                    final trainerSig = session['trainer_signature_url'] as String?;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GlassCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Date & Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(displayTime),
                                      style: AppTextStyles.subheadline.copyWith(color: AppColors.primaryYellow),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      session['title'] ?? 'Ders',
                                      style: AppTextStyles.headline,
                                    ),
                                  ],
                                ),
                                if (trainerSig != null)
                                  InkWell(
                                    onTap: () => _showSignatureDialog('PT İmzası', trainerSig),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.accentGreen.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppColors.accentGreen),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.verified_rounded, size: 14, color: AppColors.accentGreen),
                                          const SizedBox(width: 4),
                                          Text(
                                            'PT Onaylı',
                                            style: AppTextStyles.caption1.copyWith(color: AppColors.accentGreen),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Divider(color: AppColors.glassBorder, height: 1),
                            const SizedBox(height: 12),
                            
                            // Students List
                            Text('Katılımcılar', style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 8),
                            if (enrollments.isEmpty)
                              Text('Katılımcı yok', style: AppTextStyles.body),
                            
                            ...enrollments.map((e) {
                              final member = e['members'] ?? {};
                              final studentName = member['name'] ?? 'Bilinmeyen Üye';
                              final studentSig = e['student_signature_url'] as String?;
                              final isPresent = e['status'] == 'attended' || e['status'] == 'completed'; // Logic check

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 16, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(studentName, style: AppTextStyles.body)),
                                    if (studentSig != null)
                                      InkWell(
                                        onTap: () => _showSignatureDialog('$studentName İmzası', studentSig),
                                        child: Icon(Icons.draw_rounded, color: AppColors.primaryYellow, size: 20),
                                      )
                                    else if (isPresent)
                                       Text('İmza Yok', style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary))
                                    else
                                       Text('Katılmadı', style: AppTextStyles.caption1.copyWith(color: AppColors.accentRed)),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
      ),
    );
  }
}
