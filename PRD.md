# Suraksha QR — Product Requirements Document (PRD)

**Project:** Suraksha QR — Emergency Based QR Scanner Application
**Platform:** Mobile (Flutter — Android first)
**Backend:** Supabase (Auth + PostgreSQL + Storage)
**Version:** 1.0 (Simplified, final scope)

---

## 1. Overview

Suraksha QR is a mobile application that lets a person store their basic and medical information in advance and get a personal **QR code**. In an emergency (accident, unconsciousness, etc.), a **Doctor** or any **third person** can scan that QR and instantly see the person's emergency information (blood group, conditions, emergency contacts), so correct help can be given quickly.

To keep the information trustworthy, an **Admin** verifies the documents uploaded by Users (blood group proof, medical proof) and Doctors (degree, MBBS registration).

### 1.1 Problem Statement
In an emergency, the victim is often unable to speak, and bystanders/doctors don't know the person's blood group, allergies, diseases, or whom to call. Valuable time is lost.

### 1.2 Goal
Provide a simple, reliable way to carry verified emergency information that can be accessed by scanning one QR code.

### 1.3 Scope Rule
Only the features listed in this document will be built. **No extra features.** (See Section 12 for what is out of scope.)

### 1.4 Story Case (Real-Life Scenario)

**Characters:** Rahul (User), Suresh (bystander / third person), Dr. Mehta (verified Doctor), Rahul's father (emergency contact).

**Before the accident**
Rahul registered on Suraksha QR, added his basic and medical details, blood group proof, medical report and his father's number as an emergency contact. The Admin verified his documents, and his dashboard shows **Verified**. Rahul saved his QR and keeps it where it is easy to find (printed on his wallet card / helmet sticker / phone).

**Accident**
1. Rahul meets with a road accident and becomes unconscious. He cannot speak or tell anyone his name, blood group or whom to call.
2. Suresh, a bystander, reaches the spot and finds Rahul's QR. He opens Suraksha QR and taps **Scan QR as Guest** (no login needed).
3. The app instantly shows Rahul's limited emergency information: photo, name, age, gender, **blood group (verified)**, known conditions such as diabetes or allergies, and his **emergency contacts**.
4. Suresh taps **Call Emergency Contact** and calls Rahul's father, tells him about the accident and the location.
5. Suresh, with the family's guidance, calls for help and gets Rahul to the nearest hospital.

**At the hospital**
6. Dr. Mehta, a verified Doctor, logs in to the app and taps **Scan QR** as soon as Rahul arrives. No time is lost asking questions Rahul cannot answer.
7. The app shows the **full information**: verified blood group, recent medical details, diseases and allergies, uploaded medical documents, and contact numbers.
8. Dr. Mehta confirms the medical details (for example blood group for transfusion, diabetes, any allergy to medicine) and **starts the treatment / operation immediately**, safely and without delay.

**Outcome:** Right information reached the right person at the right time, and critical minutes were saved.

| Step | Who | Action | What they see |
|------|-----|--------|---------------|
| 1 | Suresh (guest) | Scans QR | Limited emergency info |
| 2 | Suresh | Calls emergency contact | Emergency contacts with Call button |
| 3 | Dr. Mehta (verified Doctor) | Logs in and scans QR | Full medical info and documents |
| 4 | Dr. Mehta | Verifies details and starts treatment | Verified blood group, conditions, allergies |

---

## 2. User Roles

| Role | Who | What they do |
|------|-----|--------------|
| **User** | Any person who wants an emergency QR | Registers, fills basic + medical info, uploads photo and documents, adds emergency contacts, gets QR, sees dashboard |
| **Doctor** | Medical professional | Registers with professional details and documents, gets verified by Admin, scans QR and sees full medical info |
| **Admin** | System verifier | Registers/logs in with email + password, verifies Users' and Doctors' profiles and documents |
| **Third Person (guest)** | Bystander, no account | Scans QR and sees limited emergency info only (no login required) |

---

## 3. Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| State management | Riverpod |
| Navigation | GoRouter |
| Backend | Supabase |
| Authentication | Supabase Auth (email + password) |
| Database | Supabase PostgreSQL with Row Level Security (RLS) |
| File storage | Supabase Storage (private buckets, signed URLs) |
| QR generation | `qr_flutter` |
| QR scanning | `mobile_scanner` |
| Image / file picking | `image_picker`, `file_picker` |
| Calling emergency contact | `url_launcher` |
| Config | `flutter_dotenv` (Supabase URL + anon key) |
| Secure local storage | `flutter_secure_storage` |

> No separate Node.js / custom backend. Supabase handles everything.

---

## 4. Authentication & Access

- Single login system via **Supabase Auth (email + password)**.
- Each account has a **role**: `user`, `doctor`, or `admin`, stored in the `profiles` table.
- **User, Doctor and Admin can all self-register** from the app. The Admin creates their own account using their own email and password (no manual creation by the developer).
- The role is chosen at registration and **cannot be changed afterwards**.
- After login, the app routes the person to the correct dashboard based on role.
- **Doctor access to scanned data is allowed only after Admin approves the Doctor.**

### Login screen (same screen for all 3 roles)
- One common Login page for User, Doctor and Admin.
- A **role toggle / segmented bar** at the top: **User | Doctor | Admin**. The person selects who they are logging in as.
- Fields: Email, Password, Login button.
- On login, the app checks that the account's stored role matches the selected toggle. If it does not match, show an error ("This account is not registered as <role>") and do not log in.
- A "Register" link below the form; the registration form also uses the same toggle (User / Doctor / Admin) to decide which registration form opens.

---

## 5. Functional Requirements

### 5.1 User Module

#### 5.1.1 User Registration (multi-step form)

**Step 1 — Account**
- Email, Password, Confirm Password

**Step 2 — Basic Information**
- Profile Photo (required)
- Full Name (required)
- Gender (Male / Female / Other)
- Age (number)
- Own Contact Number

**Step 3 — Emergency Contacts**
- Minimum 1, maximum 3 contacts
- Each: Name, Relation, Phone Number

**Step 4 — Medical Information**
- Blood Group (A+, A−, B+, B−, AB+, AB−, O+, O−) + **Blood Group Proof document** (upload)
- Recent Medical Details (text) + **Medical document / report** (upload)
- Infections / Diseases (text or checkboxes: Diabetes, BP, Asthma, Heart disease, Epilepsy, Other)
- Allergies (text, optional)

**Step 5 — Review & Submit**
- User reviews all details and submits.
- Account status becomes **Pending Verification**.

#### 5.1.2 QR Code
- A QR is generated automatically after registration.
- QR contains **only a unique ID (UUID / secure token)**, not the actual medical data. Data is fetched from Supabase after scanning.
- User can view the QR on dashboard, **save as image**, and **share/print** it.
- QR keeps working even if info is later edited (same ID, updated data).

#### 5.1.3 User Dashboard (final screen the user sees)
- Profile photo, name, age, gender
- **Verification status** badge: Pending / Verified / Rejected (with reason if rejected)
- **Blood Group** with verified badge (if proof approved)
- Medical summary (conditions, allergies, recent medical)
- Emergency contacts list
- **My QR Code** (large, with Download / Share button)
- Edit Profile button (editing re-submits documents for verification if documents are changed)
- Logout

---

### 5.2 Doctor Module

#### 5.2.1 Doctor Registration
- Email, Password, Confirm Password
- Full Name
- Profile Photo
- Phone Number
- Gender (optional) / Age (optional)
- **Degree** (e.g., MBBS, MD) + **Degree Certificate** (upload)
- **MBBS / Medical Registration Number** (required)
- **State Medical Council** (name of council that issued registration)
- Hospital / Clinic name (optional, basic)
- Any ID proof (e.g., Aadhaar / Govt ID) upload — to confirm identity

#### 5.2.2 Doctor Status
- After registration: **Pending Verification** — doctor can log in but **cannot scan/see medical data** until approved.
- If Rejected: sees reason and can re-upload documents.

#### 5.2.3 Doctor Dashboard
- Doctor's name, photo, verification status
- **Scan QR** button (opens camera)
- Recently scanned patients (list of name + time)
- Logout

---

### 5.3 Admin Module

Admin's work is **only profile and document verification**.

#### 5.3.1 Admin Registration & Login
- **Registration:** Admin creates their own account from the app using **Email + Password + Confirm Password** only (selected via the **Admin** option of the role toggle). Role is saved as `admin`.
- **Login:** on the common Login page, Admin selects the **Admin** toggle and enters Email + Password.

#### 5.3.2 Admin Dashboard
- Counts: Pending Users, Pending Doctors, Verified, Rejected
- Two tabs: **Users** and **Doctors**, each with a pending list

#### 5.3.3 Verification Flow
1. Admin opens a pending request.
2. Sees submitted details and documents (viewed through signed URLs):
   - User: photo, name, blood group proof, medical document
   - Doctor: photo, name, degree certificate, MBBS registration number, ID proof
3. Admin chooses **Approve** or **Reject** (rejection requires a reason).
4. Status is updated; the applicant sees the new status on their dashboard.

> Admin sees **only what is needed for verification** (uploaded documents + basic details). Admin does not browse or edit any other medical data.

---

### 5.4 QR Scanning Module

Scanning opens the camera, reads the QR, extracts the unique ID, and fetches the person's data.

#### Who sees what

| Information | Third Person (no login) | Verified Doctor |
|-------------|:-:|:-:|
| Photo | ✅ | ✅ |
| Name, Age, Gender | ✅ | ✅ |
| Blood Group (+ verified badge) | ✅ | ✅ |
| Infections / Diseases / Allergies | ✅ | ✅ |
| Emergency Contacts (Call button) | ✅ | ✅ |
| User's own contact number | ❌ | ✅ |
| Recent medical details | ❌ | ✅ |
| Uploaded medical documents | ❌ | ✅ |

- The scan result screen has a big **"Call Emergency Contact"** button for each contact.
- If the QR is invalid / user not found → show an error message.
- If the User is not yet verified → data is still shown but with a **"Not Verified"** warning label.

#### Scan log
Every scan stores: scanned user, scanner (doctor id or "guest"), time. (Used for the Doctor's "recent scans" list.)

---

## 6. User Flows

**User flow**
`Register → Fill basic + medical + contacts + documents → Submit → QR generated → Admin verifies → Dashboard shows Verified + QR`

**Doctor flow**
`Register → Upload degree + MBBS no. → Admin verifies → Login → Scan QR → View patient info`

**Third person flow**
`Open app → Scan QR (no login) → View emergency info → Call emergency contact`

**Admin flow**
`Register (email + password) → Login with Admin toggle → Dashboard → Open pending request → Check documents → Approve / Reject`

---

## 7. Screen List

| # | Screen | Role |
|---|--------|------|
| 1 | Splash | All |
| 2 | Welcome (Login / Register / Scan QR as Guest) | All |
| 3 | Login (common page with User / Doctor / Admin role toggle) | All |
| 4 | Register — choose role (User / Doctor / Admin) | All |
| 5 | User Registration (5 steps) | User |
| 6 | Doctor Registration | Doctor |
| 6a | Admin Registration (email + password) | Admin |
| 7 | User Dashboard (with QR) | User |
| 8 | Edit Profile | User |
| 9 | Doctor Dashboard | Doctor |
| 10 | QR Scanner | Doctor / Guest |
| 11 | Scan Result — limited view | Guest |
| 12 | Scan Result — full view | Doctor |
| 13 | Admin Dashboard | Admin |
| 14 | Pending List (Users / Doctors) | Admin |
| 15 | Verification Detail (documents + Approve/Reject) | Admin |

---

## 8. Database Design (Supabase PostgreSQL)

### `profiles`
| Column | Type | Notes |
|--------|------|-------|
| id | uuid (PK) | = `auth.users.id` |
| role | text | `user` / `doctor` / `admin` |
| full_name | text | |
| photo_url | text | path in storage |
| phone | text | |
| gender | text | |
| age | int | |
| verification_status | text | `pending` / `verified` / `rejected` |
| rejection_reason | text | nullable |
| qr_token | uuid | unique, used in QR (users only) |
| created_at | timestamptz | |

### `medical_info` (users only)
| Column | Type |
|--------|------|
| user_id | uuid (FK → profiles) |
| blood_group | text |
| blood_group_proof_url | text |
| blood_group_verified | boolean |
| recent_medical | text |
| medical_doc_url | text |
| diseases | text[] |
| allergies | text |

### `emergency_contacts`
| Column | Type |
|--------|------|
| id | uuid (PK) |
| user_id | uuid (FK → profiles) |
| name | text |
| relation | text |
| phone | text |

### `doctor_details`
| Column | Type |
|--------|------|
| doctor_id | uuid (FK → profiles) |
| degree | text |
| degree_doc_url | text |
| registration_no | text |
| medical_council | text |
| id_proof_url | text |
| hospital | text (optional) |

### `scan_logs`
| Column | Type |
|--------|------|
| id | uuid (PK) |
| scanned_user_id | uuid |
| scanned_by | uuid (nullable → guest) |
| scanned_at | timestamptz |

---

## 9. Storage (Supabase Storage)

Private buckets (no public links):
- `profile-photos`
- `user-documents` (blood group proof, medical documents)
- `doctor-documents` (degree certificate, ID proof)

Files are accessed only via **signed URLs** with short expiry. Upload limits: images/PDF only, max 5 MB per file.

---

## 10. Security & Access Rules (RLS)

- A User can read/update **only their own** profile, medical info, and contacts.
- A Doctor can read patient full data **only if** `verification_status = 'verified'`.
- Guests (not logged in) can read **only the limited public fields** via a dedicated database view/function that takes `qr_token` — never direct table access.
- Admin can read documents and basic details of pending users/doctors and update `verification_status` only.
- Role is set once at registration and cannot be changed afterwards (enforced by RLS: users cannot update their own `role`).
- Raw QR content has no medical data — only the token.
- Passwords are handled entirely by Supabase Auth (never stored by the app).

---

## 11. Non-Functional Requirements

- **Simplicity:** clean UI, large buttons, readable in emergency conditions.
- **Speed:** scan result should appear within ~3 seconds on normal internet.
- **Validation:** required fields, valid phone (10 digits), valid email, age range 1–120.
- **Error handling:** clear messages for no internet, invalid QR, upload failure.
- **Privacy:** sensitive data protected as per Section 10.
- **Compatibility:** Android 8.0+ (iOS optional).
- **Permissions:** Camera (QR scan, photo), Storage/Gallery (document upload), Phone call (contacts).

---

## 12. Out of Scope (NOT being built)

- Hospital / system-administrator roles
- Multi-language support
- Offline mode
- Maps / location sharing
- Push notifications, chat, appointments, prescriptions
- Automated / third-party (DigiLocker, Aadhaar API) verification — verification is **manual by Admin only**
- Payments, analytics, reports

---

## 13. Development Phases

| Phase | Work |
|-------|------|
| 1 | Supabase setup: project, tables, RLS, storage buckets |
| 2 | Flutter setup: folder structure, theme, routing, Supabase connection |
| 3 | Authentication: login, role-based routing, User & Doctor registration |
| 4 | User profile: medical info, contacts, uploads, QR generation, User dashboard |
| 5 | Admin: dashboard, pending lists, document viewing, approve/reject |
| 6 | Doctor: dashboard, QR scanner, limited & full scan result screens |
| 7 | Testing (all roles end-to-end), bug fixing, final polish |

---

## 14. Success Criteria

- A user can register with all details and documents and receive a working QR.
- Admin can verify/reject a user or doctor with documents visible.
- A verified Doctor can scan a QR and see full information.
- A third person can scan a QR and see only limited emergency information and call a contact.
- Unverified doctors cannot access medical data.
- All three roles (User, Doctor, Admin) can register themselves, log in from the same page using the role toggle, and land on the correct dashboard.
