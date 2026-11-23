import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';
import '../models/role_permission.dart';
import '../widgets/attachment_picker_widget.dart';

class CreateCaseScreen extends StatefulWidget {
  const CreateCaseScreen({super.key});

  @override
  State<CreateCaseScreen> createState() => _CreateCaseScreenState();
}

class _CreateCaseScreenState extends State<CreateCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController(text: 'UI/UX');
  final _systemController = TextEditingController(text: 'Web Application');
  final _envController = TextEditingController(text: 'Production');

  // Platform Type Selection: 'web' vs 'mobile'
  String _platformType = 'web';
  final _urlController = TextEditingController(text: 'https://app.company.com/dashboard');
  final _browserController = TextEditingController(text: 'Chrome (Version 128)');

  // Mobile App Platform Specific Controllers
  String _appOsPlatform = 'iOS'; // 'iOS', 'Android', 'Both'
  final _appVersionController = TextEditingController(text: 'v1.2.4 (Build 108)');
  final _deviceModelController = TextEditingController(text: 'iPhone 15 Pro');
  final _osVersionController = TextEditingController(text: 'iOS 17.5');

  TeamType _selectedTeam = TeamType.web;
  CasePriority _selectedPriority = CasePriority.medium;
  UserModel? _selectedAssignee; // Optional! Default to Unassigned (null)

  final List<String> _attachedImages = [];
  final List<CaseFileAttachment> _attachedFiles = [];
  List<PendingFileAttachment> _pendingFiles = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _systemController.dispose();
    _envController.dispose();
    _urlController.dispose();
    _browserController.dispose();
    _appVersionController.dispose();
    _deviceModelController.dispose();
    _osVersionController.dispose();
    super.dispose();
  }



  void _submit() async {
    if (_isSubmitting) return;
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSubmitting = true;
      });

      final appState = Provider.of<AppState>(context, listen: false);

      String formattedUrl = '';
      String formattedBrowser = '';

      if (_platformType == 'web') {
        formattedUrl = _urlController.text.trim();
        formattedBrowser = _browserController.text.trim();
      } else {
        // Mobile App
        formattedUrl = 'App ${_appVersionController.text.trim()} ($_appOsPlatform)';
        formattedBrowser = '${_deviceModelController.text.trim()} (${_osVersionController.text.trim()})';
      }

      try {
        await appState.createCase(
          title: _titleController.text.trim(),
          team: _selectedTeam,
          category: _categoryController.text.trim(),
          assignee: _selectedAssignee,
          priority: _selectedPriority,
          systemAffected: _systemController.text.trim(),
          environment: _envController.text.trim(),
          url: formattedUrl,
          browser: formattedBrowser,
          images: _attachedImages,
          files: _attachedFiles,
          pendingFiles: _pendingFiles,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('สร้างเคสเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการสร้างเคส: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isSubmitting = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final isUserRole = appState.currentUser.roleEnum == UserRole.user;

    if (isUserRole) {
      _selectedAssignee = null;
    }

    // Filter registered users belonging to the currently selected team
    final teamMembers = appState.registeredUsers.where((u) => u.team == _selectedTeam).toList();

    // Safely check if current _selectedAssignee belongs to teamMembers
    if (_selectedAssignee != null && !teamMembers.contains(_selectedAssignee)) {
      _selectedAssignee = null;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'สร้างเคสใหม่',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Case Title Input
              _buildSectionTitle('หัวข้อ / ชื่อเคส'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'ระบุชื่อเคส เช่น หน้า Dashboard แสดงผลผิด',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'กรุณากรอกชื่อเคส';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Team & Priority Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('ทีม (บังคับ)'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<TeamType>(
                          isExpanded: true,
                          value: _selectedTeam,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: TeamType.values.map((t) {
                            return DropdownMenuItem(
                              value: t,
                              child: Text(
                                t.label,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedTeam = val;
                                // Automatically switch platform type if mobile team
                                if (val == TeamType.mobile) {
                                  _platformType = 'mobile';
                                  _systemController.text = 'Mobile Application';
                                } else if (val == TeamType.web) {
                                  _platformType = 'web';
                                  _systemController.text = 'Web Application';
                                }
                                // Check if _selectedAssignee is still valid for new team
                                final newTeamMembers = appState.registeredUsers.where((u) => u.team == val).toList();
                                if (_selectedAssignee != null && !newTeamMembers.contains(_selectedAssignee)) {
                                  _selectedAssignee = null;
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Priority'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<CasePriority>(
                          isExpanded: true,
                          value: _selectedPriority,
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          items: CasePriority.values.map((p) {
                            return DropdownMenuItem(
                              value: p,
                              child: Text(
                                p.label,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPriority = val);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Assignee & Category Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('ผู้รับผิดชอบ'),
                        const SizedBox(height: 6),
                        if (isUserRole) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: const Text(
                              'ยังไม่ระบุผู้รับผิดชอบ (อัตโนมัติ)',
                              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'ผู้ใช้งานทั่วไปไม่สามารถกำหนดผู้รับผิดชอบได้',
                            style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ] else ...[
                          DropdownButtonFormField<UserModel?>(
                            isExpanded: true,
                            value: _selectedAssignee,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            ),
                            items: [
                              const DropdownMenuItem<UserModel?>(
                                value: null,
                                child: Text(
                                  'ยังไม่ระบุผู้รับผิดชอบ',
                                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              ...teamMembers.map((u) {
                                return DropdownMenuItem<UserModel?>(
                                  value: u,
                                  child: Text(
                                    '${u.name} (${u.role})',
                                    style: TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedAssignee = val);
                            },
                          ),
                          const SizedBox(height: 4),
                          Text(
                            teamMembers.isNotEmpty
                                ? 'สมาชิกใน ${_selectedTeam.label} (${teamMembers.length} คน)'
                                : 'ทีมนี้ยังไม่มีสมาชิกในระบบ (เคสจะถูกส่งให้ Team Lead / Admin จัดการ)',
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('หมวดหมู่'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            hintText: 'UI/UX, Bug ฯลฯ',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // System & Environment
              _buildSectionTitle('ระบบที่มีปัญหา / รายละเอียดปัญหา'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _systemController,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  hintText: 'ระบุระบบที่มีปัญหาและรายละเอียด เช่น Web Application หรือ Mobile App (เมื่อกดปุ่มชำระเงินแล้วเกิด Crash)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              _buildSectionTitle('Environment'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _envController,
                decoration: const InputDecoration(
                  hintText: 'เช่น Production, Staging, TestFlight',
                ),
              ),
              const SizedBox(height: 20),

              // Platform Selector (ใต้ Environment)
              _buildSectionTitle('เลือกประเภทแพลตฟอร์มที่พบปัญหา'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.language,
                      size: 18,
                      color: _platformType == 'web' ? Colors.white : AppColors.primary,
                    ),
                    label: const Text('เว็บไซต์ (Web)'),
                    selected: _platformType == 'web',
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _platformType == 'web' ? Colors.white : AppColors.textPrimary,
                      fontWeight: _platformType == 'web' ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _platformType = 'web';
                          if (_systemController.text == 'Mobile Application') {
                            _systemController.text = 'Web Application';
                          }
                        });
                      }
                    },
                  ),
                  ChoiceChip(
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.phone_android,
                      size: 18,
                      color: _platformType == 'mobile' ? Colors.white : AppColors.primary,
                    ),
                    label: const Text('แอปพลิเคชัน (Mobile App)'),
                    selected: _platformType == 'mobile',
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _platformType == 'mobile' ? Colors.white : AppColors.textPrimary,
                      fontWeight: _platformType == 'mobile' ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _platformType = 'mobile';
                          if (_systemController.text == 'Web Application') {
                            _systemController.text = 'Mobile Application';
                          }
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // DYNAMIC FORM FIELDS BASED ON PLATFORM SELECTION
              if (_platformType == 'web') ...[
                // --- WEBSITE FORM FIELDS (แบบเดิม) ---
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.language, color: AppColors.primary, size: 18),
                          SizedBox(width: 6),
                          Text('ข้อมูลสำหรับเว็บไซต์ (Web Details)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      const Divider(height: 16),
                      _buildSectionTitle('URL ที่พบปัญหา'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          hintText: 'https://...',
                        ),
                      ),
                      const SizedBox(height: 14),

                      _buildSectionTitle('Browser / Version'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _browserController,
                        decoration: const InputDecoration(
                          hintText: 'เช่น Chrome (Version 128), Safari, Edge',
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // --- MOBILE APP FORM FIELDS (แบบใหม่เฉพาะ Mobile) ---
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.phone_android, color: AppColors.primary, size: 18),
                          SizedBox(width: 6),
                          Text('ข้อมูลสำหรับแอปพลิเคชัน (Mobile App Details)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      const Divider(height: 16),

                      // OS Platform Choice Chips (iOS, Android, ทั้งสองระบบ)
                      _buildSectionTitle('ระบบปฏิบัติการ (OS Platform)'),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _buildOsChip('iOS', Icons.apple),
                          const SizedBox(width: 8),
                          _buildOsChip('Android', Icons.android),
                          const SizedBox(width: 8),
                          _buildOsChip('ทั้งสองระบบ', Icons.devices),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // App Version
                      _buildSectionTitle('เวอร์ชันของแอป (App Version)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _appVersionController,
                        decoration: const InputDecoration(
                          hintText: 'เช่น v1.2.4 (Build 108) หรือ TestFlight v2.0',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Device Model & OS Version Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('รุ่นอุปกรณ์ / โมเดล'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _deviceModelController,
                                  decoration: const InputDecoration(
                                    hintText: 'เช่น iPhone 15 Pro, S24',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle('เวอร์ชัน OS'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _osVersionController,
                                  decoration: const InputDecoration(
                                    hintText: 'เช่น iOS 17.5, Android 14',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),
              // Attachment Picker Widget
              AttachmentPickerWidget(
                pendingFiles: _pendingFiles,
                onFilesChanged: (files) {
                  setState(() {
                    _pendingFiles = files;
                  });
                },
                isUploading: _isSubmitting,
                uploadProgressText: 'กำลังบันทึกและอัปโหลดไฟล์...',
              ),

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'บันทึก / สร้างเคส',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOsChip(String label, IconData icon) {
    final isSelected = _appOsPlatform == label;
    return FilterChip(
      showCheckmark: false,
      avatar: Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.primary),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _appOsPlatform = label;
          });
        }
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }
}
