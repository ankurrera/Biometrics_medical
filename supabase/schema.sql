-- CareSync Database Schema
-- Run this in your Supabase SQL Editor

-- ============================================================================
-- EXTENSIONS
-- ============================================================================
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- PROFILES TABLE (extends auth.users)
-- ============================================================================
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL,
    phone TEXT,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('patient', 'doctor', 'pharmacist', 'first_responder')),
    avatar_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger to create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, email, full_name, role)
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(NEW.raw_user_meta_data->>'full_name', 'User'),
        COALESCE(NEW.raw_user_meta_data->>'role', 'patient')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================================
-- USER DEVICES TABLE (for biometric binding)
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    device_id TEXT NOT NULL,
    device_name TEXT,
    platform TEXT CHECK (platform IN ('ios', 'android', 'web')),
    enrolled_at TIMESTAMPTZ DEFAULT NOW(),
    last_used_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(user_id, device_id)
);

-- ============================================================================
-- PATIENTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS patients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    blood_type TEXT CHECK (blood_type IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', NULL)),
    date_of_birth DATE,
    emergency_contact JSONB, -- { name, phone, relationship }
    qr_code_id TEXT UNIQUE DEFAULT uuid_generate_v4()::TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- DOCTORS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS doctors (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    license_number TEXT,
    specialization TEXT,
    hospital_affiliation TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PHARMACISTS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS pharmacists (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    license_number TEXT,
    pharmacy_name TEXT,
    pharmacy_address TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- FIRST RESPONDERS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS first_responders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
    badge_number TEXT,
    organization TEXT,
    certification_type TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PRESCRIPTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS prescriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    doctor_id UUID REFERENCES profiles(id), -- nullable for patient-entered
    diagnosis TEXT NOT NULL,
    notes TEXT,
    is_public BOOLEAN DEFAULT FALSE, -- visible to first responders
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'cancelled')),
    patient_entered BOOLEAN DEFAULT FALSE, -- flag prescriptions created by patients
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- PRESCRIPTION ITEMS TABLE (individual medicines)
-- ============================================================================
CREATE TABLE IF NOT EXISTS prescription_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prescription_id UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
    medicine_name TEXT NOT NULL,
    dosage TEXT NOT NULL,
    frequency TEXT NOT NULL, -- e.g., "Twice daily", "Every 8 hours"
    duration TEXT, -- e.g., "7 days", "Until finished"
    instructions TEXT,
    quantity INTEGER,
    is_dispensed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- DISPENSING RECORDS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS dispensing_records (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    prescription_id UUID NOT NULL REFERENCES prescriptions(id),
    pharmacist_id UUID NOT NULL REFERENCES profiles(id),
    patient_id UUID NOT NULL REFERENCES patients(id),
    items_dispensed JSONB, -- Array of prescription_item_ids
    notes TEXT,
    dispensed_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- MEDICAL CONDITIONS TABLE (for emergency QR access)
-- ============================================================================
CREATE TABLE IF NOT EXISTS medical_conditions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    condition_type TEXT NOT NULL CHECK (condition_type IN ('allergy', 'chronic', 'medication', 'other')),
    description TEXT NOT NULL,
    severity TEXT CHECK (severity IN ('mild', 'moderate', 'severe', 'critical')),
    is_public BOOLEAN DEFAULT TRUE, -- visible to first responders
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- EMERGENCY ACCESS LOGS (audit trail)
-- ============================================================================
CREATE TABLE IF NOT EXISTS emergency_access_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    patient_id UUID NOT NULL REFERENCES patients(id),
    accessed_by UUID REFERENCES profiles(id), -- NULL if accessed via web without login
    access_type TEXT NOT NULL CHECK (access_type IN ('app', 'web')),
    ip_address TEXT,
    user_agent TEXT,
    accessed_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================================
-- ROW LEVEL SECURITY POLICIES
-- ============================================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE patients ENABLE ROW LEVEL SECURITY;
ALTER TABLE doctors ENABLE ROW LEVEL SECURITY;
ALTER TABLE pharmacists ENABLE ROW LEVEL SECURITY;
ALTER TABLE first_responders ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescription_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispensing_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_conditions ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_access_logs ENABLE ROW LEVEL SECURITY;

-- PROFILES POLICIES
CREATE POLICY "Users can view their own profile"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

CREATE POLICY "Doctors can view patient profiles"
    ON profiles FOR SELECT
    USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'doctor'
        AND role = 'patient'
    );

-- USER DEVICES POLICIES
CREATE POLICY "Users can manage their own devices"
    ON user_devices FOR ALL
    USING (auth.uid() = user_id);

-- PATIENTS POLICIES
CREATE POLICY "Patients can view and update their own data"
    ON patients FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "Doctors can view patient data"
    ON patients FOR SELECT
    USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'doctor');

CREATE POLICY "Pharmacists can view patient data"
    ON patients FOR SELECT
    USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'pharmacist');

-- PRESCRIPTIONS POLICIES
CREATE POLICY "Patients can view their prescriptions"
    ON prescriptions FOR SELECT
    USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "Doctors can create prescriptions"
    ON prescriptions FOR INSERT
    WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'doctor');

CREATE POLICY "Patients can create their own prescriptions"
    ON prescriptions FOR INSERT
    WITH CHECK (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'patient'
        AND patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
        AND patient_entered = TRUE
    );

CREATE POLICY "Doctors can view prescriptions they created"
    ON prescriptions FOR SELECT
    USING (doctor_id = auth.uid());

CREATE POLICY "Pharmacists can view prescriptions"
    ON prescriptions FOR SELECT
    USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'pharmacist');

-- PRESCRIPTION ITEMS POLICIES
CREATE POLICY "Users can view prescription items for accessible prescriptions"
    ON prescription_items FOR SELECT
    USING (
        prescription_id IN (
            SELECT id FROM prescriptions WHERE 
                patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
                OR doctor_id = auth.uid()
                OR (SELECT role FROM profiles WHERE id = auth.uid()) = 'pharmacist'
        )
    );

CREATE POLICY "Doctors can create prescription items"
    ON prescription_items FOR INSERT
    WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'doctor');

CREATE POLICY "Patients can create prescription items on their own prescriptions"
    ON prescription_items FOR INSERT
    WITH CHECK (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'patient'
        AND prescription_id IN (
            SELECT id FROM prescriptions 
            WHERE patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
              AND patient_entered = TRUE
        )
    );

-- DISPENSING RECORDS POLICIES
CREATE POLICY "Pharmacists can create dispensing records"
    ON dispensing_records FOR INSERT
    WITH CHECK ((SELECT role FROM profiles WHERE id = auth.uid()) = 'pharmacist');

CREATE POLICY "Users can view their dispensing records"
    ON dispensing_records FOR SELECT
    USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
        OR pharmacist_id = auth.uid()
    );

-- MEDICAL CONDITIONS POLICIES
CREATE POLICY "Patients can manage their medical conditions"
    ON medical_conditions FOR ALL
    USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

CREATE POLICY "Doctors can view patient medical conditions"
    ON medical_conditions FOR SELECT
    USING ((SELECT role FROM profiles WHERE id = auth.uid()) = 'doctor');

CREATE POLICY "First responders can view public medical conditions"
    ON medical_conditions FOR SELECT
    USING (
        is_public = TRUE 
        AND (SELECT role FROM profiles WHERE id = auth.uid()) = 'first_responder'
    );

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_patients_qr_code ON patients(qr_code_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_patient ON prescriptions(patient_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_doctor ON prescriptions(doctor_id);
CREATE INDEX IF NOT EXISTS idx_prescriptions_status ON prescriptions(status);
CREATE INDEX IF NOT EXISTS idx_dispensing_records_patient ON dispensing_records(patient_id);
CREATE INDEX IF NOT EXISTS idx_medical_conditions_patient ON medical_conditions(patient_id);
CREATE INDEX IF NOT EXISTS idx_user_devices_user ON user_devices(user_id);

-- ============================================================================
-- FUNCTIONS FOR EMERGENCY ACCESS
-- ============================================================================
CREATE OR REPLACE FUNCTION get_emergency_data(p_qr_code_id TEXT)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    SELECT jsonb_build_object(
        'patient', jsonb_build_object(
            'full_name', pr.full_name,
            'blood_type', p.blood_type,
            'emergency_contact', p.emergency_contact
        ),
        'conditions', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'type', mc.condition_type,
                    'description', mc.description,
                    'severity', mc.severity
                )
            ), '[]'::jsonb)
            FROM medical_conditions mc
            WHERE mc.patient_id = p.id AND mc.is_public = TRUE
        ),
        'medications', (
            SELECT COALESCE(jsonb_agg(
                jsonb_build_object(
                    'medicine', pi.medicine_name,
                    'dosage', pi.dosage,
                    'frequency', pi.frequency
                )
            ), '[]'::jsonb)
            FROM prescription_items pi
            JOIN prescriptions rx ON pi.prescription_id = rx.id
            WHERE rx.patient_id = p.id 
                AND rx.is_public = TRUE 
                AND rx.status = 'active'
        )
    ) INTO result
    FROM patients p
    JOIN profiles pr ON p.user_id = pr.id
    WHERE p.qr_code_id = p_qr_code_id;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

