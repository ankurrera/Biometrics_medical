-- Migration: Add enhanced medication fields to prescription_items table
-- This adds medicine_type, route_of_administration, and food_timing columns

-- Add medicine_type column
ALTER TABLE prescription_items
ADD COLUMN IF NOT EXISTS medicine_type TEXT;

-- Add CHECK constraint for medicine_type
ALTER TABLE prescription_items
ADD CONSTRAINT IF NOT EXISTS medicine_type_check
CHECK (medicine_type IN ('tablet', 'syrup', 'injection', 'ointment', 'capsule', 'drops') OR medicine_type IS NULL);

-- Add route_of_administration column
ALTER TABLE prescription_items
ADD COLUMN IF NOT EXISTS route TEXT;

-- Add CHECK constraint for route
ALTER TABLE prescription_items
ADD CONSTRAINT IF NOT EXISTS route_check
CHECK (route IN ('oral', 'intravenous', 'intramuscular', 'topical', 'sublingual') OR route IS NULL);

-- Add food_timing column
ALTER TABLE prescription_items
ADD COLUMN IF NOT EXISTS food_timing TEXT;

-- Add CHECK constraint for food_timing
ALTER TABLE prescription_items
ADD CONSTRAINT IF NOT EXISTS food_timing_check
CHECK (food_timing IN ('beforeFood', 'afterFood', 'withFood', 'empty') OR food_timing IS NULL);

-- Add comments for documentation
COMMENT ON COLUMN prescription_items.medicine_type IS 'Type of medicine: tablet, syrup, injection, ointment, capsule, drops';
COMMENT ON COLUMN prescription_items.route IS 'Route of administration: oral, intravenous, intramuscular, topical, sublingual';
COMMENT ON COLUMN prescription_items.food_timing IS 'Food timing: beforeFood, afterFood, withFood, empty';
