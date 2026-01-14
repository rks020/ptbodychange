import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_config.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/profile_repository.dart';
import '../../../shared/widgets/custom_snackbar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../chat/screens/chat_screen.dart';
import '../../../shared/widgets/ambient_background.dart';

class TrainersListScreen extends StatefulWidget {
  const TrainersListScreen({super.key});

  @override
  State<TrainersListScreen> createState() => _TrainersListScreenState();
}

class _TrainersListScreenState extends State<TrainersListScreen> {
  final _supabase = Supabase.instance.client;
  List<Profile> _trainers = [];
  bool _isLoading = true;
  Set<String> _onlineUserIds = {};
  Set<String> _busyTrainerIds = {};
  RealtimeChannel? _presenceChannel;
  bool _isAdmin = false;
  final _profileRepository = ProfileRepository();
  Set<String> _selectedTrainerIds = {};
  bool get _isSelectionMode => _selectedTrainerIds.isNotEmpty;

  String _myStatus = 'online'; // online, busy, away
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    debugPrint('=== LOADING DATA ===');
    await _checkAdminStatus(); // Check admin status first!
    await Future.wait([
      _loadTrainers(),
      _checkBusyStatus(),
    ]);
    _setupPresence();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final profile = await _profileRepository.getProfile();
      debugPrint('=== CHECKING ADMIN STATUS ===');
      debugPrint('Profile role: ${profile?.role}');
      
      if (mounted) {
        setState(() {
          _isAdmin = profile?.role == 'admin' || profile?.role == 'owner';
          debugPrint('Is Admin set to: $_isAdmin');
        });
      }
    } catch (e) {
      debugPrint('Error checking admin status: $e');
    }
  }

  Future<void> _loadTrainers() async {
    try {
      // 1. Fetch all, ordered by newest creation date first
      final response = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false); 
          
      final trainers = (response as List).map((e) => Profile.fromSupabase(e)).toList();
      
      // 2. Custom Sort: Force Owner to the very top
      trainers.sort((a, b) {
        if (a.role == 'owner' && b.role != 'owner') return -1; // Owner moves up
        if (a.role != 'owner' && b.role == 'owner') return 1;  // Owner moves up
        return 0; // Maintain existing order (created_at descending) for non-owners
      });

      if (mounted) {
        setState(() {
          _trainers = trainers;
          _isLoading = false; 
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkBusyStatus() async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final response = await _supabase
          .from('class_sessions')
          .select('trainer_id')
          .neq('status', 'cancelled')
          .lte('start_time', now)
          .gte('end_time', now);
      
      final busyIds = (response as List).map((e) => e['trainer_id'] as String).toSet();
      
      if (mounted) {
        setState(() {
          _busyTrainerIds = busyIds;
        });
      }
    } catch (e) {
      debugPrint('Error checking busy status: $e');
    }
  }

  void _setupPresence() {
    _presenceChannel = _supabase.channel('online_users');
    _presenceChannel?.onPresenceSync((payload) {
      if (!mounted) return;
      
      // presenceState() returns List<SinglePresenceState> in this version
      final dynamic rawState = _presenceChannel?.presenceState();
      final Map<String, dynamic> statusMap = {};

      if (rawState != null && rawState is List) {
        for (final item in rawState) {
          _extractPresence(item, statusMap);
        }
      } else if (rawState is Map) {
         // Fallback for different versions
         rawState.forEach((key, value) {
           _extractPresence(value, statusMap);
         });
      }
      
      
      setState(() {
        _onlineUserIds = statusMap.keys.toSet();
        _userManualStatuses = statusMap;
      });
      setState(() {
        _onlineUserIds = statusMap.keys.toSet();
        _userManualStatuses = statusMap;
      });
    }).subscribe((status, error) async {
       if (status == RealtimeSubscribeStatus.subscribed) {
         await _updateMyPresence();
       }
    });
  }
  
  void _extractPresence(dynamic presenceData, Map<String, dynamic> statusMap) {
    try {
      // If it's a list (e.g. Map value or List<SinglePresenceState>), recurse or iterate
      if (presenceData is List) {
        for (final item in presenceData) {
          _extractPresence(item, statusMap);
        }
        return;
      }

      // Check for 'presences' list (seen in logs for PresenceState)
      try {
        final presences = (presenceData as dynamic).presences;
        if (presences != null && presences is List) {
           for (final presence in presences) {
             // Each presence has a payload
             final payload = (presence as dynamic).payload;
             _extractPayload(payload, statusMap);
          }
          return;
        }
      } catch (_) {}

      // Check for 'payloads' list (standard Phoenix/Realtime Presence structure)
      try {
        final payloads = (presenceData as dynamic).payloads;
        if (payloads != null && payloads is List) {
          for (final payload in payloads) {
            _extractPayload(payload, statusMap);
          }
          return;
        }
      } catch (_) {}

      // Fallback: Check for 'payload' (singular)
      try {
        final payload = (presenceData as dynamic).payload;
        if (payload != null) {
           _extractPayload(payload, statusMap);
           return;
        }
      } catch (_) {}

      // Fallback: Treat presenceData itself as payload (Map)
      _extractPayload(presenceData, statusMap);

    } catch (e) {
      // Ignore parsing errors
    }
  }

  void _extractPayload(dynamic payload, Map<String, dynamic> statusMap) {
     if (payload == null) return;
     
     // Sometimes payload is wrapped in another payload key
     dynamic internalPayload = payload;
     if (internalPayload is Map && internalPayload.containsKey('payload')) {
       internalPayload = internalPayload['payload'];
     }

     final uid = _getValue(internalPayload, 'user_id');
     if (uid != null) {
       final st = _getValue(internalPayload, 'status');
       statusMap[uid.toString()] = st;
     }
  }

  dynamic _getValue(dynamic data, String key) {
    if (data is Map) {
      return data[key];
    }
    // Try property access via dynamic
    try {
      return (data as dynamic).toJson()[key];
    } catch (_) {}
    try {
       // Reflection-like access isn't easy, assume Map usually
    } catch (_) {}
    return null;
  }
  
  Map<String, dynamic> _userManualStatuses = {}; // userId -> status

  Future<void> _updateMyPresence() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId != null) {
      await _presenceChannel?.track({
        'user_id': userId,
        'status': _myStatus,
        'online_at': DateTime.now().toIso8601String(),
      });
    }
  }
  
  Future<void> _setMyStatus(String status) async {
    setState(() {
      _myStatus = status;
    });
    await _updateMyPresence();
  }

  @override
  void dispose() {
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
    }
    super.dispose();
  }



  Future<void> _showAddTrainerDialog() async {
    final usernameController = TextEditingController(); 
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final emailFocusNode = FocusNode();
    
    // Default specialty
    String selectedSpecialty = 'Personal Trainer';
    String? errorText; // For validation errors
    final List<String> specialtyOptions = [
      'Personal Trainer',
      'Diyetisyen',
      'Fizyoterapist',
      'PT / Diyetisyen',
      'PT / Fizyoterapist',
      'Yoga Eğitmeni',
      'Pilates Eğitmeni',
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            title: const Text('Yeni Eğitmen Ekle', style: TextStyle(color: AppColors.primaryYellow)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   DropdownButtonFormField<String>(
                    value: selectedSpecialty,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Görevi / Uzmanlık',
                      labelStyle: TextStyle(color: Colors.grey),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    ),
                    items: specialtyOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      if (newValue != null) {
                        setStateDialog(() => selectedSpecialty = newValue);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: firstNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Ad', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: lastNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Soyad', labelStyle: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailController,
                    focusNode: emailFocusNode,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'E-posta Adresi', 
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: 'ornek@email.com',
                      hintStyle: TextStyle(color: Colors.white30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usernameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı Adı (Opsiyonel)', 
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: 'ornek, bosluksuz',
                      hintStyle: TextStyle(color: Colors.white30),
                    ),
                  ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Geçici Şifre', 
                      labelStyle: TextStyle(color: Colors.grey),
                      hintText: 'Eğitmen ilk girişte değiştirecek',
                      hintStyle: TextStyle(color: Colors.white30),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  const Text(
                  'Eğitmen bu şifre ile giriş yapıp kendi şifresini belirleyecektir.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('İptal', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () {
                  // Validate before closing
                  final email = emailController.text.trim();
                  
                  if (email.isEmpty) {
                    setStateDialog(() => errorText = 'E-posta zorunludur');
                    return;
                  }
                  
                  // Email format validation
                  final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                  if (!emailRegex.hasMatch(email)) {
                    setStateDialog(() => errorText = 'Lütfen geçerli bir e-posta adresi girin');
                    emailFocusNode.requestFocus(); // Focus email field
                    return;
                  }
                  
                  if (passwordController.text.trim().isEmpty) {
                    setStateDialog(() => errorText = 'Şifre zorunludur');
                    return;
                  }
                  if (passwordController.text.trim().length < 6) {
                    setStateDialog(() => errorText = 'Şifre en az 6 karakter olmalıdır');
                    return;
                  }
                  Navigator.pop(context, true);
                },
                child: const Text('Oluştur', style: TextStyle(color: AppColors.primaryYellow)),
              ),
            ],
          );
        }
      ),
    );

    if (result == true) {
      _createTrainer(
        firstNameController.text,
        lastNameController.text,
        usernameController.text,
        emailController.text,
        passwordController.text,
        selectedSpecialty,
      );
    }
  }

  Future<void> _createTrainer(String first, String last, String username, String email, String password, String specialty) async {
    if (mounted) setState(() => _isLoading = true);

    try {
      // 1. Get current admin's profile to retrieve organization_id
      final adminProfile = await _profileRepository.getProfile();
      final orgId = adminProfile?.organizationId;

      if (orgId == null) {
        throw Exception("Salon sahibi bir organizasyona sahip değil.");
      }

      // If username is empty, derive from email or name
      String finalUsername = username;
      if (finalUsername.isEmpty) {
        finalUsername = email.split('@')[0];
      }
      final cleanUsername = finalUsername.trim().replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    
      // 2. Create user with signUp (with password)
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'first_name': first,
          'last_name': last,
          'full_name': '$first $last'.trim(),
          'display_name': '$first $last'.trim(), 
          'username': cleanUsername,
          'role': 'trainer',
          'organization_id': orgId,
          'specialty': specialty,
          'password_changed': false, // Flag that password needs to be changed
        },
      );

      if (response.user == null) {
        throw Exception('Kullanıcı oluşturulamadı');
      }

      // 3. Update the profile with organization_id and password_changed flag
      await _supabase.from('profiles').update({
        'organization_id': orgId,
        'specialty': specialty,
        'password_changed': false,
      }).eq('id', response.user!.id);

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Eğitmen başarıyla oluşturuldu!');
        await Future.delayed(const Duration(seconds: 1)); 
        _loadTrainers();
      }
    } catch (e) {
      debugPrint('Error creating trainer: $e');
      if (mounted) CustomSnackBar.showError(context, 'Hata: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showTrainerActionMenu(Profile trainer) async {
    debugPrint('=== SHOWING TRAINER ACTION MENU for ${trainer.firstName} ${trainer.lastName} ===');
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: Text('${trainer.firstName} ${trainer.lastName}', style: const TextStyle(color: AppColors.primaryYellow)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.accentBlue),
              title: const Text('Uzmanlık Değiştir', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'edit_specialty'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: AppColors.accentRed),
              title: const Text('Sil', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('İptal', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    debugPrint('=== ACTION SELECTED: $action ===');
    
    if (action == 'edit_specialty') {
      await _showChangeSpecialtyDialog(trainer);
    } else if (action == 'delete') {
      await _deleteSingleTrainer(trainer);
    }
  }

  Future<void> _showChangeSpecialtyDialog(Profile trainer) async {
    debugPrint('=== OPENING SPECIALTY DIALOG for ${trainer.firstName} ${trainer.lastName} ===');
    String selectedSpecialty = trainer.specialty ?? 'Personal Trainer';
    final List<String> specialtyOptions = [
      'Personal Trainer',
      'Diyetisyen',
      'Fizyoterapist',
      'PT / Diyetisyen',
      'PT / Fizyoterapist',
      'Yoga Eğitmeni',
      'Pilates Eğitmeni',
    ];

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceDark,
            title: Text('${trainer.firstName} ${trainer.lastName} - Uzmanlık Değiştir', style: const TextStyle(color: AppColors.primaryYellow)),
            content: DropdownButtonFormField<String>(
              value: selectedSpecialty,
              dropdownColor: AppColors.surface,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Yeni Uzmanlık',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
              ),
              items: specialtyOptions.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  setStateDialog(() => selectedSpecialty = newValue);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('İptal', style: TextStyle(color: Colors.white)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, selectedSpecialty),
                child: const Text('Kaydet', style: TextStyle(color: AppColors.primaryYellow)),
              ),
            ],
          );
        }
      ),
    );

    debugPrint('Dialog result: $result, current specialty: ${trainer.specialty}');
    
    if (result != null) {
      // Always update, even if it's the same value (to handle null -> value case)
      await _updateTrainerSpecialty(trainer.id, result);
    }
  }

  Future<void> _updateTrainerSpecialty(String trainerId, String newSpecialty) async {
    if (mounted) setState(() => _isLoading = true);

    try {
      debugPrint('Updating specialty for trainer $trainerId to $newSpecialty');
      
      final response = await _supabase
        .from('profiles')
        .update({'specialty': newSpecialty})
        .eq('id', trainerId)
        .select(); // Add select to see if update happened
      
      debugPrint('Update response: $response');

      if (mounted) {
        CustomSnackBar.showSuccess(context, 'Uzmanlık başarıyla güncellendi');
        await _loadTrainers(); // Reload list to show changes
      }
    } catch (e) {
      debugPrint('Error updating specialty: $e');
      if (mounted) CustomSnackBar.showError(context, 'Hata: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSingleTrainer(Profile trainer) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Eğitmeni Sil', style: TextStyle(color: AppColors.primaryYellow)),
        content: Text(
          '${trainer.firstName} ${trainer.lastName} adlı eğitmeni silmek istediğinize emin misiniz?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) setState(() => _isLoading = true);

      try {
        await _supabase.rpc('delete_user_by_admin', params: {'target_user_id': trainer.id});

        if (mounted) {
          CustomSnackBar.showSuccess(context, 'Eğitmen başarıyla silindi');
          await _loadTrainers();
        }
      } catch (e) {
        debugPrint('Error deleting trainer: $e');
        if (mounted) CustomSnackBar.showError(context, 'Silme hatası: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteSelectedTrainers() async {
    if (_selectedTrainerIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        title: const Text('Seçilenleri Sil', style: TextStyle(color: AppColors.accentRed)),
        content: Text('${_selectedTrainerIds.length} eğitmeni silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hayır', style: TextStyle(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Evet', style: TextStyle(color: AppColors.accentRed)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) setState(() => _isLoading = true);
      try {
        // Iterate and delete each user via RPC (secure deletion of Auth + Profile)
        for (final userId in _selectedTrainerIds) {
          try {
            await _supabase.rpc('delete_user_by_admin', params: {'target_user_id': userId});
          } catch (rpcError) {
             debugPrint('Failed to delete user $userId: $rpcError');
             // If RPC fails (e.g. not admin, or user not found), we might try manual profile delete as fallback
             // but usually RPC is the source of truth.
          }
        }
        
        if (mounted) CustomSnackBar.showSuccess(context, 'Seçilen eğitmenler tamamen silindi.');
        _selectedTrainerIds.clear();
        _loadTrainers();
      } catch (e) {
        if (mounted) CustomSnackBar.showError(context, 'Silme hatası: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: _isSelectionMode 
            ? Text('${_selectedTrainerIds.length} Seçildi', style: const TextStyle(color: Colors.white))
            : const Text('Eğitmenler'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedTrainerIds.clear()),
              )
            : null,
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: AppColors.accentRed),
              onPressed: _deleteSelectedTrainers,
            ),
        ],
      ),
      floatingActionButton: (_isAdmin && !_isSelectionMode)
          ? FloatingActionButton(
              onPressed: _showAddTrainerDialog,
              backgroundColor: AppColors.primaryYellow,
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
      body: AmbientBackground(
        child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadTrainers();
                await _checkBusyStatus();
              },
              color: AppColors.accentOrange,
              backgroundColor: AppColors.surfaceDark,
              child: ListView.separated(
                padding: const EdgeInsets.only(top: kToolbarHeight + 40, left: 20, right: 20, bottom: 20),
                itemCount: _trainers.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final trainer = _trainers[index];
                  return _buildTrainerCard(trainer);
                },
              ),
            ),
      ),
    );
  }

  Widget _buildTrainerCard(Profile trainer) {
    String statusText = 'Offline';
    Color statusColor = AppColors.textSecondary;
    IconData statusIcon = Icons.circle_outlined;

    final isBusy = _busyTrainerIds.contains(trainer.id);
    final isOnline = _onlineUserIds.contains(trainer.id);
    final currentUserId = _supabase.auth.currentUser?.id;

    // Manual status overrides everything if user is online/connected
    // Use local _myStatus for current user for instant feedback
    String? manualStatus;
    if (trainer.id == currentUserId) {
      manualStatus = _myStatus;
    } else {
      manualStatus = _userManualStatuses[trainer.id];
    }
    
    // If we are looking at someone else who is offline, their manualStatus (from presence) will be null.
    // If we are looking at ourselves, _myStatus dictates what we broadcast, but if we are 'offline' (app closed), we wouldn't be seeing this screen.
    // However, if logic says "Derste" but I set "Online", I want to see Online.

    if (manualStatus != null) {
      if (manualStatus == 'busy') {
        statusText = 'Meşgul';
        statusColor = AppColors.accentRed;
        statusIcon = Icons.remove_circle_rounded;
      } else if (manualStatus == 'away') {
        statusText = 'Dışarıda';
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_filled_rounded;
      } else if (manualStatus == 'online') {
        statusText = 'Online';
        statusColor = AppColors.accentGreen;
        statusIcon = Icons.check_circle_rounded;
      }
    } else {
       // ... fallback
    }

    if (manualStatus != null) {
      if (manualStatus == 'busy') {
        statusText = 'Meşgul';
        statusColor = AppColors.accentRed;
        statusIcon = Icons.remove_circle_rounded;
      } else if (manualStatus == 'away') {
        statusText = 'Dışarıda';
        statusColor = Colors.orange;
        statusIcon = Icons.access_time_filled_rounded;
      } else {
        // 'online' or unknown
        statusText = 'Online';
        statusColor = AppColors.accentGreen;
        statusIcon = Icons.check_circle_rounded;
      }
    } else {
      // Automatic fallback
      if (isBusy) {
        statusText = 'Derste';
        statusColor = AppColors.accentRed;
        statusIcon = Icons.do_not_disturb_on_rounded;
      } else if (isOnline) {
        statusText = 'Online';
        statusColor = AppColors.accentGreen;
        statusIcon = Icons.check_circle_rounded;
      }
    }

    final isSelected = _selectedTrainerIds.contains(trainer.id);

    return GlassCard(
      backgroundColor: isSelected ? AppColors.primaryYellow.withOpacity(0.1) : null,
      border: isSelected ? Border.all(color: AppColors.primaryYellow) : null,
      child: ListTile(
        onTap: () {
          if (_isSelectionMode) {
             if (!_isAdmin) return; // Only admin can select
             setState(() {
               if (isSelected) {
                 _selectedTrainerIds.remove(trainer.id);
               } else {
                 _selectedTrainerIds.add(trainer.id);
               }
             });
          } else {
             // Navigate to Chat Screen
             final currentUserId = _supabase.auth.currentUser?.id;
             if (currentUserId != trainer.id) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatScreen(otherUser: trainer)),
                );
             }
          }
        },
        onLongPress: _isAdmin ? () {
          if (_isSelectionMode) {
            // In selection mode: toggle selection
            setState(() {
              if (isSelected) {
                _selectedTrainerIds.remove(trainer.id);
              } else {
                _selectedTrainerIds.add(trainer.id);
              }
            });
          } else {
            // Not in selection mode: show action menu (Edit/Delete)
            _showTrainerActionMenu(trainer);
          }
        } : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.accentOrange,
              backgroundImage: trainer.avatarUrl != null 
                  ? NetworkImage(trainer.avatarUrl!) 
                  : null,
              child: trainer.avatarUrl == null
                  ? Text(
                      ((trainer.firstName?[0] ?? '') + (trainer.lastName?[0] ?? '')).toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceDark, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          '${trainer.firstName ?? ''} ${trainer.lastName ?? ''}'.trim().isEmpty 
              ? 'İsimsiz Eğitmen' 
              : '${trainer.firstName ?? ''} ${trainer.lastName ?? ''}',
          style: AppTextStyles.headline,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Priority 1: Role Label (Owner) or Specialty
            if (trainer.role == 'owner')
              Text(
                'Salon Sahibi',
                style: AppTextStyles.caption1.copyWith(color: AppColors.primaryYellow, fontWeight: FontWeight.bold),
              )
            else if (trainer.specialty != null && trainer.specialty!.isNotEmpty)
              Text(
                trainer.specialty!,
                style: AppTextStyles.caption1.copyWith(color: AppColors.primaryYellow, fontWeight: FontWeight.bold),
              )
            else
               Text(
                'Eğitmen',
                style: AppTextStyles.caption1.copyWith(color: Colors.grey),
              ),
            
            // Priority 2: Profession (Background info)
            if (trainer.profession != null && trainer.profession!.isNotEmpty)
               Text(
                trainer.profession!,
                style: AppTextStyles.caption2.copyWith(color: AppColors.textSecondary),
              ),
          ],
        ),


        trailing: _isSelectionMode 
          ? Checkbox(
              value: isSelected,
              activeColor: AppColors.primaryYellow,
              checkColor: Colors.black,
              onChanged: _isAdmin ? (val) {
                setState(() {
                   if (val == true) {
                     _selectedTrainerIds.add(trainer.id);
                   } else {
                     _selectedTrainerIds.remove(trainer.id);
                   }
                });
              } : null,
            )
          : GestureDetector(
              onTap: () {
                // Only allow changing own status
                final currentUserId = _supabase.auth.currentUser?.id;
                if (currentUserId == trainer.id) {
                  _showStatusPicker();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: AppTextStyles.caption1.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold
                      ),
                    ),
                    if (_supabase.auth.currentUser?.id == trainer.id) ...[
                       const SizedBox(width: 4),
                       Icon(Icons.edit, size: 10, color: statusColor.withOpacity(0.7)),
                    ],
                  ],
                ),
              ),
            ),
      ),
    );
  }


  void _showStatusPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceDark,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.circle, color: AppColors.accentGreen),
            title: const Text('Online', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _setMyStatus('online');
            },
          ),
          ListTile(
            leading: const Icon(Icons.remove_circle, color: AppColors.accentRed),
            title: const Text('Meşgul', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _setMyStatus('busy');
            },
          ),
          ListTile(
            leading: const Icon(Icons.access_time_filled, color: Colors.orange),
            title: const Text('Dışarıda', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              _setMyStatus('away');
            },
          ),
        ],
      ),
    );
  }
}
