-- ============================================================
-- SURAKSHA QR - Supabase Schema
-- Run this in Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- A) TABLES
-- ============================================================

-- profiles: one row per auth user
CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    role text NOT NULL CHECK (role IN ('user','doctor','admin')) DEFAULT 'user',
    full_name text,
    photo_url text,
    phone text,
    gender text,
    age int,
    verification_status text NOT NULL CHECK (verification_status IN ('pending','verified','rejected')) DEFAULT 'pending',
    rejection_reason text,
    qr_token uuid UNIQUE DEFAULT gen_random_uuid(),
    created_at timestamptz NOT NULL DEFAULT now()
);

-- medical_info: medical details for users only
CREATE TABLE IF NOT EXISTS public.medical_info (
    user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    blood_group text CHECK (blood_group IN ('A+','A-','B+','B-','AB+','AB-','O+','O-')),
    blood_group_proof_url text,
    blood_group_verified boolean NOT NULL DEFAULT false,
    recent_medical text,
    medical_doc_url text,
    diseases text[] NOT NULL DEFAULT '{}',
    allergies text
);

-- emergency_contacts: 1-3 contacts per user
CREATE TABLE IF NOT EXISTS public.emergency_contacts (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    name text NOT NULL,
    relation text NOT NULL,
    phone text NOT NULL CHECK (phone ~ '^\d{10}$')
);

-- doctor_details: professional info for doctors
CREATE TABLE IF NOT EXISTS public.doctor_details (
    doctor_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    degree text NOT NULL,
    degree_doc_url text,
    registration_no text NOT NULL,
    medical_council text NOT NULL,
    id_proof_url text,
    hospital text
);

-- scan_logs: audit trail of every scan
CREATE TABLE IF NOT EXISTS public.scan_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    scanned_user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    scanned_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    scanned_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.medical_info ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.doctor_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.scan_logs ENABLE ROW LEVEL SECURITY;

-- B) TRIGGER: auto-create profile on user signup
-- ============================================================

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, role, full_name, verification_status)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'role', 'user'),
        NEW.raw_user_meta_data->>'full_name',
        CASE WHEN COALESCE(NEW.raw_user_meta_data->>'role', 'user') = 'admin' THEN 'verified' ELSE 'pending' END
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- C) HELPER FUNCTIONS
-- ============================================================

-- is_admin(): true if caller is an admin
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
$$;

-- is_verified_doctor(): true if caller is a verified doctor
CREATE OR REPLACE FUNCTION public.is_verified_doctor()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'doctor' AND verification_status = 'verified'
    );
$$;

-- D) PROTECTION TRIGGER: block non-admin changes to sensitive columns
-- ============================================================

CREATE OR REPLACE FUNCTION public.protect_sensitive_profile_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Allow admin to change anything
    IF public.is_admin() THEN
        RETURN NEW;
    END IF;

    -- Block changes to role, verification_status, qr_token
    IF OLD.role IS DISTINCT FROM NEW.role THEN
        RAISE EXCEPTION 'Cannot change role';
    END IF;
    IF OLD.verification_status IS DISTINCT FROM NEW.verification_status THEN
        RAISE EXCEPTION 'Cannot change verification_status';
    END IF;
    IF OLD.qr_token IS DISTINCT FROM NEW.qr_token THEN
        RAISE EXCEPTION 'Cannot change qr_token';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS protect_profile_sensitive_columns ON public.profiles;
CREATE TRIGGER protect_profile_sensitive_columns
BEFORE UPDATE ON public.profiles
FOR EACH ROW EXECUTE FUNCTION public.protect_sensitive_profile_columns();

-- E) RLS POLICIES
-- ============================================================

-- profiles: user reads/updates own; admin reads all
CREATE POLICY "profiles_self_select" ON public.profiles
FOR SELECT USING (auth.uid() = id);

CREATE POLICY "profiles_self_update" ON public.profiles
FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "profiles_admin_select" ON public.profiles
FOR SELECT USING (public.is_admin());

-- medical_info: owner CRUD; admin SELECT (to view proofs)
CREATE POLICY "medical_info_owner_select" ON public.medical_info
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "medical_info_owner_insert" ON public.medical_info
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "medical_info_owner_update" ON public.medical_info
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "medical_info_owner_delete" ON public.medical_info
FOR DELETE USING (auth.uid() = user_id);

CREATE POLICY "medical_info_admin_select" ON public.medical_info
FOR SELECT USING (public.is_admin());

-- emergency_contacts: owner CRUD only
CREATE POLICY "emergency_contacts_owner_select" ON public.emergency_contacts
FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "emergency_contacts_owner_insert" ON public.emergency_contacts
FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "emergency_contacts_owner_update" ON public.emergency_contacts
FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "emergency_contacts_owner_delete" ON public.emergency_contacts
FOR DELETE USING (auth.uid() = user_id);

-- doctor_details: owner CRUD; admin SELECT
CREATE POLICY "doctor_details_owner_select" ON public.doctor_details
FOR SELECT USING (auth.uid() = doctor_id);

CREATE POLICY "doctor_details_owner_insert" ON public.doctor_details
FOR INSERT WITH CHECK (auth.uid() = doctor_id);

CREATE POLICY "doctor_details_owner_update" ON public.doctor_details
FOR UPDATE USING (auth.uid() = doctor_id);

CREATE POLICY "doctor_details_admin_select" ON public.doctor_details
FOR SELECT USING (public.is_admin());

-- scan_logs: verified doctor reads own scans only
CREATE POLICY "scan_logs_doctor_select" ON public.scan_logs
FOR SELECT USING (public.is_verified_doctor() AND scanned_by = auth.uid());

-- F) RPC FUNCTIONS (Security Definer, callable via Supabase client)
-- ============================================================

-- 1. get_public_emergency_info: limited view for guests / third persons
CREATE OR REPLACE FUNCTION public.get_public_emergency_info(p_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile public.profiles%ROWTYPE;
    v_medical public.medical_info%ROWTYPE;
    v_contacts jsonb;
    v_scanner_id uuid := auth.uid(); -- null for anon
BEGIN
    -- Find profile by qr_token
    SELECT * INTO v_profile
    FROM public.profiles
    WHERE qr_token = p_token
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'QR code not found' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_medical
    FROM public.medical_info
    WHERE user_id = v_profile.id
    LIMIT 1;

    SELECT jsonb_agg(jsonb_build_object(
        'name', name,
        'relation', relation,
        'phone', phone
    )) INTO v_contacts
    FROM public.emergency_contacts
    WHERE user_id = v_profile.id;

    -- Log the scan (scanned_by = null for guest)
    INSERT INTO public.scan_logs (scanned_user_id, scanned_by)
    VALUES (v_profile.id, v_scanner_id);

    RETURN jsonb_build_object(
        'full_name', v_profile.full_name,
        'photo_url', v_profile.photo_url,
        'age', v_profile.age,
        'gender', v_profile.gender,
        'blood_group', v_medical.blood_group,
        'blood_group_verified', v_medical.blood_group_verified,
        'diseases', v_medical.diseases,
        'allergies', v_medical.allergies,
        'verification_status', v_profile.verification_status,
        'emergency_contacts', COALESCE(v_contacts, '[]'::jsonb)
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_public_emergency_info(uuid) TO anon, authenticated;

-- 2. get_full_medical_info: full view for verified doctors only
CREATE OR REPLACE FUNCTION public.get_full_medical_info(p_token uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_profile public.profiles%ROWTYPE;
    v_medical public.medical_info%ROWTYPE;
    v_contacts jsonb;
BEGIN
    IF NOT public.is_verified_doctor() THEN
        RAISE EXCEPTION 'Only verified doctors can access full medical info' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_profile
    FROM public.profiles
    WHERE qr_token = p_token
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'QR code not found' USING ERRCODE = 'P0001';
    END IF;

    SELECT * INTO v_medical
    FROM public.medical_info
    WHERE user_id = v_profile.id
    LIMIT 1;

    SELECT jsonb_agg(jsonb_build_object(
        'name', name,
        'relation', relation,
        'phone', phone
    )) INTO v_contacts
    FROM public.emergency_contacts
    WHERE user_id = v_profile.id;

    INSERT INTO public.scan_logs (scanned_user_id, scanned_by)
    VALUES (v_profile.id, auth.uid());

    RETURN jsonb_build_object(
        'full_name', v_profile.full_name,
        'photo_url', v_profile.photo_url,
        'age', v_profile.age,
        'gender', v_profile.gender,
        'blood_group', v_medical.blood_group,
        'blood_group_verified', v_medical.blood_group_verified,
        'diseases', v_medical.diseases,
        'allergies', v_medical.allergies,
        'verification_status', v_profile.verification_status,
        'emergency_contacts', COALESCE(v_contacts, '[]'::jsonb),
        'phone', v_profile.phone,
        'recent_medical', v_medical.recent_medical,
        'medical_doc_url', v_medical.medical_doc_url,
        'blood_group_proof_url', v_medical.blood_group_proof_url
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_full_medical_info(uuid) TO authenticated;

-- 3. set_verification: admin approves/rejects user or doctor
CREATE OR REPLACE FUNCTION public.set_verification(p_target uuid, p_status text, p_reason text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_admin() THEN
        RAISE EXCEPTION 'Admin only' USING ERRCODE = '42501';
    END IF;

    IF p_status NOT IN ('verified','rejected') THEN
        RAISE EXCEPTION 'Invalid status' USING ERRCODE = 'P0001';
    END IF;

    UPDATE public.profiles
    SET verification_status = p_status,
        rejection_reason = CASE WHEN p_status = 'rejected' THEN p_reason ELSE NULL END
    WHERE id = p_target;

    -- If verifying a user, also mark blood_group_verified
    IF p_status = 'verified' THEN
        UPDATE public.medical_info
        SET blood_group_verified = true
        WHERE user_id = p_target;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_verification(uuid, text, text) TO authenticated;

-- 4. resubmit_for_verification: user re-submits after editing docs
CREATE OR REPLACE FUNCTION public.resubmit_for_verification()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    UPDATE public.profiles
    SET verification_status = 'pending',
        rejection_reason = NULL
    WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.resubmit_for_verification() TO authenticated;

-- 5. get_recent_scans: doctor's last 20 scans
CREATE OR REPLACE FUNCTION public.get_recent_scans()
RETURNS TABLE (
    scanned_user_name text,
    scanned_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    IF NOT public.is_verified_doctor() THEN
        RAISE EXCEPTION 'Only verified doctors can view scan history' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT p.full_name, sl.scanned_at
    FROM public.scan_logs sl
    JOIN public.profiles p ON p.id = sl.scanned_user_id
    WHERE sl.scanned_by = auth.uid()
    ORDER BY sl.scanned_at DESC
    LIMIT 20;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_recent_scans() TO authenticated;

-- G) STORAGE BUCKETS & POLICIES
-- ============================================================

-- Create buckets (run in Supabase Storage or via SQL if using supabase-js)
-- Note: Bucket creation via SQL requires supabase_storage extension; 
-- typically done in Dashboard. Included here for reference.

-- INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
-- VALUES
--   ('profile-photos', 'profile-photos', true, 5242880, ARRAY['image/jpeg','image/png','image/webp']),
--   ('user-documents', 'user-documents', false, 5242880, ARRAY['image/jpeg','image/png','application/pdf']),
--   ('doctor-documents', 'doctor-documents', false, 5242880, ARRAY['image/jpeg','image/png','application/pdf'])
-- ON CONFLICT (id) DO NOTHING;

-- Storage policies (run after buckets exist)

-- profile-photos: anyone can read; authenticated users write to own folder
-- CREATE POLICY "profile_photos_public_read" ON storage.objects
-- FOR SELECT USING (bucket_id = 'profile-photos');

-- CREATE POLICY "profile_photos_owner_write" ON storage.objects
-- FOR INSERT TO authenticated
-- WITH CHECK (
--     bucket_id = 'profile-photos' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- CREATE POLICY "profile_photos_owner_update" ON storage.objects
-- FOR UPDATE TO authenticated
-- USING (
--     bucket_id = 'profile-photos' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- CREATE POLICY "profile_photos_owner_delete" ON storage.objects
-- FOR DELETE TO authenticated
-- USING (
--     bucket_id = 'profile-photos' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- user-documents: owner and admin read; verified doctors read; owner write
-- CREATE POLICY "user_docs_owner_read" ON storage.objects
-- FOR SELECT TO authenticated
-- USING (
--     bucket_id = 'user-documents' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- CREATE POLICY "user_docs_admin_read" ON storage.objects
-- FOR SELECT TO authenticated
-- USING (
--     bucket_id = 'user-documents' AND
--     public.is_admin()
-- );

-- CREATE POLICY "user_docs_doctor_read" ON storage.objects
-- FOR SELECT TO authenticated
-- USING (
--     bucket_id = 'user-documents' AND
--     public.is_verified_doctor()
-- );

-- CREATE POLICY "user_docs_owner_write" ON storage.objects
-- FOR INSERT TO authenticated
-- WITH CHECK (
--     bucket_id = 'user-documents' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- CREATE POLICY "user_docs_owner_update" ON storage.objects
-- FOR UPDATE TO authenticated
-- USING (
--     bucket_id = 'user-documents' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- CREATE POLICY "user_docs_owner_delete" ON storage.objects
-- FOR DELETE TO authenticated
-- USING (
--     bucket_id = 'user-documents' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- doctor-documents: owner and admin read; owner write
-- CREATE POLICY "doctor_docs_owner_read" ON storage.objects
-- FOR SELECT TO authenticated
-- USING (
--     bucket_id = 'doctor-documents' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- CREATE POLICY "doctor_docs_admin_read" ON storage.objects
-- FOR SELECT TO authenticated
-- USING (
--     bucket_id = 'doctor-documents' AND
--     public.is_admin()
-- );

-- CREATE POLICY "doctor_docs_owner_write" ON storage.objects
-- FOR INSERT TO authenticated
-- WITH CHECK (
--     bucket_id = 'doctor-documents' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- CREATE POLICY "doctor_docs_owner_update" ON storage.objects
-- FOR UPDATE TO authenticated
-- USING (
--     bucket_id = 'doctor-documents' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- CREATE POLICY "doctor_docs_owner_delete" ON storage.objects
-- FOR DELETE TO authenticated
-- USING (
--     bucket_id = 'doctor-documents' AND
--     (storage.foldername(name))[1] = auth.uid()::text
-- );

-- ============================================================
-- SECTION SUMMARY
-- A) Tables: profiles, medical_info, emergency_contacts, doctor_details, scan_logs with RLS enabled
-- B) Trigger: auto-create profile on auth.users insert with role from metadata
-- C) Helpers: is_admin(), is_verified_doctor() security definer functions
-- D) Protection: BEFORE UPDATE trigger blocks non-admin changes to role, verification_status, qr_token
-- E) RLS: Owner-only access for medical_info, emergency_contacts, doctor_details; admin SELECT; doctor SELECT own scans
-- F) RPCs: get_public_emergency_info (anon+auth), get_full_medical_info (verified doctor), set_verification (admin), resubmit_for_verification (user), get_recent_scans (verified doctor)
-- G) Storage: 3 buckets (profile-photos public, user-documents private, doctor-documents private) with folder-per-user policies
-- ============================================================