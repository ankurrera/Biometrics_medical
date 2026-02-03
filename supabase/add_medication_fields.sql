-- Migration: Add enhanced medication fields to prescription_items table
-- This adds medicine_type, route_of_administration, and food_timing columns

-- Add medicine_type column
ALTER TABLE prescription_items
ADD COLUMN IF NOT EXISTS medicine_type TEXT
CHECK (medicine_type IN ('tablet', 'syrup', 'injection', 'ointment', 'capsule', 'drops', NULL));

-- Add route_of_administration column
ALTER TABLE prescription_items
ADD COLUMN IF NOT EXISTS route TEXT
CHECK (route IN ('oral', 'intravenous', 'intramuscular', 'topical', 'sublingual', NULL));

-- Add food_timing column
ALTER TABLE prescription_items
ADD COLUMN IF NOT EXISTS food_timing TEXT
CHECK (food_timing IN ('beforeFood', 'afterFood', 'withFood', 'empty', NULL));

-- Add comments for documentation
COMMENT ON COLUMN prescription_items.medicine_type IS 'Type of medicine: tablet, syrup, injection, ointment, capsule, drops';
COMMENT ON COLUMN prescription_items.route IS 'Route of administration: oral, intravenous, intramuscular, topical, sublingual';
COMMENT ON COLUMN prescription_items.food_timing IS 'Food timing: beforeFood, afterFood, withFood, empty';
