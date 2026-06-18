import 'package:go_router/go_router.dart';
import 'package:buildacre_crm/features/auth/screens/login_screen.dart';
import 'package:buildacre_crm/features/leads/screens/leads_list_screen.dart';
import 'package:buildacre_crm/features/leads/screens/lead_detail_screen.dart';
import 'package:buildacre_crm/features/leads/screens/add_lead_screen.dart';
import 'package:buildacre_crm/features/leads/screens/kanban_screen.dart';
import 'package:buildacre_crm/features/leads/screens/call_queue_screen.dart';
import 'package:buildacre_crm/features/leads/screens/assignment_screen.dart';
import 'package:buildacre_crm/features/leads/screens/search_screen.dart';
import 'package:buildacre_crm/features/leads/screens/followup_calendar_screen.dart';
import 'package:buildacre_crm/features/leads/screens/lead_timeline_screen.dart';
import 'package:buildacre_crm/features/leads/screens/edit_lead_screen.dart';
import 'package:buildacre_crm/features/leads/screens/lost_leads_screen.dart';
import 'package:buildacre_crm/features/leads/screens/future_pipeline_screen.dart';
import 'package:buildacre_crm/features/dashboard/screens/dashboard_screen.dart';
import 'package:buildacre_crm/features/dashboard/screens/performance_screen.dart';
import 'package:buildacre_crm/features/dashboard/screens/city_analytics_screen.dart';
import 'package:buildacre_crm/features/dashboard/screens/reports_screen.dart';
import 'package:buildacre_crm/features/calls/screens/recordings_screen.dart';
import 'package:buildacre_crm/features/settings/screens/settings_screen.dart';
import 'package:buildacre_crm/features/notifications/screens/notifications_screen.dart';
import 'package:buildacre_crm/features/settings/screens/profile_screen.dart';
import 'package:buildacre_crm/features/telecaller/screens/my_performance_screen.dart';
import 'package:buildacre_crm/shared/widgets/main_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/leads',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LeadsListScreen()),
          routes: [
            GoRoute(
              path: 'add',
              builder: (context, state) => const AddLeadScreen(),
            ),
            GoRoute(
              path: 'kanban',
              builder: (context, state) => const KanbanScreen(),
            ),
            GoRoute(
              path: 'assign',
              builder: (context, state) => const AssignmentScreen(),
            ),
            GoRoute(
              path: 'search',
              builder: (context, state) => const SearchScreen(),
            ),
            GoRoute(
              path: 'lost',
              builder: (context, state) => const LostLeadsScreen(),
            ),
            GoRoute(
              path: 'future',
              builder: (context, state) => const FuturePipelineScreen(),
            ),
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  LeadDetailScreen(leadId: state.pathParameters['id']!),
              routes: [
                GoRoute(
                  path: 'timeline',
                  builder: (context, state) =>
                      LeadTimelineScreen(leadId: state.pathParameters['id']!),
                ),
                GoRoute(
                  path: 'edit',
                  builder: (context, state) =>
                      EditLeadScreen(leadId: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/queue',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CallQueueScreen()),
        ),
        GoRoute(
          path: '/calendar',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: FollowupCalendarScreen()),
        ),
        GoRoute(
          path: '/dashboard',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: DashboardScreen()),
          routes: [
            GoRoute(
              path: 'performance',
              builder: (context, state) => const PerformanceScreen(),
            ),
            GoRoute(
              path: 'recordings',
              builder: (context, state) => const RecordingsScreen(),
            ),
            GoRoute(
              path: 'city',
              builder: (context, state) => const CityAnalyticsScreen(),
            ),
            GoRoute(
              path: 'reports',
              builder: (context, state) => const ReportsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '/my-performance',
          builder: (context, state) => const MyPerformanceScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    ),
  ],
);
