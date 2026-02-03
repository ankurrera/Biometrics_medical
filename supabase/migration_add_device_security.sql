-- Migration to add token_fingerprint and trusted columns to registered_devices
-- Run this after kyc_schema.sql

-- Add token_fingerprint column for device binding security
ALTER TABLE registered_devices 
ADD COLUMN IF NOT EXISTS token_fingerprint TEXT;

-- Add trusted column to mark devices as trusted after biometric enrollment
ALTER TABLE registered_devices 
ADD COLUMN IF NOT EXISTS trusted BOOLEAN DEFAULT TRUE;

-- Add index for faster fingerprint lookups
CREATE INDEX IF NOT EXISTS idx_registered_devices_fingerprint 
ON registered_devices(user_id, token_fingerprint);

-- Comment the columns
COMMENT ON COLUMN registered_devices.token_fingerprint IS 'SHA-256 hash of access_token + device_id for secure device binding';
COMMENT ON COLUMN registered_devices.trusted IS 'Indicates if device has completed full biometric enrollment and verification';
