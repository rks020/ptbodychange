-- Add is_public column to class_sessions table
ALTER TABLE public.class_sessions 
ADD COLUMN IF NOT EXISTS is_public BOOLEAN DEFAULT false;

-- Update existing records to be private by default
UPDATE public.class_sessions 
SET is_public = false 
WHERE is_public IS NULL;
