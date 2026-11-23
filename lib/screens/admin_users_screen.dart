import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  List<Map<String, dynamic>> _profiles = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Search & Filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterRole = 'all';
  String _filterStatus = 'all';
  String _filterActive = 'all';

  @override
  void initState() {
    super.initState();
    _fetchProfiles();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfiles() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('*, teams!profiles_team_id_fkey(name, code), requested_team:teams!profiles_requested_team_id_fkey(name, code)')
          .order('created_at', ascending: false);

      if (!mounted) return;
      setState(() {
        _profiles = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูลสมาชิกได้: $e';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredProfiles {
    return _profiles.where((p) {
      final name = (p['full_name'] ?? '').toLowerCase();
      final email = (p['email'] ?? '').toLowerCase();
      final role = (p['role'] ?? '').toLowerCase();
      final status = (p['team_status'] ?? 'pending').toLowerCase();
      final isActive = p['is_active'] ?? true;

      // Search query
      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery.toLowerCase()) && !email.contains(_searchQuery.toLowerCase())) {
        return false;
      }
      // Role filter
      if (_filterRole != 'all' && role != _filterRole) {
        return false;
      }
      // Status filter
      if (_filterStatus != 'all' && status != _filterStatus) {
        return false;
      }
      // Active filter
      if (_filterActive == 'active' && !isActive) return false;
      if (_filterActive == 'inactive' && isActive) return false;

      return true;
    }).toList();
  }

  Future<void> _approveTeam(String userId, String userName) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final success = await appState.approveTeam(userId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('อนุมัติทีมให้ $userName สำเร็จ'), backgroundColor: Colors.green),
        );
        _fetchProfiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('อนุมัติทีมไม่สำเร็จ'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectTeam(String userId, String userName) async {
    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final success = await appState.rejectTeam(userId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ปฏิเสธคำขอทีมของ $userName แล้ว'), backgroundColor: Colors.orange),
        );
        _fetchProfiles();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ปฏิเสธคำขอทีมไม่สำเร็จ'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _changeRole(String userId, String currentRole, String userName) async {
    String selectedRole = currentRole;
    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('เปลี่ยนบทบาท (Role): $userName'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => DropdownButtonFormField<String>(
            value: selectedRole,
            items: const [
              DropdownMenuItem(value: 'user', child: Text('User')),
              DropdownMenuItem(value: 'developer', child: Text('Developer')),
              DropdownMenuItem(value: 'team_lead', child: Text('Team Lead')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
            ],
            onChanged: (val) {
              if (val != null) setDialogState(() => selectedRole = val);
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (success == true) {
      try {
        final appState = Provider.of<AppState>(context, listen: false);
        final ok = await appState.setProfileRole(userId, selectedRole);
        if (!mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('เปลี่ยน Role ของ $userName เป็น $selectedRole เรียบร้อยแล้ว'), backgroundColor: Colors.green),
          );
          _fetchProfiles();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('เปลี่ยน Role ไม่สำเร็จ'), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการเปลี่ยน Role: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _changeTeam(String userId, String? currentTeamId, String userName) async {
    try {
      final teamsRes = await Supabase.instance.client
          .from('teams')
          .select('id, name')
          .eq('is_active', true)
          .order('name');

      if (!mounted) return;
      final teams = List<Map<String, dynamic>>.from(teamsRes);
      if (teams.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลทีมที่เปิดใช้งาน'), backgroundColor: Colors.orange),
        );
        return;
      }

      String? selectedTeamId = currentTeamId ?? teams.first['id'];

      final success = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('กำหนดทีม (Team): $userName'),
          content: StatefulBuilder(
            builder: (context, setDialogState) => DropdownButtonFormField<String>(
              value: teams.any((t) => t['id'] == selectedTeamId) ? selectedTeamId : teams.first['id'],
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
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      );

      if (success == true && selectedTeamId != null) {
        final appState = Provider.of<AppState>(context, listen: false);
        final ok = await appState.setProfileTeam(userId, selectedTeamId!);
        if (!mounted) return;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('กำหนดทีมให้ $userName สำเร็จ'), backgroundColor: Colors.green),
          );
          _fetchProfiles();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('กำหนดทีมไม่สำเร็จ'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาดในการกำหนดทีม: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleAccountStatus(String userId, String userName, bool currentStatus) async {
    final newStatus = !currentStatus;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newStatus ? 'เปิดใช้งานบัญชี: $userName' : 'ระงับการใช้งานบัญชี: $userName'),
        content: Text(newStatus ? 'คุณต้องการเปิดใช้งานบัญชีนี้ใช่หรือไม่?' : 'คุณต้องการระงับการใช้งานบัญชีนี้ใช่หรือไม่? ผู้ใช้จะไม่สามารถเข้าสู่ระบบได้'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: newStatus ? Colors.green : Colors.red, foregroundColor: Colors.white),
            child: Text(newStatus ? 'เปิดใช้งาน' : 'ระงับบัญชี'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({'is_active': newStatus, 'updated_at': DateTime.now().toIso8601String()})
            .eq('id', userId);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus ? 'เปิดใช้งานบัญชี $userName แล้ว' : 'ระงับบัญชี $userName แล้ว'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
        _fetchProfiles();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredProfiles;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('จัดการสมาชิกและการอนุมัติทีม'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchProfiles,
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'ค้นหาด้วยชื่อหรืออีเมล...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterRole,
                        decoration: const InputDecoration(labelText: 'Role', isDense: true, contentPadding: EdgeInsets.all(8)),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('ทุก Role')),
                          DropdownMenuItem(value: 'user', child: Text('User')),
                          DropdownMenuItem(value: 'developer', child: Text('Developer')),
                          DropdownMenuItem(value: 'team_lead', child: Text('Team Lead')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (val) => setState(() => _filterRole = val ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterStatus,
                        decoration: const InputDecoration(labelText: 'Team Status', isDense: true, contentPadding: EdgeInsets.all(8)),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('ทุกสถานะทีม')),
                          DropdownMenuItem(value: 'pending', child: Text('Pending')),
                          DropdownMenuItem(value: 'approved', child: Text('Approved')),
                          DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                        ],
                        onChanged: (val) => setState(() => _filterStatus = val ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _filterActive,
                        decoration: const InputDecoration(labelText: 'Account', isDense: true, contentPadding: EdgeInsets.all(8)),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('ทุกบัญชี')),
                          DropdownMenuItem(value: 'active', child: Text('Active')),
                          DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                        ],
                        onChanged: (val) => setState(() => _filterActive = val ?? 'all'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : filtered.isEmpty
                        ? const Center(child: Text('ไม่พบข้อมูลสมาชิกที่ตรงกับเงื่อนไข'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final p = filtered[index];
                              final name = p['full_name'] ?? 'N/A';
                              final email = p['email'] ?? '';
                              final role = p['role'] ?? 'user';
                              final status = p['team_status'] ?? 'pending';
                              final isActive = p['is_active'] ?? true;
                              final userId = p['id'];
                              final teamId = p['team_id'];
                              final requestedTeam = p['requested_team'] != null ? p['requested_team']['name'] : 'ไม่มีการเลือกทีม';
                              final currentTeam = p['teams'] != null ? p['teams']['name'] : 'ยังไม่มีทีม';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              // Account Status Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isActive ? Colors.blue.shade100 : Colors.grey.shade300,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isActive ? 'ACTIVE' : 'INACTIVE',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isActive ? Colors.blue.shade800 : Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              // Team Status Badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: status == 'approved'
                                                      ? Colors.green.shade100
                                                      : status == 'rejected'
                                                          ? Colors.red.shade100
                                                          : Colors.amber.shade100,
                                                  borderRadius: BorderRadius.circular(8),
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
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text('Email: $email', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Text('Role: $role', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                                            onPressed: () => _changeRole(userId, role, name),
                                            icon: const Icon(Icons.edit, size: 12),
                                            label: const Text('เปลี่ยน Role', style: TextStyle(fontSize: 11)),
                                          ),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                                            onPressed: () => _changeTeam(userId, teamId, name),
                                            icon: const Icon(Icons.group, size: 12),
                                            label: const Text('กำหนดทีม', style: TextStyle(fontSize: 11)),
                                          ),
                                        ],
                                      ),
                                      Text('ทีมปัจจุบัน: $currentTeam', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                      Text('ทีมที่ร้องขอ: $requestedTeam', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      const SizedBox(height: 12),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          // Toggle Active / Inactive
                                          OutlinedButton(
                                            onPressed: () => _toggleAccountStatus(userId, name, isActive),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isActive ? Colors.red : Colors.green,
                                              side: BorderSide(color: isActive ? Colors.red : Colors.green),
                                            ),
                                            child: Text(isActive ? 'ระงับบัญชี' : 'เปิดใช้งาน'),
                                          ),
                                          // Team Approval Actions
                                          if (status == 'pending' && p['requested_team_id'] != null)
                                            Row(
                                              children: [
                                                OutlinedButton.icon(
                                                  onPressed: () => _rejectTeam(userId, name),
                                                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                                  label: const Text('ปฏิเสธ', style: TextStyle(color: Colors.red)),
                                                ),
                                                const SizedBox(width: 8),
                                                ElevatedButton.icon(
                                                  onPressed: () => _approveTeam(userId, name),
                                                  icon: const Icon(Icons.check, size: 16),
                                                  label: const Text('อนุมัติทีม'),
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
