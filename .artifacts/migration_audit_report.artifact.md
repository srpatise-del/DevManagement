# Architecture Audit Report: Mock Data to Supabase PostgreSQL Migration — DevCase

รายงานการตรวจสอบสถาปัตยกรรมและโครงสร้างข้อมูลปัจจุบัน (Mock Data) ก่อนดำเนินการย้ายระบบไปสู่ Supabase PostgreSQL

---

## 1. ตรวจสอบ Case Management

- **Case Model (`CaseModel` ใน `app_models.dart`)**: จัดเก็บข้อมูลเคสปัญหา ประกอบด้วย ID (`DEV-001`), ชื่อเคส (`title`), ลำดับความสำคัญ (`priority`: low, medium, high, critical), สถานะเคส (`status`: open, assigned, inProgress, pending, waiting, testing, done, closed), ทีมที่รับผิดชอบ (`team`: web, mobile, backend, infra, other), หมวดหมู่ (`category`), ผู้รับผิดชอบ (`assignee`), วันที่สร้าง (`dateText`), ระบบที่ได้รับผลกระทบ (`systemAffected`), สภาพแวดล้อม (`environment`), URL, เบราว์เซอร์ (`browser`), ผู้สร้าง (`createdById`), รูปภาพแนบ (`attachedImages`), ไฟล์แนบ (`attachedFiles`), ความคิดเห็น (`comments`), และประวัติกิจกรรม (`activityLogs`).
- **Mock Data**: กำหนดเคสเริ่มต้น 11 เคส (DEV-001 ถึง DEV-011) ใน `AppState` (`app_state.dart`), รวมถึง Comments และ Activity Logs สำหรับแต่ละเคส
- **Data Provider / AppState**: ควบคุมสถานะรายการเคส (`List<CaseModel> cases`), ตัวกรองการค้นหา (`filteredCases`), สถิติต่างๆ (`openCount`, `inProgressCount`, ฯลฯ)
- **การสร้างและแก้ไข Case**: ผ่านฟังก์ชัน `createCase(...)` และ `updateCaseDetails(...)` ใน `AppState`
- **การเปลี่ยน Status และ Priority**: ผ่านฟังก์ชัน `updateCaseStatus(...)` และ `changeCasePriority(...)` บันทึก Activity Log อัตโนมัติ
- **การกำหนด Team และ Assignee**: ผ่านฟังก์ชัน `changeCaseTeam(...)` และ `reassignCase(...)` พร้อมส่ง Notification
- **Comments**: `CommentModel` เชื่อมโยงกับผู้เขียน (`author: UserModel`), เนื้อหา, วันที่, รูปภาพแนบ, ระบบไลค์
- **Timeline / Activity Logs**: `ActivityLogModel` บันทึกประวัติการกระทำแต่ละรายการ (สร้างเคส, เปลี่ยนสถานะ, มอบหมายงาน, คอมเมนต์, แนบไฟล์)
- **Attachments**: `CaseFileAttachment` (ชื่อไฟล์, ขนาด) และ `attachedImages`
- **Dashboard และ Reports**: `DashboardScreen` และ `ReportsExportScreen` ใช้สถิติจาก `cases` และ `filteredCases` ใน `AppState`

---

## 2. ตรวจสอบ Order Management (Order Diff & Bank Issue Cards)

- **Order Model (`OrderModel` ใน `app_models.dart`)**: จัดเก็บข้อมูลการ์ดออเดอร์ ประกอบด้วย ID (`id`), ประเภทการ์ด (`cardType`: `orderDiff`, `bankIssue`), ประเภทการจัดส่ง (`deliveryType`), ความสำคัญ (`priority`), สถานะกิจกรรม (`activityStatus`), ผู้รับผิดชอบ (`assignee`), ผู้สร้าง (`createBy`), วันที่ (`dateText`, `standardDate`), ไฟล์นำเข้า (`importFile`), ไฟล์แนบ (`attachments`), รายการย่อยในกลุ่มการ์ด (`items`: `List<OrderItemModel>`), รายละเอียดข้อผิดพลาด (`errorDetails`), ข้อมูลธนาคาร (`bankCode`, `bankName`), วิธีชำระเงิน (`paymentMethodCode`, `paymentMethod`), ยอดเงิน (`amount`), สถานะออเดอร์ (`statusOrder`), ความคิดเห็น (`comments`), และประวัติกิจกรรม (`activityLogs`).
- **Order Card Model & Order Item Model**: `OrderModel` ทำหน้าที่เป็นกลุ่มการ์ด (Card Group) ที่รวบรวม `OrderItemModel` (รหัสออเดอร์ย่อยหลายรายการในวันและผู้รับผิดชอบเดียวกัน)
- **Mock Data**: กำหนดการ์ดออเดอร์เริ่มต้นประมาณ 15 รายการ (ทั้ง Order Diff และ Bank Issue) ใน `AppState`
- **การสร้างและแก้ไข Order**: ผ่านฟังก์ชัน `createOrderCard(...)`, `updateOrderCard(...)`, `addOrderToCard(...)`, `deleteOrderCard(...)` ใน `AppState`
- **การจัดกลุ่ม Card ตามวันที่**: จัดกลุ่มตาม `cardType`, วันที่ (`effectiveStandardDate`), และ `assignee` ในวันเดียวกัน
- **การกำหนด Assignee**: ผ่านฟังก์ชัน `reassignOrderCard(...)`
- **Delivery Type**: ระบุประเภทการจัดส่ง (`express`, `sameday`, `nextday`, `normal`)
- **Comments & Timeline & Attachments**: โครงสร้างใช้โมเดลร่วมกัน (`CommentModel`, `ActivityLogModel`, `AttachmentModel`)

---

## 3. ตรวจสอบระบบที่ใช้ร่วมกัน (Shared Systems)

- **Login & AppState**: จัดการ Session ผ่าน `supabase_flutter` (`_initAuthSession()`, `loginWithSupabaseProfile()`, `refreshProfile()`, `logout()`) และเก็บรายการผู้ใช้จำลอง (`registeredUsers`) สำหรับ Demo
- **Profile & Role**: `UserModel` รองรับ Employee Code (`id`) และ Supabase UUID (`authUserId`), พร้อมทั้ง Role (`UserRole`: admin, teamLead, developer, user) และสถานะบัญชี (`isActive`, `teamStatus`, `requestedTeamId`)
- **Team**: `TeamType` enum (web, mobile, backend, infra, other) สอดคล้องกับตาราง `teams` ในฐานข้อมูล Supabase
- **Role Permission**: `RolePermissionHelper` และ `OrderRolePermissionHelper` กำหนดสิทธิ์การเข้าถึงเคสและออเดอร์ตาม Role ของผู้ใช้
- **Notification**: `AppNotificationModel` และระบบแจ้งเตือนภายในแอป (`notifications`) รองรับ Module (Case, Order Diff, Bank Issue)
- **Provider**: ใช้ `provider` package (`AppState` สืบทอดจาก `ChangeNotifier`) ในการจัดการสถานะทั่วแอป
- **Navigation**: ใช้ Flutter Navigator และ `MainNavigationScreen` สลับ Tab (Dashboard, Case List, Notifications, Profile)

---

## 4. วิเคราะห์การออกแบบ Supabase Database

- **ตารางที่จำเป็น (PostgreSQL Tables)**:
  1. `teams`: id (UUID, PK), name, code, is_active, created_at
  2. `profiles`: id (UUID, PK - FK to auth.users), employee_code, full_name, email, role, team_id (FK to teams), phone_number, position, team_status, requested_team_id (FK to teams), is_active, created_at, updated_at
  3. `cases`: id (VARCHAR/SERIAL, PK), title, priority, status, team_id / team_code, category, assignee_id (FK to profiles), system_affected, environment, url, browser, created_by_id (FK to profiles), created_at, updated_at
  4. `orders`: id (VARCHAR, PK), card_type, delivery_type, priority, activity_status, assignee_id (FK to profiles), create_by, date_text, standard_date, import_file, error_details, bank_code, bank_name, payment_method_code, payment_method, amount, status_order, created_at, updated_at
  5. `order_items`: id (VARCHAR, PK/Compound PK), order_id (FK to orders), delivery_type
  6. `comments`: id (UUID, PK), reference_id (case_id or order_id), author_id (FK to profiles), content, date_text, attached_image_url, likes, is_liked, created_at
  7. `activity_logs`: id (UUID, PK), reference_id (case_id or order_id), title, author_name, date_text, icon_data, icon_color, icon_bg_color, created_at
  8. `attachments`: id (UUID, PK), reference_id (case_id or order_id), name, size, date_text, file_type, file_url, created_at
- **RLS Policy**: จำเป็นต้องเปิด RLS บนทุกตาราง โดยให้สิทธิ์ `authenticated` อ่าน/เขียนตาม Role (`devc_case_is_active_admin()`, team membership, assignee checks)
- **Supabase Storage**: ใช้เก็บไฟล์แนบ (Attachments, Case screenshots, Bank slips, Order excel files) ใน Storage Buckets

---

## 5. ตารางสรุปโครงสร้างข้อมูลและแนวทาง Migration

| 1. ชื่อไฟล์ | 2. Model / หน้าที่ | 3. ข้อมูลที่จัดเก็บ | 4. ความสัมพันธ์กับ Model อื่น | 5. Mock Data ที่ใช้อยู่ | 6. แนวทางย้ายไป Supabase |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `app_models.dart` | `UserModel` | id (Employee Code), authUserId (UUID), name, role, email, team, phoneNumber, position, teamStatus, isActive | เชื่อมกับ `TeamType` และตาราง `profiles` | `registeredUsers` (4 ผู้ใช้) | ดึงข้อมูลจากตาราง `profiles` และ JOIN `teams` |
| `app_models.dart` | `CaseModel` | id, title, priority, status, team, category, assignee, dateText, systemAffected, environment, url, browser, createdById | เชื่อมกับ `UserModel` (assignee), `CommentModel`, `ActivityLogModel`, `CaseFileAttachment` | 11 เคสเริ่มต้น (DEV-001 ถึง DEV-011) | สร้างตาราง `cases` และเชื่อม FK กับ `profiles` และ `teams` |
| `app_models.dart` | `OrderModel` | id, cardType, deliveryType, priority, activityStatus, assignee, createBy, dateText, items, errorDetails, bankName, amount, statusOrder | เชื่อมกับ `UserModel` (assignee), `OrderItemModel`, `AttachmentModel`, `CommentModel`, `ActivityLogModel` | ประมาณ 15 การ์ด (Order Diff & Bank Issue) | สร้างตาราง `orders` และ `order_items` |
| `app_models.dart` | `CommentModel` | id, caseId, author, content, dateText, attachedImageUrl, likes, isLiked | เชื่อมกับ `UserModel` (author) | คอมเมนต์จำลองในแต่ละเคสและออเดอร์ | สร้างตาราง `comments` ผูก FK กับ `profiles` และอ้างอิง `reference_id` |
| `app_models.dart` | `ActivityLogModel` | id, caseId, title, authorName, dateText, icon, iconColor, iconBgColor | อ้างอิงเคสหรือออเดอร์ | Log จำลองเริ่มต้น | สร้างตาราง `activity_logs` |
| `app_models.dart` | `AttachmentModel` / `CaseFileAttachment` | fileName, fileSize, fileType | อ้างอิงเคสหรือออเดอร์ | ไฟล์แนบจำลอง | จัดเก็บไฟล์จริงบน Supabase Storage และบันทึก Metadata ลงตาราง `attachments` |
| `app_state.dart` | `AppState` (Provider) | จัดการ State ทั้งหมดของ Cases, Orders, Notifications, CurrentUser | ควบคุม Model ทั้งหมดในแอป | Mock Data เริ่มต้นทั้งหมดในหน่วยความจำ | แทนที่การจัดการ Mock List ด้วย Supabase Client Queries และ Realtime Subscriptions |

---

## 6. แผน Migration แยก Phase (Case & Order)

### Phase 1: Authentication & User Profiles Migration
- เชื่อมต่อตาราง `profiles` และ `teams`
- ย้ายระบบ Login / Session จาก Local Mock (`registeredUsers`) ไปใช้ Supabase Auth (`auth.users` + `profiles`)

### Phase 2: Case Management Migration
- สร้างตาราง `cases`, `comments`, `activity_logs`, `attachments` บน Supabase PostgreSQL
- สร้าง RLS Policies สำหรับ Case Access Control ตาม Role
- เปลี่ยนฟังก์ชัน CRUD ใน `AppState` (`createCase`, `updateCaseStatus`, ฯลฯ) ให้เรียก Supabase API แทนการแก้ไข Local List

### Phase 3: Order & Bank Issue Management Migration
- สร้างตาราง `orders` และ `order_items` บน Supabase PostgreSQL
- ย้ายระบบสร้างการ์ดออเดอร์ การจัดกลุ่มตามวันที่ และการมอบหมายงานไปใช้ฐานข้อมูลจริง
- ทดสอบระบบการอัปโหลดไฟล์/สลิปผ่าน Supabase Storage

### Phase 4: Verification & Testing
- ตรวจสอบความถูกต้องของสิทธิ์ (`RolePermissionHelper`, `OrderRolePermissionHelper`)
- ทดสอบการซิงค์ข้อมูลแบบ Real-time และการรีเฟรชสิทธิ์ (Role Refresh)
