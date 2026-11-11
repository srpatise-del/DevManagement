import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../models/app_models.dart';

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

  void _showAttachmentPickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'เลือกประเภทไฟล์แนบ',
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
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.image_outlined, color: AppColors.primary),
                ),
                title: const Text('แนบรูปภาพ (Image)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('เพิ่มรูปภาพหน้าจอข้อผิดพลาด หรือ Screenshot', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddImageDialog();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insert_drive_file_outlined, color: Colors.purple),
                ),
                title: const Text('แนบไฟล์เอกสาร (File Attachment)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('เพิ่มไฟล์ Log, PDF, JSON หรือ Document เอกสาร', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddFileDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddImageDialog() {
    final customNameController = TextEditingController();
    final presets = [
      'error_screenshot_v1.png',
      'console_log_dump.png',
      'ui_render_issue.png',
      'network_payload_error.jpg',
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มรูปภาพแนบ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('เลือกจากตัวอย่าง:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: presets.map((preset) {
                return ActionChip(
                  avatar: const Icon(Icons.image, size: 16, color: AppColors.primary),
                  label: Text(preset, style: const TextStyle(fontSize: 11)),
                  onPressed: () {
                    setState(() {
                      _attachedImages.add(preset);
                    });
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('แนบรูปภาพ $preset แล้ว')),
                    );
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text('หรือพิมพ์ชื่อรูปภาพ:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            TextField(
              controller: customNameController,
              decoration: const InputDecoration(
                hintText: 'เช่น my_screenshot.png',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final text = customNameController.text.trim();
              if (text.isNotEmpty) {
                final imageName = text.contains('.') ? text : '$text.png';
                setState(() {
                  _attachedImages.add(imageName);
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('แนบรูปภาพ $imageName แล้ว')),
                );
              }
            },
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
  }

  void _showAddFileDialog() {
    final fileNameController = TextEditingController();
    final fileSizeController = TextEditingController(text: '250 KB');

    final presets = [
      const CaseFileAttachment(fileName: 'error_log.txt', fileSize: '120 KB'),
      const CaseFileAttachment(fileName: 'api_trace.json', fileSize: '45 KB'),
      const CaseFileAttachment(fileName: 'crash_report.pdf', fileSize: '1.4 MB'),
      const CaseFileAttachment(fileName: 'db_dump.sql', fileSize: '2.8 MB'),
    ];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('เพิ่มไฟล์เอกสารแนบ'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('เลือกจากตัวอย่าง:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              Column(
                children: presets.map((preset) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.insert_drive_file, color: Colors.purple, size: 20),
                    title: Text(preset.fileName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text(preset.fileSize, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    onTap: () {
                      setState(() {
                        _attachedFiles.add(preset);
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('แนบไฟล์ ${preset.fileName} แล้ว')),
                      );
                    },
                  );
                }).toList(),
              ),
              const Divider(height: 20),
              const Text('หรือระบุชื่อไฟล์ใหม่:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              const SizedBox(height: 6),
              TextField(
                controller: fileNameController,
                decoration: const InputDecoration(
                  hintText: 'ชื่อไฟล์ เช่น system_log.txt',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fileSizeController,
                decoration: const InputDecoration(
                  hintText: 'ขนาดไฟล์ เช่น 350 KB',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final name = fileNameController.text.trim();
              final size = fileSizeController.text.trim().isNotEmpty ? fileSizeController.text.trim() : '100 KB';
              if (name.isNotEmpty) {
                setState(() {
                  _attachedFiles.add(CaseFileAttachment(fileName: name, fileSize: size));
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('แนบไฟล์ $name แล้ว')),
                );
              }
            },
            child: const Text('เพิ่ม'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
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

      appState.createCase(
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
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สร้างเคสเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

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
                        _buildSectionTitle('ผู้รับผิดชอบ (ไม่บังคับ)'),
                        const SizedBox(height: 6),
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
                                  style: const TextStyle(fontSize: 12),
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

              // Attachment Simulator
              _buildSectionTitle('แนบรูปภาพ / ไฟล์'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _showAttachmentPickerSheet,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary, style: BorderStyle.solid),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 32),
                      SizedBox(height: 6),
                      Text(
                        'คลิกเพื่อแนบรูปภาพหรือไฟล์เอกสาร',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'รองรับ PNG, JPG, PDF, TXT, JSON, SQL',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Attached Images Section
              if (_attachedImages.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'รูปภาพที่แนบแล้ว',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachedImages.map((img) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.image, size: 16, color: AppColors.primary),
                          const SizedBox(width: 6),
                          Text(img, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              setState(() {
                                _attachedImages.remove(img);
                              });
                            },
                            child: const Icon(Icons.close, size: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              // Attached Files Section
              if (_attachedFiles.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'ไฟล์เอกสารที่แนบแล้ว',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Column(
                  children: _attachedFiles.map((f) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.insert_drive_file, color: Colors.purple, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.fileName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  f.fileSize,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                            onPressed: () {
                              setState(() {
                                _attachedFiles.remove(f);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 32),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
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
