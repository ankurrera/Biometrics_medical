-- ============================================================================
-- FIX FOR INFINITE RECURSION IN RLS POLICIES
-- Run this AFTER the main schema.sql if you're getting recursion errors
-- Or run it to fix existing database
-- ============================================================================

-- First, create a function that gets user role without triggering RLS
-- This function uses SECURITY DEFINER to bypass RLS
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role FROM public.profiles WHERE id = user_id;
    RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_user_role(UUID) TO authenticated;

-- ============================================================================
-- DROP OLD POLICIES THAT CAUSE RECURSION
-- ============================================================================

-- Drop profiles policies
DROP POLICY IF EXISTS "Users can view their own profile" ON profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON profiles;
DROP POLICY IF EXISTS "Doctors can view patient profiles" ON profiles;

-- Drop patients policies
DROP POLICY IF EXISTS "Patients can view and update their own data" ON patients;
DROP POLICY IF EXISTS "Doctors can view patient data" ON patients;
DROP POLICY IF EXISTS "Pharmacists can view patient data" ON patients;

-- Drop prescriptions policies
DROP POLICY IF EXISTS "Patients can view their prescriptions" ON prescriptions;
DROP POLICY IF EXISTS "Doctors can create prescriptions" ON prescriptions;
DROP POLICY IF EXISTS "Doctors can view prescriptions they created" ON prescriptions;
DROP POLICY IF EXISTS "Pharmacists can view prescriptions" ON prescriptions;

-- Drop prescription_items policies
DROP POLICY IF EXISTS "Users can view prescription items for accessible prescriptions" ON prescription_items;
DROP POLICY IF EXISTS "Doctors can create prescription items" ON prescription_items;

-- Drop dispensing_records policies
DROP POLICY IF EXISTS "Pharmacists can create dispensing records" ON dispensing_records;
DROP POLICY IF EXISTS "Users can view their dispensing records" ON dispensing_records;

-- Drop medical_conditions policies
DROP POLICY IF EXISTS "Patients can manage their medical conditions" ON medical_conditions;
DROP POLICY IF EXISTS "Doctors can view patient medical conditions" ON medical_conditions;
DROP POLICY IF EXISTS "First responders can view public medical conditions" ON medical_conditions;

-- ============================================================================
-- RECREATE POLICIES WITHOUT RECURSION
-- ============================================================================

-- PROFILES POLICIES (fixed)
CREATE POLICY "profiles_select_own"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY "profiles_update_own"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- Allow doctors to view patient profiles using the helper function
CREATE POLICY "profiles_doctors_view_patients"
    ON profiles FOR SELECT
    USING (
        public.get_user_role(auth.uid()) = 'doctor'
        AND role = 'patient'
    );

-- Allow pharmacists to view patient profiles  
CREATE POLICY "profiles_pharmacists_view_patients"
    ON profiles FOR SELECT
    USING (
        public.get_user_role(auth.uid()) = 'pharmacist'
        AND role = 'patient'
    );

-- PATIENTS POLICIES (fixed)
CREATE POLICY "patients_own_data"
    ON patients FOR ALL
    USING (auth.uid() = user_id);

CREATE POLICY "patients_doctors_view"
    ON patients FOR SELECT
    USING (public.get_user_role(auth.uid()) = 'doctor');

CREATE POLICY "patients_pharmacists_view"
    ON patients FOR SELECT
    USING (public.get_user_role(auth.uid()) = 'pharmacist');

-- PRESCRIPTIONS POLICIES (fixed)
CREATE POLICY "prescriptions_patient_view"
    ON prescriptions FOR SELECT
    USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
    );

CREATE POLICY "prescriptions_doctor_create"
    ON prescriptions FOR INSERT
    WITH CHECK (public.get_user_role(auth.uid()) = 'doctor');

CREATE POLICY "prescriptions_doctor_view_own"
    ON prescriptions FOR SELECT
    USING (doctor_id = auth.uid());

CREATE POLICY "prescriptions_pharmacist_view"
    ON prescriptions FOR SELECT
    USING (public.get_user_role(auth.uid()) = 'pharmacist');

-- PRESCRIPTION ITEMS POLICIES (fixed)
CREATE POLICY "prescription_items_view"
    ON prescription_items FOR SELECT
    USING (
        prescription_id IN (
            SELECT id FROM prescriptions WHERE 
                patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
                OR doctor_id = auth.uid()
                OR public.get_user_role(auth.uid()) = 'pharmacist'
        )
    );

CREATE POLICY "prescription_items_doctor_create"
    ON prescription_items FOR INSERT
    WITH CHECK (public.get_user_role(auth.uid()) = 'doctor');

-- DISPENSING RECORDS POLICIES (fixed)
CREATE POLICY "dispensing_pharmacist_create"
    ON dispensing_records FOR INSERT
    WITH CHECK (public.get_user_role(auth.uid()) = 'pharmacist');

CREATE POLICY "dispensing_view"
    ON dispensing_records FOR SELECT
    USING (
        patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
        OR pharmacist_id = auth.uid()
    );

-- MEDICAL CONDITIONS POLICIES (fixed)
CREATE POLICY "medical_conditions_patient_manage"
    ON medical_conditions FOR ALL
    USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

CREATE POLICY "medical_conditions_doctors_view"
    ON medical_conditions FOR SELECT
    USING (public.get_user_role(auth.uid()) = 'doctor');

CREATE POLICY "medical_conditions_first_responders_view_public"
    ON medical_conditions FOR SELECT
    USING (
        is_public = TRUE 
        AND public.get_user_role(auth.uid()) = 'first_responder'
    );

-- ============================================================================
-- VERIFY: List all policies
-- ============================================================================
-- SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public';

