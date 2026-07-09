-- Adds menu bar visibility flag for macOS sync.
-- Apply in Supabase Dashboard → SQL Editor, or via: supabase db push

ALTER TABLE public.items
ADD COLUMN IF NOT EXISTS show_in_menu_bar boolean NOT NULL DEFAULT true;
