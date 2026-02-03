-- ============================================================================
-- ADDITIONAL FIX FOR PATIENT RECORD CREATION
-- Run this if patients cannot create their own patient records
-- ============================================================================

-- Fix: The patients policy needs WITH CHECK for INSERT to work properly
DROP POLICY IF EXISTS "patients_own_data" ON patients;

-- Recreate with both USING (for SELECT/UPDATE/DELETE) and WITH CHECK (for INSERT/UPDATE)
CREATE POLICY "patients_own_all"
    ON patients FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Also add a specific INSERT policy as a fallback
CREATE POLICY "patients_insert_own"
    ON patients FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Ensure medical conditions can be inserted by patients
DROP POLICY IF EXISTS "medical_conditions_patient_manage" ON medical_conditions;

CREATE POLICY "medical_conditions_patient_all"
    ON medical_conditions FOR ALL
    USING (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()))
    WITH CHECK (patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid()));

-- ============================================================================
-- OPTIONAL: Auto-create patient record when profile with role='patient' is created
-- ============================================================================

-- Create a function to auto-create patient record
CREATE OR REPLACE FUNCTION public.handle_new_patient()
RETURNS TRIGGER AS $$
BEGIN
    -- Only create patient record if role is 'patient' and no patient record exists
    IF NEW.role = 'patient' THEN
        INSERT INTO public.patients (user_id)
        VALUES (NEW.id)
        ON CONFLICT (user_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_profile_patient_created ON public.profiles;

-- Create trigger to auto-create patient record when profile is created/updated with role='patient'
CREATE TRIGGER on_profile_patient_created
    AFTER INSERT OR UPDATE OF role ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_patient();

-- ============================================================================
-- FIX EXISTING USERS: Create patient records for existing patient profiles
-- ============================================================================
INSERT INTO public.patients (user_id)
SELECT id FROM public.profiles WHERE role = 'patient'
ON CONFLICT (user_id) DO NOTHING;

