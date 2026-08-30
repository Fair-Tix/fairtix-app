import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/admin_session.dart';
import '../organizer/app_colors.dart';
import 'admin-dashboard.dart';
import 'admin-login.dart';
import 'admin-route.dart';
import 'admin-accounts.dart';
import 'admin-events-tickets.dart';
import 'admin-fraud-alerts.dart';
import 'admin-resale-monitoring.dart';
import 'admin-revenue-reports.dart';
import 'admin-platform-settings.dart';
import 'admin-profile.dart';

class AdminOrganizerApplicationsScreen extends StatefulWidget {
  const AdminOrganizerApplicationsScreen({super.key});

  static String statusLabelFor(String? status) {
    switch ((status ?? 'pending').toLowerCase()) {
      case 'verified':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'pending':
      default:
        return 'Pending';
    }
  }

  static bool matchesFilter(Map<String, dynamic> row, int filterIndex) {
    final status = (row['id_verification_status'] as String?) ?? 'pending';
    switch (filterIndex) {
      case 0:
        return true;
      case 1:
        return status == 'pending';
      case 2:
        return status == 'verified';
      case 3:
        return status == 'rejected';
      default:
        return true;
    }
  }

  static bool isOrganizerApplicationCandidate(Map<String, dynamic> row) {
    final role = (row['role'] as String?)?.trim().toLowerCase();
    final organizationName = (row['organization_name'] as String?)?.trim();
    final venueProofUrl = (row['venue_proof_url'] as String?)?.trim();
    final eventPermitUrl = (row['event_permit_url'] as String?)?.trim();
    final fullName = (row['full_name'] as String?)?.trim();
    final verificationStatus = (row['id_verification_status'] as String?)?.trim().toLowerCase();

    if (role == 'organizer') {
      return true;
    }

    final hasOrganizerProfile = ((organizationName != null && organizationName.isNotEmpty) ||
        (fullName != null && fullName.isNotEmpty && organizationName == null));
    final hasVerificationFiles = (venueProofUrl != null && venueProofUrl.isNotEmpty) ||
        (eventPermitUrl != null && eventPermitUrl.isNotEmpty);
    final isPendingOrganizerSubmission =
        verificationStatus == null || verificationStatus == 'pending';

    return (hasOrganizerProfile || hasVerificationFiles) && isPendingOrganizerSubmission;
  }

  @override
  State<AdminOrganizerApplicationsScreen> createState() =>
      _AdminOrganizerApplicationsScreenState();
}

class _AdminOrganizerApplicationsScreenState
    extends State<AdminOrganizerApplicationsScreen> {
  int _filterIndex = 1;
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _applications = const [];

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final primaryRows = await Supabase.instance.client
          .from('users')
          .select()
          .eq('role', 'organizer')
          .order('created_at', ascending: false);

      final applications = primaryRows
          .map<Map<String, dynamic>>(
            (row) => Map<String, dynamic>.from(row as Map),
          )
          .where(AdminOrganizerApplicationsScreen.isOrganizerApplicationCandidate)
          .toList();

      setState(() {
        _applications = applications;
        _isLoading = false;
      });
      return;
    } on PostgrestException catch (error) {
      // Some older or partially-migrated rows may have stale role metadata,
      // so fall back to a broader organizer-like scan instead of showing an
      // empty queue for a valid organizer submission.
      try {
        final fallbackRows = await Supabase.instance.client
            .from('users')
            .select()
            .or('role.eq.organizer,organization_name.not.is.null,venue_proof_url.not.is.null,event_permit_url.not.is.null')
            .order('created_at', ascending: false);

        setState(() {
          _applications = fallbackRows
              .map<Map<String, dynamic>>(
                (row) => Map<String, dynamic>.from(row as Map),
              )
              .where(AdminOrganizerApplicationsScreen.isOrganizerApplicationCandidate)
              .toList();
          _isLoading = false;
        });
      } catch (fallbackError) {
        final details = fallbackError is PostgrestException ? fallbackError.message : fallbackError.toString();
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unable to load organizer applications right now: $details';
        });
      }
      return;
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load organizer applications right now: ${error.toString()}';
      });
    }
  }

  Future<void> _updateApplicationStatus(
    Map<String, dynamic> row,
    String nextStatus,
  ) async {
    final id = row['id'];
    if (id == null) {
      return;
    }

    try {
      await Supabase.instance.client
          .from('users')
          .update({'id_verification_status': nextStatus}).eq('id', id);

      if (!mounted) {
        return;
      }

      setState(() {
        _applications = _applications.map((current) {
          if (current['id'] == id) {
            return {...current, 'id_verification_status': nextStatus};
          }
          return current;
        }).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_fullName(row)} was ${nextStatus == 'verified' ? 'approved' : 'rejected'}.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to update this organizer application.'),
        ),
      );
    }
  }

  String _fullName(Map<String, dynamic> row) {
    final name = (row['full_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return (row['organization_name'] as String?)?.trim() ?? 'Organizer';
  }

  String _submissionLabel(Map<String, dynamic> row) {
    final createdAt = row['created_at'];
    if (createdAt is String && createdAt.isNotEmpty) {
      final date = DateTime.tryParse(createdAt);
      if (date != null) {
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      }
    }
    return 'Recently';
  }

  String _documentSummary(Map<String, dynamic> row) {
    final hasVenueProof = (row['venue_proof_url'] as String?)?.isNotEmpty == true;
    final hasPermit = (row['event_permit_url'] as String?)?.isNotEmpty == true;
    if (hasVenueProof && hasPermit) {
      return '2 files';
    }
    if (hasVenueProof || hasPermit) {
      return '1 file';
    }
    return 'No files';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
        return const Color(0xFFEBF9F1);
      case 'rejected':
        return const Color(0xFFFDEDEC);
      case 'pending':
      default:
        return const Color(0xFFF3F0FF);
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'verified':
        return const Color(0xFF1F8F52);
      case 'rejected':
        return const Color(0xFFB42318);
      case 'pending':
      default:
        return AppColors.primaryPurple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FC),
      drawer: isWide ? null : Drawer(child: _buildSidebar()),
      body: Row(
        children: [
          if (isWide) SizedBox(width: 180, child: _buildSidebar()),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isWide),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isWide ? 18 : 14),
                    child: _buildContent(isWide),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    final currentEmail =
        AdminSession.instance.currentEmail ?? 'admin@fairtix.com';
    final items = [
      (Icons.grid_view_rounded, 'Dashboard'),
      (Icons.business_outlined, 'Organizer Applications'),
      (Icons.people_outline, 'Accounts'),
      (Icons.calendar_today_outlined, 'Events & Tickets'),
      (Icons.swap_vert_rounded, 'Resale Monitoring'),
      (Icons.shield_outlined, 'Fraud Alerts'),
      (Icons.bar_chart_rounded, 'Revenue & Reports'),
      (Icons.settings_outlined, 'Platform Settings'),
      (Icons.person_outline, 'Profile'),
    ];
    return Container(
      color: const Color(0xFFF3F1FD),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 12, 18),
              child: _AdminLogo(),
            ),
            const Divider(height: 1, color: AppColors.borderLight),
            const SizedBox(height: 14),
            for (var index = 0; index < items.length; index++)
              _SidebarItem(
                icon: items[index].$1,
                label: items[index].$2,
                selected: index == 1,
                onTap: () {
                  if (index == 0) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminDashboardScreen()),
                    );
                  } else if (index == 2) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminAccountsScreen()),
                    );
                  } else if (index == 3) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminEventsTicketsScreen()),
                    );
                  } else if (index == 4) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminResaleMonitoringScreen()),
                    );
                  } else if (index == 5) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminFraudAlertsScreen()),
                    );
                  } else if (index == 6) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminRevenueReportsScreen()),
                    );
                  } else if (index == 7) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminPlatformSettingsScreen()),
                    );
                  } else if (index == 8) {
                    Navigator.pushReplacement(
                      context,
                      adminPageRoute(const AdminProfileScreen()),
                    );
                  }
                },
              ),
            const Spacer(),
            const Divider(height: 1, color: AppColors.borderLight),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 15,
                    backgroundColor: Color(0xFFE8E6F1),
                    child: Icon(
                      Icons.person,
                      size: 17,
                      color: AppColors.textGray,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Admin', style: AppTextStyles.label),
                        Text(
                          currentEmail,
                          style: const TextStyle(
                            color: AppColors.textGray,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _confirmLogout,
                    icon: const Icon(
                      Icons.logout,
                      size: 17,
                      color: AppColors.textGray,
                    ),
                    tooltip: 'Log out',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isWide) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.menu, size: 20),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          Text('Organizer Applications', style: AppTextStyles.label),
          const Spacer(),
          SizedBox(
            width: isWide ? 270 : 130,
            height: 32,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search users, events...',
                hintStyle: const TextStyle(
                  color: Color(0xFFA6A9B7),
                  fontSize: 10,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 16,
                  color: Color(0xFFA6A9B7),
                ),
                filled: true,
                fillColor: const Color(0xFFF3F3F6),
                contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Icon(
            Icons.notifications_none,
            size: 19,
            color: AppColors.textGray,
          ),
          const SizedBox(width: 14),
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFFE8E6F1),
            child: Icon(Icons.person, size: 16, color: AppColors.textGray),
          ),
          if (isWide) ...[
            const SizedBox(width: 8),
            Text(
              AdminSession.instance.currentEmail ?? 'admin@fairtix.com',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.keyboard_arrow_down, size: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildContent(bool isWide) {
    const filters = ['All', 'Pending', 'Approved', 'Rejected'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Organizer Applications', style: AppTextStyles.h2),
            ),
            OutlinedButton.icon(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('There is no application data to export.'),
                ),
              ),
              icon: const Icon(Icons.download_outlined, size: 14),
              label: const Text('Export CSV', style: TextStyle(fontSize: 10)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
                side: const BorderSide(color: AppColors.primaryPurple),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (var index = 0; index < filters.length; index++)
              ChoiceChip(
                label: Text(filters[index]),
                selected: _filterIndex == index,
                onSelected: (_) => setState(() => _filterIndex = index),
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: _filterIndex == index
                      ? Colors.white
                      : AppColors.textGray,
                  fontWeight: FontWeight.w600,
                ),
                selectedColor: AppColors.primaryPurple,
                backgroundColor: const Color(0xFFF0EEFA),
                side: BorderSide.none,
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          constraints: const BoxConstraints(minHeight: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: isWide ? _buildWideTable() : _buildCompactTable(),
        ),
      ],
    );
  }

  Widget _buildWideTable() {
    const headers = [
      'Applicant Name',
      'Email',
      'Org Type',
      'Submitted',
      'Documents',
      'Status',
      '',
    ];

    final visibleApplications = _applications
        .where((app) => AdminOrganizerApplicationsScreen.matchesFilter(app, _filterIndex))
        .toList();

    if (_isLoading) {
      return const SizedBox(
        height: 380,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 380,
        child: Center(
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: AppColors.textGray, fontSize: 12),
          ),
        ),
      );
    }

    return SizedBox(
      height: 380,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFFBFBFD),
            child: Row(
              children: [
                for (final header in headers)
                  Expanded(
                    child: Text(
                      header,
                      style: const TextStyle(
                        color: AppColors.textGray,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: visibleApplications.isEmpty
                ? const _EmptyApplications()
                : ListView.separated(
                    itemCount: visibleApplications.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final application = visibleApplications[index];
                      final status = (application['id_verification_status'] as String?) ?? 'pending';
                      final statusLabel = AdminOrganizerApplicationsScreen.statusLabelFor(status);

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _fullName(application),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                (application['email'] as String?) ?? '—',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                (application['organization_name'] as String?)?.trim().isNotEmpty == true
                                    ? (application['organization_name'] as String).trim()
                                    : 'Independent',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _submissionLabel(application),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _documentSummary(application),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _statusColor(status),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  statusLabel,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _statusTextColor(status),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _updateApplicationStatus(application, 'rejected'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFFB42318),
                                    ),
                                    child: const Text('Reject', style: TextStyle(fontSize: 10)),
                                  ),
                                  const SizedBox(width: 6),
                                  FilledButton(
                                    onPressed: () => _updateApplicationStatus(application, 'verified'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primaryPurple,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    child: const Text('Approve', style: TextStyle(fontSize: 10)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: const [
                Text(
                  'Previous',
                  style: TextStyle(color: Color(0xFFB4B5C0), fontSize: 10),
                ),
                SizedBox(width: 24),
                Text(
                  'Page 1 of 1',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 24),
                Text(
                  'Next',
                  style: TextStyle(color: Color(0xFFB4B5C0), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactTable() {
    final visibleApplications = _applications
        .where((app) => AdminOrganizerApplicationsScreen.matchesFilter(app, _filterIndex))
        .toList();

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (visibleApplications.isEmpty) {
      return const Padding(padding: EdgeInsets.all(18), child: _EmptyApplications());
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: visibleApplications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final application = visibleApplications[index];
          final status = (application['id_verification_status'] as String?) ?? 'pending';
          final statusLabel = AdminOrganizerApplicationsScreen.statusLabelFor(status);
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9FC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _fullName(application),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: _statusColor(status),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color: _statusTextColor(status),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text((application['email'] as String?) ?? '—', style: const TextStyle(fontSize: 11)),
                const SizedBox(height: 6),
                Text(
                  (application['organization_name'] as String?)?.trim().isNotEmpty == true
                      ? (application['organization_name'] as String).trim()
                      : 'Independent',
                  style: const TextStyle(color: AppColors.textGray, fontSize: 10),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => _updateApplicationStatus(application, 'rejected'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFB42318)),
                      child: const Text('Reject', style: TextStyle(fontSize: 10)),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => _updateApplicationStatus(application, 'verified'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryPurple,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: const Text('Approve', style: TextStyle(fontSize: 10)),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to Log Out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (!mounted || shouldLogout != true) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  }
}

class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.inbox_outlined, size: 34, color: Colors.grey.shade300),
        const SizedBox(height: 10),
        const Text(
          'No organizer applications yet',
          style: TextStyle(color: AppColors.textGray, fontSize: 12),
        ),
        const SizedBox(height: 4),
        const Text(
          'Applications will appear here when organizers apply.',
          style: TextStyle(color: Color(0xFFA6A9B7), fontSize: 10),
        ),
      ],
    ),
  );
}

class _AdminLogo extends StatelessWidget {
  const _AdminLogo();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primaryPurple,
          borderRadius: BorderRadius.circular(5),
        ),
        child: const Icon(
          Icons.confirmation_number_outlined,
          color: Colors.white,
          size: 14,
        ),
      ),
      const SizedBox(width: 6),
      const Text(
        'FairTix',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
        ),
      ),
      const SizedBox(width: 3),
      const Text(
        'ADMIN',
        style: TextStyle(fontSize: 8, color: AppColors.textGray),
      ),
    ],
  );
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? AppColors.primaryPurple : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: selected ? Colors.white : AppColors.textDark,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.textDark,
                      fontSize: 10,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
