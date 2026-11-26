import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../models/role_permission.dart';
import 'login_screen.dart';
import 'reports_export_screen.dart';
import 'admin_users_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยืนยันการออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: AppColors.textMuted)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.logout();
              if (!context.mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('ออกจากระบบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileBottomSheet(BuildContext context, AppState appState, UserModel user) {
    final nameController = TextEditingController(text: user.name);
    final phoneController = TextEditingController(text: user.phoneNumber ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'แก้ไขโปรไฟล์',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Avatar with Camera Icon Overlay
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          user.avatarUrl,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Read-only Info Badges (Role, Employee ID, Team)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildReadOnlyInfoItem('รหัสพนักงาน', user.id),
                      Container(width: 1, height: 28, color: AppColors.cardBorder),
                      _buildReadOnlyInfoItem('Role', user.role),
                      Container(width: 1, height: 28, color: AppColors.cardBorder),
                      _buildReadOnlyInfoItem('ทีม', user.team?.label ?? 'N/A'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Editable Fields
                const Text(
                  'ชื่อ-นามสกุล',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'กรอกชื่อ-นามสกุล',
                    prefixIcon: Icon(Icons.person_outline, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'กรุณากรอกชื่อ-นามสกุล';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                const Text(
                  'เบอร์โทรศัพท์',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: 'เช่น 081-234-5678',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'กรุณากรอกเบอร์โทรศัพท์';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Buttons Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.cardBorder),
                          foregroundColor: AppColors.textSecondary,
                        ),
                        child: const Text('ยกเลิก'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            try {
                              await appState.updateUserProfile(
                                name: nameController.text.trim(),
                                phoneNumber: phoneController.text.trim(),
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('อัปเดตข้อมูลโปรไฟล์เรียบร้อยแล้ว'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('อัปเดตโปรไฟล์ไม่สำเร็จ: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        child: const Text('บันทึก'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadOnlyInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildMyTeamCard(BuildContext context, AppState appState, UserModel user) {
    final status = user.teamStatus ?? 'approved';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ทีมของฉัน (My Team)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              if (status != 'pending')
                OutlinedButton.icon(
                  onPressed: () => _showRequestTeamDialog(context, appState),
                  icon: const Icon(Icons.swap_horiz, size: 16, color: AppColors.primary),
                  label: const Text('ขอเปลี่ยนทีม', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.groups_outlined, color: AppColors.textSecondary, size: 20),
              const SizedBox(width: 10),
              Text(
                user.team?.label ?? 'ยังไม่มีทีมสังกัด',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('สถานะคำขอ: ', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: status == 'approved'
                      ? Colors.green.shade100
                      : status == 'rejected'
                          ? Colors.red.shade100
                          : Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: status == 'approved'
                        ? Colors.green.shade800
                        : status == 'rejected'
                            ? Colors.red.shade800
                            : Colors.amber.shade800,
                  ),
                ),
              ),
            ],
          ),
          if (status == 'pending') ...[
            const SizedBox(height: 8),
            const Text(
              'คำขอเปลี่ยนทีมของคุณกำลังรอการอนุมัติจากผู้ดูแลระบบ',
              style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.w500),
            ),
          ] else if (status == 'rejected') ...[
            const SizedBox(height: 8),
            const Text(
              'คำขอเปลี่ยนทีมก่อนหน้าไม่ได้รับการอนุมัติ คุณสามารถส่งคำขอใหม่ได้',
              style: TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w500),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRequestTeamDialog(BuildContext context, AppState appState) async {
    try {
      final teamsRes = await Supabase.instance.client
          .from('teams')
          .select('id, name')
          .eq('is_active', true)
          .order('name');

      final teams = List<Map<String, dynamic>>.from(teamsRes);
      if (teams.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลทีมที่เปิดใช้งานในระบบ'), backgroundColor: Colors.orange),
        );
        return;
      }

      String? selectedTeamId = teams.first['id'];

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('ส่งคำขอเปลี่ยนทีม'),
          content: StatefulBuilder(
            builder: (context, setDialogState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('เลือกทีมที่ต้องการเข้าร่วม:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: teams.any((t) => t['id'] == selectedTeamId) ? selectedTeamId : teams.first['id'] as String?,
                  items: teams.map((t) {
                    return DropdownMenuItem<String>(
                      value: t['id'] as String,
                      child: Text(t['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedTeamId = val);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ยืนยันส่งคำขอ'),
            ),
          ],
        ),
      );

      if (confirm == true && selectedTeamId != null) {
        final success = await appState.requestTeam(selectedTeamId!);
        if (!context.mounted) return;
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ส่งคำขอเปลี่ยนทีมเรียบร้อยแล้ว รอ Admin อนุมัติ'), backgroundColor: Colors.green),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เกิดข้อผิดพลาดในการส่งคำขอ'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final user = appState.currentUser;

    // Calculate user-specific statistics dynamically (Case & Order)
    final myCasesCount = appState.cases.where((c) => RolePermissionHelper.canAccessCase(user, c)).length;
    final myOrdersCount = appState.orders.where((o) => OrderRolePermissionHelper.canAccessOrder(user, o)).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'โปรไฟล์',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Profile Header
            _buildProfileHeaderCard(context, appState, user),
            const SizedBox(height: 20),

            // Section 1.5: My Team & Request Change
            _buildMyTeamCard(context, appState, user),
            const SizedBox(height: 20),

            // Section 2: Summary Statistics (Exactly 2 concise items: เคสทั้งหมด & ออเดอร์ทั้งหมด)
            _buildSectionHeader('ภาพรวมสถิติของฉัน'),
            const SizedBox(height: 10),
            _buildStatisticsGrid(
              myCasesCount: myCasesCount,
              myOrdersCount: myOrdersCount,
            ),
            const SizedBox(height: 20),

            // Section 3: Account Information
            _buildSectionHeader('ข้อมูลบัญชี'),
            const SizedBox(height: 10),
            _buildAccountInfoCard(context, appState, user),
            const SizedBox(height: 20),

            // Section 4: Account Settings
            _buildSectionHeader('การตั้งค่าบัญชี'),
            const SizedBox(height: 10),
            _buildAccountSettingsCard(context, appState),
            const SizedBox(height: 20),

            // App Version Footer
            Center(
              child: Text(
                'DevIncident v${AppConfig.version}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildProfileHeaderCard(BuildContext context, AppState appState, UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          // Avatar
          CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.primary,
            child: Text(
              user.avatarUrl,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Name
          Text(
            user.name,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),

          // Position
          Text(
            user.position ?? user.role,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),

          // Badges (Role & Team)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              _buildRoleBadge(user.roleEnum),
              if (user.team != null) _buildTeamBadge(user.team!),
            ],
          ),
          const SizedBox(height: 10),

          // Email
          Text(
            user.email,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 16),

          // Edit Profile Button
          SizedBox(
            height: 38,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfileBottomSheet(context, appState, user),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
              label: const Text(
                'แก้ไขโปรไฟล์',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    Color bg = const Color(0xFFEFF6FF);
    Color text = const Color(0xFF2563EB);

    switch (role) {
      case UserRole.admin:
        bg = const Color(0xFFF3E8FF);
        text = const Color(0xFF9333EA);
        break;
      case UserRole.teamLead:
        bg = const Color(0xFFFEF3C7);
        text = const Color(0xFFD97706);
        break;
      case UserRole.developer:
        bg = const Color(0xFFDBEAFE);
        text = const Color(0xFF1D61E7);
        break;
      case UserRole.user:
        bg = const Color(0xFFDCFCE7);
        text = const Color(0xFF16A34A);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTeamBadge(TeamType team) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: team.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            team.label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsGrid({
    required int myCasesCount,
    required int myOrdersCount,
  }) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'เคสทั้งหมด',
            value: '$myCasesCount',
            icon: Icons.assignment_outlined,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFEFF6FF),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            title: 'ออเดอร์ทั้งหมด',
            value: '$myOrdersCount',
            icon: Icons.local_shipping_outlined,
            iconColor: const Color(0xFF16A34A),
            iconBg: const Color(0xFFDCFCE7),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfoCard(BuildContext context, AppState appState, UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.badge_outlined,
            label: 'Employee ID',
            value: user.id,
            isReadOnly: true,
          ),
          const Divider(height: 1, indent: 50, color: AppColors.cardBorder),
          _buildInfoRow(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: user.name,
            onTapEdit: () => _showEditProfileBottomSheet(context, appState, user),
          ),
          const Divider(height: 1, indent: 50, color: AppColors.cardBorder),
          _buildInfoRow(
            icon: Icons.email_outlined,
            label: 'Company Email',
            value: user.email,
            isReadOnly: true,
          ),
          const Divider(height: 1, indent: 50, color: AppColors.cardBorder),
          _buildInfoRow(
            icon: Icons.phone_outlined,
            label: 'Phone Number',
            value: user.phoneNumber ?? '081-234-5678',
            onTapEdit: () => _showEditProfileBottomSheet(context, appState, user),
          ),
          const Divider(height: 1, indent: 50, color: AppColors.cardBorder),
          _buildInfoRow(
            icon: Icons.work_outline,
            label: 'Job Position',
            value: user.position ?? user.role,
            isReadOnly: true,
          ),
          const Divider(height: 1, indent: 50, color: AppColors.cardBorder),
          _buildInfoRow(
            icon: Icons.groups_outlined,
            label: 'Team',
            value: user.team?.label ?? 'General Team',
            isReadOnly: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isReadOnly = false,
    VoidCallback? onTapEdit,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title: Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      trailing: isReadOnly
          ? const Tooltip(
              message: 'อ่านได้อย่างเดียว (ผู้ดูแลระบบจัดตั้ง)',
              child: Icon(Icons.lock_outline, size: 16, color: AppColors.textMuted),
            )
          : IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              onPressed: onTapEdit,
            ),
    );
  }

  Widget _buildAccountSettingsCard(BuildContext context, AppState appState) {
    final user = appState.currentUser;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          if (user.roleEnum == UserRole.admin) ...[
            _buildSettingsMenuItem(
              icon: Icons.admin_panel_settings_outlined,
              title: 'จัดการสมาชิกและการอนุมัติทีม',
              subtitle: 'อนุมัติหรือปฏิเสธคำขอทีมของสมาชิก',
              iconColor: Colors.purple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminUsersScreen(),
                  ),
                );
              },
            ),
            const Divider(height: 1, indent: 50, color: AppColors.cardBorder),
          ],
          _buildSettingsMenuItem(
            icon: Icons.bar_chart_outlined,
            title: 'Reports & Export',
            subtitle: 'สรุปและส่งออกรายงานเคสและออเดอร์ (PDF / CSV)',
            iconColor: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReportsExportScreen(),
                ),
              );
            },
          ),
          const Divider(height: 1, indent: 50, color: AppColors.cardBorder),
          _buildSettingsMenuItem(
            icon: Icons.lock_outline,
            title: 'Change Password',
            subtitle: 'เปลี่ยนรหัสผ่านเข้าใช้งาน',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ฟังก์ชันเปลี่ยนรหัสผ่าน')),
              );
            },
          ),
          const Divider(height: 1, indent: 50, color: AppColors.cardBorder),
          _buildSettingsMenuItem(
            icon: Icons.notifications_none,
            title: 'Notification Settings',
            subtitle: 'ตั้งค่าการรับการแจ้งเตือน',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ตั้งค่าการแจ้งเตือน')),
              );
            },
          ),
          const Divider(height: 1, indent: 50, color: AppColors.cardBorder),
          _buildSettingsMenuItem(
            icon: Icons.palette_outlined,
            title: 'Theme Settings',
            subtitle: 'ปรับแต่งธีมและการแสดงผล',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ตั้งค่าธีมการแสดงผล')),
              );
            },
          ),
          const Divider(height: 1, indent: 50, color: AppColors.cardBorder),
          _buildSettingsMenuItem(
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'ออกจากระบบเข้าใช้งาน',
            textColor: Colors.red,
            iconColor: Colors.red,
            showArrow: false,
            onTap: () => _showLogoutDialog(context, appState),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color textColor = AppColors.textPrimary,
    Color iconColor = AppColors.textSecondary,
    bool showArrow = true,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 22),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
      ),
      trailing: showArrow
          ? const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20)
          : null,
      onTap: onTap,
    );
  }
}
