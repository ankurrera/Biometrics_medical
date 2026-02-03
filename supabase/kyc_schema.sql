-- CareSync KYC and Enhanced Authentication Schema
-- Run this after the main schema.sql

-- ============================================================================
-- KYC VERIFICATIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS kyc_verifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    date_of_birth DATE NOT NULL,
    id_document_url TEXT, -- S3/Supabase Storage URL for ID proof
    selfie_url TEXT, -- S3/Supabase Storage URL for selfie
    additional_documents JSONB, -- Array of additional document URLs
    kyc_status TEXT NOT NULL DEFAULT 'pending' CHECK (kyc_status IN ('pending', 'verified', 'rejected')),
    rejection_reason TEXT,
    verified_at TIMESTAMPTZ,
    verified_by UUID REFERENCES auth.users(id), -- Admin who verified
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- ============================================================================
-- REGISTERED DEVICES TABLE (Enhanced device management)
-- ============================================================================
CREATE TABLE IF NOT EXISTS registered_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL, -- Unique device identifier
    device_name TEXT NOT NULL, -- "iPhone 13", "Samsung Galaxy S21"
    platform TEXT CHECK (platform IN ('ios', 'android', 'web')),
    device_model TEXT,
    os_version TEXT,
    biometric_enabled BOOLEAN DEFAULT FALSE,
    registered_at TIMESTAMPTZ DEFAULT NOW(),
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    revoked BOOLEAN DEFAULT FALSE, -- User can revoke device access
    revoked_at TIMESTAMPTZ,
    UNIQUE(user_id, device_id)
);

-- ============================================================================
-- MEDICAL RECORDS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS medical_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    record_type TEXT NOT NULL CHECK (record_type IN ('prescription', 'lab_result', 'diagnosis', 'other')),
    record_title TEXT NOT NULL,
    record_data JSONB NOT NULL, -- Flexible structure for different record types
    document_url TEXT, -- Optional document/file URL
    is_public BOOLEAN DEFAULT FALSE, -- Visible to first responders
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    accessed_at TIMESTAMPTZ, -- Track when last accessed
    accessed_from_device UUID REFERENCES registered_devices(id)
);

-- ============================================================================
-- TWO FACTOR CODES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS two_factor_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    code_type TEXT NOT NULL CHECK (code_type IN ('email', 'sms')),
    expires_at TIMESTAMPTZ NOT NULL,
    verified BOOLEAN DEFAULT FALSE,
    verified_at TIMESTAMPTZ,
    attempts INT DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for faster lookups
CREATE INDEX idx_two_factor_codes_user_id ON two_factor_codes(user_id);
CREATE INDEX idx_two_factor_codes_expires_at ON two_factor_codes(expires_at);

-- ============================================================================
-- AUDIT LOG TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS audit_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action TEXT NOT NULL, -- 'view_medical_record', 'login', 'kyc_upload', etc.
    resource_type TEXT, -- 'medical_record', 'prescription', etc.
    resource_id UUID,
    device_id TEXT,
    ip_address TEXT,
    user_agent TEXT,
    metadata JSONB, -- Additional context
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Index for efficient querying
CREATE INDEX idx_audit_log_user_id ON audit_log(user_id);
CREATE INDEX idx_audit_log_timestamp ON audit_log(timestamp);
CREATE INDEX idx_audit_log_action ON audit_log(action);

-- ============================================================================
-- STORAGE BUCKET FOR KYC DOCUMENTS
-- ============================================================================
-- Note: Create this bucket manually in Supabase dashboard:
-- 1. Go to Storage in Supabase dashboard
-- 2. Click "Create a new bucket"
-- 3. Set name to "kyc-documents"
-- 4. Uncheck "Public bucket" (keep it private)
-- 5. Click "Create bucket"
--
-- Alternative: Use Supabase CLI:
-- supabase storage create kyc-documents --private
--
-- SQL insert may not work in all Supabase environments

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on all new tables
ALTER TABLE kyc_verifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE registered_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE two_factor_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

-- KYC VERIFICATIONS POLICIES
CREATE POLICY "Users can view their own KYC data"
    ON kyc_verifications FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own KYC data"
    ON kyc_verifications FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own pending KYC data"
    ON kyc_verifications FOR UPDATE
    USING (auth.uid() = user_id AND kyc_status = 'pending');

-- Admin policies for KYC verification (you can create admin role later)
-- CREATE POLICY "Admins can view all KYC data"
--     ON kyc_verifications FOR SELECT
--     USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'admin');

-- REGISTERED DEVICES POLICIES
CREATE POLICY "Users can view their own devices"
    ON registered_devices FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own devices"
    ON registered_devices FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own devices"
    ON registered_devices FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own devices"
    ON registered_devices FOR DELETE
    USING (auth.uid() = user_id);

-- MEDICAL RECORDS POLICIES
CREATE POLICY "Users can view their own medical records"
    ON medical_records FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own medical records"
    ON medical_records FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own medical records"
    ON medical_records FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own medical records"
    ON medical_records FOR DELETE
    USING (auth.uid() = user_id);

-- Doctors can view patient medical records (extend as needed)
CREATE POLICY "Doctors can view medical records"
    ON medical_records FOR SELECT
    USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'doctor');

-- TWO FACTOR CODES POLICIES
CREATE POLICY "Users can view their own 2FA codes"
    ON two_factor_codes FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can insert 2FA codes"
    ON two_factor_codes FOR INSERT
    WITH CHECK (true); -- Allow insertion from server functions

CREATE POLICY "Users can update their own 2FA codes"
    ON two_factor_codes FOR UPDATE
    USING (auth.uid() = user_id);

-- AUDIT LOG POLICIES
CREATE POLICY "Users can view their own audit logs"
    ON audit_log FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "System can insert audit logs"
    ON audit_log FOR INSERT
    WITH CHECK (true); -- Allow insertion from any authenticated context

-- ============================================================================
-- STORAGE POLICIES FOR KYC DOCUMENTS
-- ============================================================================

-- Policy to allow users to upload their KYC documents
CREATE POLICY "Users can upload their own KYC documents"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'kyc-documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy to allow users to view their own KYC documents
CREATE POLICY "Users can view their own KYC documents"
ON storage.objects FOR SELECT
TO authenticated
USING (
  bucket_id = 'kyc-documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy to allow users to update their own KYC documents
CREATE POLICY "Users can update their own KYC documents"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'kyc-documents' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- Function to clean up expired 2FA codes (run periodically)
CREATE OR REPLACE FUNCTION cleanup_expired_2fa_codes()
RETURNS void AS $$
BEGIN
    DELETE FROM two_factor_codes
    WHERE expires_at < NOW() - INTERVAL '1 hour';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to log access to medical records
CREATE OR REPLACE FUNCTION log_medical_record_access()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_log (user_id, action, resource_type, resource_id, timestamp)
    VALUES (auth.uid(), 'view_medical_record', 'medical_record', NEW.id, NOW());
    
    NEW.accessed_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to log medical record access
DROP TRIGGER IF EXISTS on_medical_record_accessed ON medical_records;
CREATE TRIGGER on_medical_record_accessed
    BEFORE UPDATE ON medical_records
    FOR EACH ROW
    WHEN (OLD.accessed_at IS DISTINCT FROM NEW.accessed_at)
    EXECUTE FUNCTION log_medical_record_access();

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_kyc_verifications_user_id ON kyc_verifications(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_verifications_status ON kyc_verifications(kyc_status);
CREATE INDEX IF NOT EXISTS idx_registered_devices_user_id ON registered_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_registered_devices_device_id ON registered_devices(device_id);
CREATE INDEX IF NOT EXISTS idx_medical_records_user_id ON medical_records(user_id);
CREATE INDEX IF NOT EXISTS idx_medical_records_type ON medical_records(record_type);
