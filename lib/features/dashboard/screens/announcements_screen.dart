import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/custom_text_field.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _announcements = [];
  Map<String, String> _creatorNames = {};
  bool _isLoading = true;
  bool _canManage = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadAnnouncements();
  }

  Future<void> _checkPermissions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .single();
      
      if (mounted) {
        setState(() {
          final role = data['role'] as String?;
          _canManage = role == 'owner' || role == 'trainer';
        });
      }
    } catch (e) {
      debugPrint('Error checking permissions: $e');
    }
  }

  Future<void> _loadAnnouncements() async {
    try {
      // Fetch announcements. Because of RLS, users only see their org's.
      // Order by created_at desc
      final response = await _supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);
      
      final data = List<Map<String, dynamic>>.from(response);

      // Fetch Creator Names
      final userIds = data.map((e) => e['created_by'] as String).toSet().toList();
      if (userIds.isNotEmpty) {
        final profiles = await _supabase.from('profiles').select('id, first_name, last_name, role').filter('id', 'in', userIds);
        for (var p in profiles) {
          final name = '${p['first_name']} ${p['last_name']}';
          final role = p['role'] == 'owner' ? 'Salon Sahibi' : (p['role'] == 'trainer' ? 'Eğitmen' : '');
          _creatorNames[p['id']] = role.isNotEmpty ? '$name ($role)' : name;
        }
      }

      if (mounted) {
        setState(() {
          _announcements = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.showError(context, 'Duyurular yüklenirken hata oluştu: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addAnnouncement(String title, String content) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // We need organization_id. 
      // Option 1: Fetch from profile.
      // Option 2: Maybe we can rely on a helper or existing state?
      // Let's fetch from profile to be safe.
      final profile = await _supabase.from('profiles').select('organization_id').eq('id', userId).single();
      final orgId = profile['organization_id'];

      if (orgId == null) throw Exception('Organizasyon bulunamadı');

      await _supabase.from('announcements').insert({
        'organization_id': orgId,
        'created_by': userId,
        'title': title,
        'content': content,
      });

      _loadAnnouncements();
      if (mounted) Navigator.pop(context);
      if (mounted) CustomSnackBar.showSuccess(context, 'Duyuru oluşturuldu');

    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Hata: $e');
    }
  }

  Future<void> _deleteAnnouncement(String id) async {
    try {
      await _supabase.from('announcements').delete().eq('id', id);
      _loadAnnouncements();
      if (mounted) CustomSnackBar.showSuccess(context, 'Duyuru silindi');
    } catch (e) {
      if (mounted) CustomSnackBar.showError(context, 'Silme hatası: $e');
    }
  }

  void _showAddDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Yeni Duyuru', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomTextField(
                label: 'Başlık',
                controller: titleController,
                hint: 'Örn: Salon Bakımı',
              ),
              const SizedBox(height: 16),
              CustomTextField(
                label: 'İçerik',
                controller: contentController,
                hint: 'Duyuru metni...',
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                 _addAnnouncement(titleController.text.trim(), contentController.text.trim());
              }
            },
            child: const Text('Paylaş', style: TextStyle(color: AppColors.primaryYellow)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Duyuruyu Sil', style: TextStyle(color: Colors.white)),
        content: const Text('Bu duyuruyu silmek istediğinize emin misiniz?', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // close confirm
              _deleteAnnouncement(id);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Duyurular', style: AppTextStyles.headline),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _showAddDialog,
              backgroundColor: AppColors.primaryYellow,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
      body: AmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primaryYellow))
              : _announcements.isEmpty
                  ? Center(
                      child: Text(
                        'Henüz duyuru yok',
                        style: AppTextStyles.body.copyWith(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _announcements.length,
                      itemBuilder: (context, index) {
                        final item = _announcements[index];
                        final date = DateTime.parse(item['created_at']).toLocal();
                        final formattedDate = DateFormat('dd MMM yyyy, HH:mm', 'tr_TR').format(date);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: GlassCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item['title'] ?? 'Başlık Yok',
                                        style: AppTextStyles.title3.copyWith(color: AppColors.primaryYellow),
                                      ),
                                    ),
                                    if (_canManage)
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                        onPressed: () => _showDeleteConfirm(item['id']),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  item['content'] ?? '',
                                  style: AppTextStyles.body.copyWith(color: Colors.white),
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _creatorNames[item['created_by']] ?? '',
                                        style: AppTextStyles.caption1.copyWith(
                                          color: AppColors.primaryYellow.withOpacity(0.8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formattedDate,
                                        style: AppTextStyles.caption2.copyWith(color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ),
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
