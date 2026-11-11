import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';

class EditCaseScreen extends StatefulWidget {
  final CaseModel caseObj;

  const EditCaseScreen({super.key, required this.caseObj});

  @override
  State<EditCaseScreen> createState() => _EditCaseScreenState();
}

class _EditCaseScreenState extends State<EditCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _categoryController;
  late TextEditingController _systemController;
  late TextEditingController _envController;

  // Platform Type Selection: 'web' vs 'mobile'
  late String _platformType;

  // Web Platform Specific Controllers
  late TextEditingController _urlController;
  late TextEditingController _browserController;

  // Mobile App Platform Specific Controllers
  String _appOsPlatform = 'iOS';
  late TextEditingController _appVersionController;
  late TextEditingController _deviceModelController;
  late TextEditingController _osVersionController;

  late TeamType _selectedTeam;
  late CasePriority _selectedPriority;
  UserModel? _selectedAssignee;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.caseObj.title);
    _categoryController = TextEditingController(text: widget.caseObj.category);
    _systemController = TextEditingController(text: widget.caseObj.systemAffected);
    _envController = TextEditingController(text: widget.caseObj.environment);

    final isMobile = widget.caseObj.systemAffected.toLowerCase().contains('mobile') ||
        widget.caseObj.team == TeamType.mobile ||
        widget.caseObj.url.toLowerCase().contains('app ');

    _platformType = isMobile ? 'mobile' : 'web';

    _urlController = TextEditingController(text: widget.caseObj.url);
    _browserController = TextEditingController(text: widget.caseObj.browser);

    // Initialize Mobile App controllers
    if (widget.caseObj.url.toLowerCase().contains('ios')) {
      _appOsPlatform = 'iOS';
    } else if (widget.caseObj.url.toLowerCase().contains('android')) {
      _appOsPlatform = 'Android';
    } else {
      _appOsPlatform = 'ทั้งสองระบบ';
    }

    _appVersionController = TextEditingController(
      text: isMobile ? widget.caseObj.url : 'v1.2.4 (Build 108)',
    );
    _deviceModelController = TextEditingController(
      text: isMobile ? widget.caseObj.browser : 'iPhone 15 Pro',
    );
    _osVersionController = TextEditingController(text: 'iOS 17.5');

    _selectedTeam = widget.caseObj.team;
    _selectedPriority = widget.caseObj.priority;
    _selectedAssignee = widget.caseObj.assignee;
  }

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

      appState.updateCaseDetails(
        caseId: widget.caseObj.id,
        title: _titleController.text.trim(),
        team: _selectedTeam,
        category: _categoryController.text.trim(),
        assignee: _selectedAssignee,
        priority: _selectedPriority,
        systemAffected: _systemController.text.trim(),
        environment: _envController.text.trim(),
        url: formattedUrl,
        browser: formattedBrowser,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('แก้ไขเคส ${widget.caseObj.id} เรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
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
        title: Text(
          'แก้ไขเคส ${widget.caseObj.id}',
          style: const TextStyle(
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
                  hintText: 'ระบุชื่อเคส',
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
                        _buildSectionTitle('ทีม'),
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
                  hintText: 'ระบุระบบที่มีปัญหาและรายละเอียดเพิ่มเติม',
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

                      // OS Platform Choice Chips
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
                    'บันทึกการแก้ไข',
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
