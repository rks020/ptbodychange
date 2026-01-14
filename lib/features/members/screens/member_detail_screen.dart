import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/member.dart';
import '../../../data/repositories/member_repository.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/ambient_background.dart';
import 'add_edit_member_screen.dart';
import '../../measurements/screens/add_measurement_screen.dart';
import '../../measurements/screens/member_measurements_screen.dart';
import '../../measurements/screens/progress_charts_screen.dart';
import '../../../data/repositories/class_repository.dart';
import '../../../data/models/class_session.dart';
import '../../classes/screens/create_schedule_screen.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';
import '../widgets/add_payment_modal.dart';

class MemberDetailScreen extends StatefulWidget {
  final Member member;

  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  late Member _currentMember;

  @override
  void initState() {
    super.initState();
    _currentMember = widget.member;
  }

  Future<void> _editMember() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditMemberScreen(member: _currentMember),
      ),
    );

    if (result == true) {
      // Reload member data
      final repository = MemberRepository();
      final updatedMember = await repository.getById(_currentMember.id);
      if (updatedMember != null) {
        setState(() {
          _currentMember = updatedMember;
        });
      }
    }
  }

  Future<void> _deleteMember() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('Üyeyi Sil', style: AppTextStyles.title3),
        content: Text(
          '${_currentMember.name} adlı üyeyi silmek istediğinize emin misiniz?',
          style: AppTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('İptal', style: AppTextStyles.callout),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentRed,
            ),
            child: Text('Sil', style: AppTextStyles.callout),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final repository = MemberRepository();
      await repository.delete(_currentMember.id);
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Üye Detayı'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: _editMember,
          ),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            onPressed: _deleteMember,
          ),
        ],
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ... (keeping previous content references intact by replacing whole block if needed or carefully targeting)
            // Wait, I need to preserve the list view content up to Action Buttons.
            // I'll assume lines 113-424 are fine and target the Action Buttons block + Layout structure.
            // Actually, I can just replace the whole build method or the part after "Action Buttons".
            // Let's replace the whole build method to be safe with bottomSheet insertion.
            // Oh, bottomNavigationBar property needs to be added to Scaffold.
            // So I must target the Scaffold.
            
            // Re-targeting the Build method implementation.
            
            // Profile Header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.muscleGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Center(
                      child: Text(
                        _currentMember.name.isNotEmpty
                            ? _currentMember.name[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentMember.name,
                    style: AppTextStyles.title1,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _currentMember.isActive
                          ? AppColors.accentGreen.withOpacity(0.2)
                          : AppColors.textSecondary.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _currentMember.isActive ? 'Aktif Üye' : 'Pasif Üye',
                      style: AppTextStyles.callout.copyWith(
                        color: _currentMember.isActive
                            ? AppColors.accentGreen
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_currentMember.subscriptionPackage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Text(
                        _currentMember.subscriptionPackage!,
                        style: AppTextStyles.subheadline.copyWith(
                          color: AppColors.primaryYellow,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (_currentMember.sessionCount != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.confirmation_number_rounded, size: 16, color: AppColors.primaryYellow),
                          const SizedBox(width: 8),
                          Text(
                            '${_currentMember.sessionCount} Ders Hakkı',
                            style: AppTextStyles.subheadline.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Upcoming Classes
            Text(
              'Ders Bilgisi',
              style: AppTextStyles.title3,
            ),
             const SizedBox(height: 12),
            FutureBuilder<List<ClassSession>>(
              future: ClassRepository().getMemberUpcomingClasses(_currentMember.id),
              builder: (context, snapshot) {
                 if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                 }
                 if (snapshot.hasError) {
                   return Text('Hata: ${snapshot.error}', style: TextStyle(color: Colors.red));
                 }
                 
                 final classes = snapshot.data ?? [];

                 return SizedBox(
                   height: 120,
                   child: ListView.builder(
                     scrollDirection: Axis.horizontal,
                     itemCount: classes.length + 1,
                     itemBuilder: (context, index) {
                       // 1. First Item: Remaining Sessions Card
                       if (index == 0) {
                         return Container(
                           width: 140, // Slightly narrower
                           margin: const EdgeInsets.only(right: 12),
                           decoration: BoxDecoration(
                             color: AppColors.surfaceDark,
                             borderRadius: BorderRadius.circular(16),
                             border: Border.all(color: AppColors.glassBorder),
                           ),
                           padding: const EdgeInsets.all(12),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                             children: [
                               Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     'Kalan Ders',
                                     style: AppTextStyles.headline.copyWith(color: AppColors.primaryYellow, fontSize: 16),
                                   ),
                                   const SizedBox(height: 8),
                                   Text(
                                     '${_currentMember.sessionCount ?? 0}',
                                     style: AppTextStyles.title1.copyWith(color: Colors.white, fontSize: 32, height: 1.0),
                                   ),
                                 ],
                               ),
                               Row(
                                 children: [
                                   Icon(Icons.confirmation_number_outlined, size: 12, color: AppColors.textSecondary),
                                   const SizedBox(width: 4),
                                   Text(
                                      'Adet',
                                      style: AppTextStyles.caption1,
                                   ),
                                 ],
                               )
                             ],
                           ),
                         );
                       }

                       // 2. Class Items
                       final session = classes[index - 1]; // Shift index
                       final isCompleted = session.status == 'completed';

                       return Container(
                         width: 170, // Increased width to prevent overflow
                         margin: const EdgeInsets.only(right: 12),
                         decoration: BoxDecoration(
                           color: AppColors.surfaceDark,
                           borderRadius: BorderRadius.circular(16),
                           border: Border.all(
                             color: isCompleted ? AppColors.accentGreen.withOpacity(0.5) : AppColors.glassBorder
                           ),
                         ),
                         padding: const EdgeInsets.all(12),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(
                                   isCompleted ? 'Tamamlanmış' : 'Gelecek Ders',
                                   style: AppTextStyles.headline.copyWith(
                                     color: isCompleted ? AppColors.accentGreen : AppColors.primaryYellow, 
                                     fontSize: 16
                                   ),
                                   maxLines: 1,
                                   overflow: TextOverflow.ellipsis,
                                 ),
                                 const SizedBox(height: 8),
                                 Text(
                                   DateFormat('dd MMM HH:mm', 'tr_TR').format(session.startTime),
                                   style: AppTextStyles.title1.copyWith(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                 ),
                               ],
                             ),

                              Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      session.title, // Trainer Name
                                       style: AppTextStyles.caption1,
                                       maxLines: 1, overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                           ],
                         ),
                       );
                     },
                   ),
                 );
              },
            ),
            const SizedBox(height: 32),

            // Contact Information
            Text(
              'İletişim Bilgileri',
              style: AppTextStyles.title3,
            ),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.email_rounded,
                    label: 'E-posta',
                    value: _currentMember.email,
                  ),
                  const Divider(height: 24),
                  _InfoRow(
                    icon: Icons.phone_rounded,
                    label: 'Telefon',
                    value: _currentMember.phone,
                  ),
                  const Divider(height: 24),
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    label: 'Kayıt Tarihi',
                    value: DateFormat('dd MMMM yyyy', 'tr_TR')
                        .format(_currentMember.joinDate),
                  ),
                ],
              ),
            ),

            // Emergency Contact
            if (_currentMember.emergencyContact != null ||
                _currentMember.emergencyPhone != null) ...[
              const SizedBox(height: 24),
              Text(
                'Acil Durum',
                style: AppTextStyles.title3,
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Column(
                  children: [
                    if (_currentMember.emergencyContact != null)
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Kişi',
                        value: _currentMember.emergencyContact!,
                      ),
                    if (_currentMember.emergencyContact != null &&
                        _currentMember.emergencyPhone != null)
                      const Divider(height: 24),
                    if (_currentMember.emergencyPhone != null)
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Telefon',
                        value: _currentMember.emergencyPhone!,
                      ),
                  ],
                ),
              ),
            ],

            // Notes
            if (_currentMember.notes != null &&
                _currentMember.notes!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Notlar',
                style: AppTextStyles.title3,
              ),
              const SizedBox(height: 12),
              GlassCard(
                child: Text(
                  _currentMember.notes!,
                  style: AppTextStyles.body,
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            Text(
              'İşlemler',
              style: AppTextStyles.title3,
            ),
            const SizedBox(height: 12),
            Column(
              children: [
                _ActionTile(
                  title: 'Program Oluştur & Düzenle',
                  subtitle: 'Üye için ders programı hazırla',
                  icon: Icons.calendar_month_rounded,
                  color: AppColors.accentOrange,
                  onTap: () {
                     Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => CreateScheduleScreen(member: _currentMember),
                      ),
                    ).then((_) {
                       setState(() {}); // Refresh logic if needed
                    });
                  },
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  title: 'Ölçüm Ekle',
                  subtitle: 'Yeni vücut ölçümleri kaydet',
                  icon: Icons.straighten_rounded,
                  color: AppColors.accentOrange, // Keeping same color as defined in dashboard usually
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AddMeasurementScreen(member: _currentMember),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  title: 'Ölçüm Geçmişi',
                  subtitle: 'Tüm ölçüm kayıtlarını incele',
                  icon: Icons.history_rounded,
                  color: AppColors.accentOrange,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => MemberMeasurementsScreen(memberId: _currentMember!.id),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _ActionTile(
                  title: 'Gelişim Grafikleri',
                  subtitle: 'Vücut değişim analizini gör',
                  icon: Icons.show_chart_rounded,
                  color: AppColors.accentOrange,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ProgressChartsScreen(member: _currentMember),
                      ),
                    );
                  },
                ),
                // Payment Button Removed from here
              ],
            ),
            const SizedBox(height: 32),

            // Payment History
            Text(
              'Son Ödemeler',
              style: AppTextStyles.title3,
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<Payment>>(
              future: PaymentRepository().getMemberPayments(_currentMember.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final payments = snapshot.data ?? [];
                if (payments.isEmpty) {
                  return GlassCard(
                    child: Center(
                      child: Text(
                        'Henüz ödeme kaydı yok.',
                        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                return Column(
                  children: payments.take(5).map((payment) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.accentGreen.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.currency_lira,
                              color: AppColors.accentGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payment.category.label,
                                  style: AppTextStyles.headline.copyWith(fontSize: 16),
                                ),
                                Text(
                                  payment.formattedDate,
                                  style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                payment.formattedAmount,
                                style: AppTextStyles.headline.copyWith(
                                  color: AppColors.accentGreen,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                payment.type.label,
                                style: AppTextStyles.caption1.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 80), // Extra space for bottom bar
          ],
        ),
      ),
    ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: SafeArea(
          child: CustomButton(
            text: 'Ödeme Al',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => AddPaymentModal(member: _currentMember),
              ).then((result) {
                if (result == true) {
                  setState(() {}); // Refresh payments
                }
              });
            },
            icon: Icons.payments_rounded,
            backgroundColor: AppColors.accentGreen,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryYellow.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.primaryYellow,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption1.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppTextStyles.callout,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.headline,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.subheadline,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
