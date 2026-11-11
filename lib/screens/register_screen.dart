import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'main_navigation_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  String _selectedRole = 'Developer';
  TeamType _selectedTeam = TeamType.web;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  final List<String> _roles = [
    'Developer',
    'User',
    'Team Lead',
    'Admin',
    'QA',
    'UI/UX Designer',
    'Product Owner',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รหัสผ่านและยืนยันรหัสผ่านไม่ตรงกัน'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final appState = Provider.of<AppState>(context, listen: false);
      final exists = appState.registeredUsers.any(
        (u) => u.email.trim().toLowerCase() == email.toLowerCase(),
      );

      if (exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('อีเมลนี้ถูกลงทะเบียนไว้ในระบบแล้ว'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Generate Mock OTP (6 digits) & Ref Code
      final mockOtp = '123456';
      final refCode = 'DC${(DateTime.now().millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}';

      // Show Mock OTP Verification Sheet
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => _OtpVerificationBottomSheet(
          email: email,
          generatedOtp: mockOtp,
          refCode: refCode,
          onOtpVerified: () {
            setState(() => _isLoading = true);

            final success = appState.registerUser(
              name: name,
              role: _selectedRole,
              email: email,
              password: password,
              team: _selectedTeam,
            );

            setState(() => _isLoading = false);

            if (success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('สมัครสมาชิกสำเร็จ! ยินดีต้อนรับคุณ $name'),
                  backgroundColor: Colors.green,
                ),
              );

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => const MainNavigationScreen(),
                ),
                (route) => false,
              );
            }
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E40AF),
              Color(0xFF1D61E7),
              Color(0xFF2563EB),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back Button & Title
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'สมัครสมาชิกใหม่',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Text(
                      'กรอกข้อมูลเพื่อลงทะเบียนเข้าใช้งาน DevCase',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Name Field
                  _buildLabel('ชื่อ-นามสกุล'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      hint: 'เช่น Patis Dev',
                      icon: Icons.person_outline,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'กรุณากรอกชื่อ-นามสกุล';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Role Selection Dropdown
                  _buildLabel('บทบาท / ตำแหน่ง'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    dropdownColor: const Color(0xFF1E40AF),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _buildInputDecoration(
                      hint: 'เลือกบทบาท',
                      icon: Icons.badge_outlined,
                    ),
                    items: _roles.map((r) {
                      return DropdownMenuItem(
                        value: r,
                        child: Text(r),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Team Selection Dropdown
                  _buildLabel('ทีม (Team)'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<TeamType>(
                    value: _selectedTeam,
                    dropdownColor: const Color(0xFF1E40AF),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _buildInputDecoration(
                      hint: 'เลือกทีมต้นสังกัด',
                      icon: Icons.groups_outlined,
                    ),
                    items: TeamType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedTeam = val);
                    },
                  ),
                  const SizedBox(height: 16),

                  // Email Field
                  _buildLabel('อีเมล (Email)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      hint: 'เช่น user@company.com',
                      icon: Icons.email_outlined,
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'กรุณากรอกอีเมล';
                      }
                      if (!val.contains('@') || !val.contains('.')) {
                        return 'รูปแบบอีเมลไม่ถูกต้อง';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password Field
                  _buildLabel('รหัสผ่าน (Password)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      hint: 'กำหนดรหัสผ่าน ( อย่างน้อย 6 ตัวอักษร )',
                      icon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'กรุณากรอกรหัสผ่าน';
                      }
                      if (val.length < 6) {
                        return 'รหัสผ่านต้องมีความยาวอย่างน้อย 6 ตัวอักษร';
                      }
                      List<String> errors = [];
                      if (!val.contains(RegExp(r'[a-z]'))) {
                        errors.add('ตัวพิมพ์เล็ก (a-z)');
                      }

                      if (!val.contains(RegExp(r'[A-Z]'))) {
                        errors.add('ตัวพิมพ์ใหญ่ (A-Z)');
                      }

                      if (!val.contains(RegExp(r'[0-9]'))) {
                        errors.add('ตัวเลข (0-9)');
                      }

                      if (val.length < 6) {
                        errors.add('ความยาวอย่างน้อย 6 ตัวอักษร');
                      }

                      if (errors.isNotEmpty) {
                        return 'รหัสผ่านยังขาด:\n• ${errors.join('\n• ')}';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Confirm Password Field
                  _buildLabel('ยืนยันรหัสผ่าน (Confirm Password)'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: _buildInputDecoration(
                      hint: 'กรอกรหัสผ่านอีกครั้ง',
                      icon: Icons.lock_clock_outlined,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                          color: Colors.white70,
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'กรุณายืนยันรหัสผ่าน';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1D61E7),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Color(0xFF1D61E7),
                              ),
                            )
                          : const Text(
                              'สมัครสมาชิกและเข้าใช้งาน',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Already have an account
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'มีบัญชีอยู่แล้ว? เข้าสู่ระบบที่นี่',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.white),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white, width: 1.5),
      ),
      errorStyle: const TextStyle(color: Color(0xFFFFD2D2), fontWeight: FontWeight.bold),
    );
  }
}

class _OtpVerificationBottomSheet extends StatefulWidget {
  final String email;
  final String generatedOtp;
  final String refCode;
  final VoidCallback onOtpVerified;

  const _OtpVerificationBottomSheet({
    required this.email,
    required this.generatedOtp,
    required this.refCode,
    required this.onOtpVerified,
  });

  @override
  State<_OtpVerificationBottomSheet> createState() => _OtpVerificationBottomSheetState();
}

class _OtpVerificationBottomSheetState extends State<_OtpVerificationBottomSheet> {
  final TextEditingController _otpController = TextEditingController();
  bool _isVerifying = false;
  String? _errorMessage;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _verifyOtp() {
    final inputOtp = _otpController.text.trim();
    if (inputOtp.length < 6) {
      setState(() => _errorMessage = 'กรุณากรอกรหัส OTP ให้ครบ 6 หลัก');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (inputOtp == widget.generatedOtp || inputOtp == '123456') {
        Navigator.pop(context);
        widget.onOtpVerified();
      } else {
        setState(() {
          _isVerifying = false;
          _errorMessage = 'รหัส OTP ไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'ยืนยันรหัส OTP',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Demo Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '[Demo] รหัส OTP คือ: ${widget.generatedOtp}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    setState(() {
                      _otpController.text = widget.generatedOtp;
                      _errorMessage = null;
                    });
                  },
                  child: const Text('เติมรหัส', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'ระบบได้ส่งรหัส OTP 6 หลัก ไปที่ ${widget.email}',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 2),
          Text(
            'รหัสอ้างอิง (Ref): ${widget.refCode}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),

          // OTP Pincode Input
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
              color: AppColors.primary,
            ),
            decoration: InputDecoration(
              hintText: '••••••',
              hintStyle: const TextStyle(letterSpacing: 12, color: AppColors.textMuted),
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
            onChanged: (val) {
              if (_errorMessage != null) setState(() => _errorMessage = null);
              if (val.length == 6) {
                _verifyOtp();
              }
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              _errorMessage!,
              style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 20),

          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyOtp,
              child: _isVerifying
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('ยืนยันรหัส OTP', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
