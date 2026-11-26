import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  List<Map<String, dynamic>> _teams = [];
  bool _isLoadingTeams = true;
  String? _selectedTeamId;
  String? _teamFetchError;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchTeams();
  }

  Future<void> _fetchTeams() async {
    try {
      final response = await Supabase.instance.client
          .from('teams')
          .select('id, name, code')
          .eq('is_active', true)
          .order('name');

      if (!mounted) return;
      setState(() {
        _teams = List<Map<String, dynamic>>.from(response);
        _isLoadingTeams = false;
        if (_teams.isNotEmpty) {
          _selectedTeamId = _teams.first['id'] as String?;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingTeams = false;
        _teamFetchError = 'ไม่สามารถโหลดข้อมูลทีมได้';
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if (password != confirmPassword) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รหัสผ่านและยืนยันรหัสผ่านไม่ตรงกัน'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        final Map<String, dynamic> metadata = {
          'full_name': name,
        };
        if (_selectedTeamId != null && _selectedTeamId!.isNotEmpty) {
          metadata['requested_team_id'] = _selectedTeamId;
        }

        final response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
          data: metadata,
        );

        if (!mounted) return;

        setState(() => _isLoading = false);

        final successMsg = response.session != null
            ? 'สมัครสมาชิกสำเร็จ! สามารถเข้าสู่ระบบได้ทันที'
            : 'สมัครสมาชิกสำเร็จ! กรุณาตรวจสอบอีเมลเพื่อยืนยันบัญชีของคุณ';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        Navigator.pop(context);
      } on AuthException catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        String message = 'เกิดข้อผิดพลาดในการสมัครสมาชิก';
        final errLower = e.message.toLowerCase();
        if (errLower.contains('already registered') || errLower.contains('already exists')) {
          message = 'อีเมลนี้ถูกใช้งานในระบบแล้ว';
        } else if (errLower.contains('sending confirmation') || errLower.contains('smtp')) {
          message = 'ไม่สามารถส่งอีเมลยืนยันได้ กรุณาตรวจสอบการตั้งค่า SMTP ใน Supabase';
        } else if (errLower.contains('rate limit') || errLower.contains('over_email_send_rate_limit')) {
          message = 'มีการส่งอีเมลถี่เกินไป กรุณารอสักครู่แล้วลองใหม่';
        } else if (errLower.contains('password')) {
          message = 'รหัสผ่านไม่ตรงตามเงื่อนไขความปลอดภัย';
        } else if (errLower.contains('unable to validate email') ||
            errLower.contains('invalid email') ||
            (errLower.contains('email') && errLower.contains('invalid'))) {
          message = 'รูปแบบอีเมลไม่ถูกต้อง';
        } else {
          message = e.message;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเชื่อมต่อ กรุณาลองใหม่อีกครั้ง'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
                      'กรอกข้อมูลเพื่อลงทะเบียนเข้าใช้งาน DevIncident',
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

                  // Team Dropdown Selection
                  _buildLabel('เลือกทีม (Team)'),
                  const SizedBox(height: 6),
                  _isLoadingTeams
                      ? Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      : _teamFetchError != null
                          ? Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: Text(
                                _teamFetchError!,
                                style: const TextStyle(color: Color(0xFFFFD2D2), fontSize: 13),
                              ),
                            )
                          : _teams.isEmpty
                              ? Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                                  ),
                                  child: Text(
                                    'ไม่มีทีมที่เปิดใช้งานในขณะนี้',
                                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  value: _selectedTeamId,
                                  dropdownColor: const Color(0xFF1E40AF),
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  decoration: _buildInputDecoration(
                                    hint: 'เลือกทีมต้นสังกัด',
                                    icon: Icons.groups_outlined,
                                  ),
                                  items: _teams.map((t) {
                                    return DropdownMenuItem<String>(
                                      value: t['id'] as String,
                                      child: Text(
                                        t['name'] as String,
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedTeamId = val);
                                  },
                                  validator: (val) {
                                    if (_teams.isNotEmpty && (val == null || val.isEmpty)) {
                                      return 'กรุณาเลือกทีม';
                                    }
                                    return null;
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
                              'สมัครสมาชิก',
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
