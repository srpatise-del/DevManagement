# Phase 0: Project Audit Report - DevCase Authentication & Team Management

รายงานการตรวจสอบสถานะโครงการปัจจุบัน (Project Audit) ก่อนเริ่มดำเนินการพัฒนาระบบ Authentication, Team Management, Admin Approval และ Role Permission

---

## 1. สิ่งที่ทำเสร็จแล้ว (What is Done)
- **Supabase Core Integration**: ตั้งค่า `SupabaseConfig` (`supabase_config.dart`) และ Initialize `Supabase.initialize()` ใน `main.dart` เรียบร้อยแล้ว
- **Register Screen (Supabase Auth)**: ปรับปรุง `register_screen.dart` ให้เรียกใช้งาน `Supabase.instance.client.auth.signUp()` พร้อมส่ง `full_name` ใน metadata
- **Role & Permission Models**: มีโครงสร้าง `UserRole`, `Permission`, และ `RolePermissionHelper` (`role_permission.dart`) ที่แบ่งแยกสิทธิ์ตามบทบาท (Admin, Team Lead, Developer, User) อย่างชัดเจน
- **Case & Order Systems**: ระบบจัดการ Case, Order, Bank Issue และ UI components ต่าง ๆ ถูกพัฒนาไว้สมบูรณ์แล้ว (ห้ามรื้อหรือเขียนใหม่)

## 2. สิ่งที่ยังไม่เสร็จ (What is Not Done)
- **Team Selection on Registration**: หน้าจอสมัครสมาชิกยังไม่ได้เพิ่มตัวเลือกให้ผู้ใช้เลือกทีม (Team) ระหว่างสมัคร
- **Supabase Login Integration**: หน้าจอ `login_screen.dart` และ `AppState` ยังใช้งาน Mock Data ของผู้ใช้ในเครื่อง (`registeredUsers`) แทนที่จะใช้ `Supabase.instance.client.auth.signInWithPassword()`
- **Admin Approval & Team Status**: ระบบสถานะการอนุมัติทีมจาก Admin (Pending / Approved) และตาราง `teams` / `profiles` ใน Supabase
- **Profile & Role Sync**: การดึงข้อมูล Profile และ Role จาก Supabase มาเชื่อมโยงกับ `AppState` และ `currentUser`
- **Session Management**: การตรวจจับสถานะ Auth Session ปัจจุบัน (onAuthStateChange) เมื่อแอปเปิดขึ้นมา

## 3. ไฟล์ที่จะต้องแก้ไข (Files to Modify)
1. **`lib/screens/register_screen.dart`**: เพิ่ม Dropdown ให้เลือก Team ระหว่างสมัครสมาชิก และส่งข้อมูล `team_id` / `team` ไปยัง Supabase Auth metadata / profile
2. **`lib/screens/login_screen.dart`**: เปลี่ยนจากการเรียก `appState.loginWithCredentials()` แบบ mock มาใช้ Supabase Auth (`signInWithPassword`) และตรวจสอบการอนุมัติทีม (Admin Approval)
3. **`lib/providers/app_state.dart`**: เพิ่มฟังก์ชันการจัดการ Supabase Auth session, โหลดข้อมูลผู้ใช้จากตาราง `profiles`, จัดการสถานะ Admin/Team, โดย**คงระบบ Mock Data ของ Case และ Order ไว้เช่นเดิม**
4. **`lib/models/app_models.dart`**: ตรวจสอบและปรับปรุง `UserModel` ให้รองรับข้อมูลจากตาราง `profiles` (เช่น `approvalStatus`, `teamId`)

## 4. Database ที่ต้องปรับปรุง (Database / Supabase Requirements)
- **ตาราง `teams`**: เก็บข้อมูลทีมในระบบ (เช่น Web Team, Mobile Team, Backend Team, Infra, ฯลฯ)
- **ตาราง `profiles`**: เชื่อมโยงกับ `auth.users(id)` (Foreign Key), เก็บข้อมูล `full_name`, `role` (default 'user'), `team_id`, และ `approval_status` (pending, approved, rejected)
- **Database Triggers & Functions**:
  - `devc_case_set_profile_role()`: สร้าง profile อัตโนมัติเมื่อสมัครสมาชิกและกำหนด role เป็น 'user'
  - `devc_case_is_active_admin()`: ตรวจสอบสิทธิ์ Admin
- **RLS Policies**: ควบคุมสิทธิ์การอ่าน/เขียนข้อมูลตาราง profiles และ teams

## 5. ความเสี่ยงต่อระบบเดิม (Risks to Existing Systems)
- **การทับซ้อนของ Model / Provider**: ห้ามสร้าง Model, Provider หรือฟังก์ชันซ้ำซ้อนกับของเดิม (ให้ใช้วิธี extend หรือปรับแต่งจากของเดิมที่มีอยู่)
- **Case & Order Systems**: ห้ามแก้ไขหรือลบตรรกะของ Case, Order และ Bank Issue ที่มีอยู่เดิม เพื่อป้องกันแอปพัง
- **Null Safety & Context**: ต้องตรวจสอบ `mounted` เสมอเมื่อใช้งาน async ใน Widget และจัดการ Error จาก Supabase ให้ชัดเจน
