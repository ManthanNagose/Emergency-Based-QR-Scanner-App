# Suraksha QR - Emergency QR Scanner Application

A Flutter mobile application that allows users to store their emergency medical information and generate a QR code. In emergencies, first responders, doctors, or bystanders can scan the QR code to access critical medical information.

## Features

- **User Registration**: 5-step form with profile photo, basic info, emergency contacts, and medical information
- **Doctor Registration**: Professional credentials with document uploads
- **Admin Registration**: Simple email/password for verification authority
- **QR Code Generation**: Unique QR code containing only a token (no medical data)
- **QR Scanning**: Camera-based scanning with flashlight toggle
- **Role-based Access**: 
  - Guests see limited emergency info (photo, name, blood group, conditions, emergency contacts with call buttons)
  - Verified doctors see full medical details including documents
- **Admin Dashboard**: Pending user/doctor counts, verification queues, document review, approve/reject
- **Profile Management**: Edit profile, update documents (triggers re-verification)

## Tech Stack

- **Frontend**: Flutter (Dart)
- **State Management**: Riverpod
- **Navigation**: GoRouter
- **Backend**: Supabase (Auth + PostgreSQL + Storage)
- **QR**: qr_flutter (generation), mobile_scanner (scanning)
- **Storage**: Supabase Storage (private buckets with signed URLs)

## Prerequisites

- Flutter SDK 3.19+
- Dart SDK 3.3+
- Supabase account
- Android Studio / VS Code with Flutter extensions

## Setup

### 1. Clone and Install Dependencies

```bash
cd suraksha_qr
flutter pub get
```

### 2. Supabase Setup

1. Create a new Supabase project at https://supabase.com
2. Go to Project Settings → API to get your Project URL and anon key
3. Run the database schema in Supabase SQL Editor:
   - Copy contents of `supabase/schema.sql`
   - Paste into SQL Editor and run
4. Create storage buckets in Supabase Storage:
   - `profile-photos` (public)
   - `user-documents` (private)
   - `doctor-documents` (private)
5. Apply storage policies from `supabase/schema.sql` (commented section G)

### 3. Configure Environment

Create `.env` file in the project root:

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

### 4. Run the App

```bash
# Chrome (web)
flutter run -d chrome

# Android
flutter run -d android

# iOS (macOS only)
flutter run -d ios
```

## Project Structure

```
lib/
├── core/
│   ├── constants/       # App constants, validation rules
│   ├── theme/           # Material 3 theme (emergency red/white)
│   ├── router.dart      # GoRouter configuration with auth guards
│   └── supabase_client.dart
├── models/              # Data models (AppProfile, MedicalInfo, etc.)
├── repositories/        # Auth, Storage repositories
├── providers/           # Riverpod providers
├── features/
│   ├── auth/            # Splash, Welcome, Login, Register screens
│   ├── user/            # User registration, dashboard, edit profile
│   ├── doctor/          # Doctor registration, dashboard
│   ├── admin/           # Admin dashboard, verification detail
│   └── scanner/         # QR scanner, limited/full result screens
└── widgets/             # Reusable UI components (buttons, fields, badges)
```

## Database Schema

Key tables (see `supabase/schema.sql`):
- `profiles` - All users (role: user/doctor/admin)
- `medical_info` - User medical data
- `emergency_contacts` - 1-3 contacts per user
- `doctor_details` - Doctor professional info
- `scan_logs` - Audit trail of scans

RLS policies enforce:
- Users can only access their own data
- Doctors see patient data only via RPC (after verification)
- Admins can view pending verification documents
- No direct table access for medical data

## User Flows

### User Registration → Admin Verification → QR Code
1. User completes 5-step registration
2. Admin views pending users in dashboard
3. Admin approves/rejects with document review
4. User dashboard shows QR code (verified status)

### Doctor Registration → Admin Verification → Scan
1. Doctor registers with credentials
2. Admin verifies doctor credentials
3. Doctor dashboard enables QR scanning
4. Scanning shows full medical info

### Guest Scan
1. No login required
2. Scan QR → Limited emergency info
4. Call emergency contacts directly

### Wrong Role Login
- Login screen has role toggle (User/Doctor/Admin)
- Entering wrong role shows: "This account is not registered as [Role]"

## Security

- Medical data never stored in QR code (only UUID token)
- Supabase RLS policies enforce data isolation
- Signed URLs for document access (10 min expiry)
- File uploads restricted to 5MB, images/PDFs only
- No hardcoded secrets (`.env` in `.gitignore`)

## Build

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release

# Web
flutter build web
```

## License

Proprietary - Suraksha QR Project