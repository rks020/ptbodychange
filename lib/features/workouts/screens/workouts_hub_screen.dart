import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../classes/screens/class_schedule_screen.dart';
// Will add these imports later as we create the screens
import 'exercise_library_screen.dart';
import 'workout_templates_screen.dart';

class WorkoutsHubScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProfile;
  final VoidCallback? onNavigateToMembers;
  const WorkoutsHubScreen({super.key, this.onNavigateToProfile, this.onNavigateToMembers});

  @override
  State<WorkoutsHubScreen> createState() => _WorkoutsHubScreenState();
}

class _WorkoutsHubScreenState extends State<WorkoutsHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Antrenman Yönetimi', style: AppTextStyles.headline),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.center,
          indicatorColor: AppColors.primaryYellow,
          labelColor: AppColors.primaryYellow,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Grup Dersleri'),
            Tab(text: 'Programlar'),
            Tab(text: 'Hareketler'),
          ],
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is OverscrollNotification) {
                // Right OverScroll (on last tab) -> Go to Profile
                if (notification.overscroll > 0 && _tabController.index == 2) {
                   widget.onNavigateToProfile?.call();
                }
                // Left OverScroll (on first tab) -> Go to Members
                else if (notification.overscroll < 0 && _tabController.index == 0) {
                   widget.onNavigateToMembers?.call();
                }
              }
              return false;
            },
            child: TabBarView(
              controller: _tabController,
              physics: const BouncingScrollPhysics(), // Important for overscroll
              children: [
                // 1. Existing Class Schedule Screen
                const ClassScheduleScreen(isEmbedded: true), 
                
                // 2. Workout Templates Screen
                const WorkoutTemplatesScreen(),
                
                // 3. Exercise Library Screen
                const ExerciseLibraryScreen(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
