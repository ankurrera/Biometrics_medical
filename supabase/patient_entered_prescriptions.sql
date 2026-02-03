-- Patient-entered prescriptions support

-- Allow doctor_id to be nullable and add patient_entered flag
ALTER TABLE prescriptions ALTER COLUMN doctor_id DROP NOT NULL;
ALTER TABLE prescriptions
  ADD COLUMN IF NOT EXISTS patient_entered BOOLEAN DEFAULT FALSE;

-- Backfill existing rows
UPDATE prescriptions SET patient_entered = FALSE WHERE patient_entered IS NULL;

-- Policy: patients can insert their own prescriptions (must flag patient_entered)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = current_schema()
      AND tablename = 'prescriptions'
      AND policyname = 'Patients can create their own prescriptions'
  ) THEN
    CREATE POLICY "Patients can create their own prescriptions"
      ON prescriptions FOR INSERT
      WITH CHECK (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'patient'
        AND patient_id IN (SELECT id FROM patients WHERE user_id = auth.uid())
        AND patient_entered = TRUE
      );
  END IF;
END $$;

-- Policy: patients can add items only to their own patient-entered prescriptions
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE schemaname = current_schema()
      AND tablename = 'prescription_items'
      AND policyname = 'Patients can create prescription items on their own prescriptions'
  ) THEN
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
  END IF;
END $$;


