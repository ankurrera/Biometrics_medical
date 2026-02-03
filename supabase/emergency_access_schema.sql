-- Emergency "Break Glass" Access Schema
-- Allows doctors and first responders to access patient records in emergencies

-- ═══════════════════════════════════════════════════════════════════════════
-- EMERGENCY ACCESS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS emergency_access (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  requester_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  requester_role TEXT NOT NULL CHECK (requester_role IN ('doctor', 'first_responder')),
  patient_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  reason TEXT NOT NULL,
  additional_notes TEXT,
  granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL,
  revoked_at TIMESTAMPTZ,
  biometric_verified BOOLEAN NOT NULL DEFAULT false,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'expired', 'revoked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES
-- ═══════════════════════════════════════════════════════════════════════════

-- Index for querying active access by requester
CREATE INDEX idx_emergency_access_requester 
ON emergency_access(requester_id, status, expires_at);

-- Index for querying access history by patient
CREATE INDEX idx_emergency_access_patient 
ON emergency_access(patient_id, granted_at DESC);

-- Index for querying active access
CREATE INDEX idx_emergency_access_active 
ON emergency_access(status, expires_at) 
WHERE status = 'active';

-- ═══════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS)
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE emergency_access ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view their own emergency access records
CREATE POLICY "Users can view their own emergency access requests"
ON emergency_access
FOR SELECT
TO authenticated
USING (auth.uid() = requester_id);

-- Policy: Users can view emergency access records for their patients
CREATE POLICY "Patients can view emergency access to their records"
ON emergency_access
FOR SELECT
TO authenticated
USING (auth.uid() = patient_id);

-- Policy: Doctors and first responders can create emergency access
CREATE POLICY "Doctors and first responders can request emergency access"
ON emergency_access
FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() = requester_id
  AND EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('doctor', 'first_responder')
  )
);

-- Policy: Users can revoke their own emergency access
CREATE POLICY "Users can revoke their own emergency access"
ON emergency_access
FOR UPDATE
TO authenticated
USING (auth.uid() = requester_id)
WITH CHECK (auth.uid() = requester_id);

-- ═══════════════════════════════════════════════════════════════════════════
-- ADD METADATA COLUMN TO PRESCRIPTIONS (if not exists)
-- ═══════════════════════════════════════════════════════════════════════════

-- Add metadata column to prescriptions table for biometric verification
-- This requires that the prescriptions table already exists from the main schema
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'prescriptions') THEN
    ALTER TABLE prescriptions 
    ADD COLUMN IF NOT EXISTS metadata JSONB;

    -- Create index on metadata for efficient queries
    CREATE INDEX IF NOT EXISTS idx_prescriptions_metadata 
    ON prescriptions USING gin(metadata);
  ELSE
    RAISE NOTICE 'prescriptions table does not exist. Please run main schema first.';
  END IF;
END $$;

-- ═══════════════════════════════════════════════════════════════════════════
-- HELPER FUNCTIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Function to auto-expire emergency access records
CREATE OR REPLACE FUNCTION expire_emergency_access()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE emergency_access
  SET status = 'expired'
  WHERE status = 'active'
  AND expires_at < NOW();
END;
$$;

-- Function to check if user has active emergency access to a patient
CREATE OR REPLACE FUNCTION has_emergency_access(
  p_requester_id UUID,
  p_patient_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1
    FROM emergency_access
    WHERE requester_id = p_requester_id
    AND patient_id = p_patient_id
    AND status = 'active'
    AND expires_at > NOW()
  );
END;
$$;

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMENTS
-- ═══════════════════════════════════════════════════════════════════════════

COMMENT ON TABLE emergency_access IS 'Emergency "break glass" access to patient records';
COMMENT ON COLUMN emergency_access.requester_id IS 'Doctor or first responder requesting access';
COMMENT ON COLUMN emergency_access.requester_role IS 'Role of the requester (doctor or first_responder)';
COMMENT ON COLUMN emergency_access.patient_id IS 'Patient whose records are being accessed';
COMMENT ON COLUMN emergency_access.reason IS 'Reason for emergency access';
COMMENT ON COLUMN emergency_access.granted_at IS 'When access was granted';
COMMENT ON COLUMN emergency_access.expires_at IS 'When access expires (15 minutes from grant)';
COMMENT ON COLUMN emergency_access.revoked_at IS 'When access was manually revoked';
COMMENT ON COLUMN emergency_access.biometric_verified IS 'Whether biometric authentication was used';
COMMENT ON COLUMN emergency_access.status IS 'Current status (active, expired, revoked)';

-- ═══════════════════════════════════════════════════════════════════════════
-- CRON JOB (Optional - requires pg_cron extension)
-- ═══════════════════════════════════════════════════════════════════════════

-- Uncomment if you have pg_cron extension enabled:
-- SELECT cron.schedule(
--   'expire-emergency-access',
--   '*/5 * * * *', -- Every 5 minutes
--   'SELECT expire_emergency_access();'
-- );

-- ═══════════════════════════════════════════════════════════════════════════
-- GRANT PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════

-- Grant execute permissions on helper functions
GRANT EXECUTE ON FUNCTION expire_emergency_access() TO authenticated;
GRANT EXECUTE ON FUNCTION has_emergency_access(UUID, UUID) TO authenticated;
