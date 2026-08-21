-- ============================================================
-- RepLiT Database Schema
-- Run this in the Supabase SQL Editor
-- ============================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. USERS TABLE
-- Stores profile data for all users (citizen, responder, admin)
-- Linked to auth.users via id (same UUID)
-- ============================================================
CREATE TABLE public.users (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL UNIQUE,
  role TEXT NOT NULL DEFAULT 'citizen' CHECK (role IN ('citizen', 'responder', 'admin')),
  full_name TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for role-based queries (admin listing responders, etc.)
CREATE INDEX idx_users_role ON public.users(role);

-- ============================================================
-- 2. INCIDENTS TABLE
-- Core table for fire incident reports
-- Status lifecycle: pending → dispatched → ongoing → resolved
-- ============================================================
CREATE TABLE public.incidents (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  citizen_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  photo_url TEXT,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  description TEXT NOT NULL CHECK (char_length(description) >= 10 AND char_length(description) <= 1000),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'dispatched', 'ongoing', 'resolved')),
  responder_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for filtering by status (dashboard queries)
CREATE INDEX idx_incidents_status ON public.incidents(status);
-- Index for citizen's own incidents
CREATE INDEX idx_incidents_citizen ON public.incidents(citizen_id);
-- Index for responder's assigned incidents
CREATE INDEX idx_incidents_responder ON public.incidents(responder_id);
-- Index for chronological listing
CREATE INDEX idx_incidents_created ON public.incidents(created_at DESC);

-- ============================================================
-- 3. RESPONDER LOCATIONS TABLE
-- Tracks real-time GPS positions for responders
-- ============================================================
CREATE TABLE public.responder_locations (
  responder_id UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  lat DOUBLE PRECISION NOT NULL,
  lng DOUBLE PRECISION NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 4. STORAGE BUCKET FOR INCIDENT PHOTOS
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'incident-photos',
  'incident-photos',
  true,
  5242880,  -- 5MB
  ARRAY['image/jpeg', 'image/png', 'image/jpg']
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================
-- 5. ROW LEVEL SECURITY POLICIES
-- Principle: least privilege. Each role sees only what it needs.
-- ============================================================

-- Enable RLS on all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.responder_locations ENABLE ROW LEVEL SECURITY;

-- ---------- USERS TABLE POLICIES ----------

-- All authenticated users can read their own profile
CREATE POLICY "Users can read own profile"
  ON public.users FOR SELECT
  USING (auth.uid() = id);

-- Admins can read all user profiles
CREATE POLICY "Admins can read all profiles"
  ON public.users FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Users can update their own profile (except role)
CREATE POLICY "Users can update own profile"
  ON public.users FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Admins can insert new user profiles (for creating responder accounts)
CREATE POLICY "Admins can insert users"
  ON public.users FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Allow new users to insert their own profile during registration
CREATE POLICY "Users can insert own profile on signup"
  ON public.users FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Admins can delete user profiles
CREATE POLICY "Admins can delete users"
  ON public.users FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can update any user profile (e.g., change roles)
CREATE POLICY "Admins can update any user"
  ON public.users FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.users WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ---------- INCIDENTS TABLE POLICIES ----------

-- Citizens can read their own incidents
CREATE POLICY "Citizens can read own incidents"
  ON public.incidents FOR SELECT
  USING (auth.uid() = citizen_id);

-- Responders and admins can read all incidents
CREATE POLICY "Responders and admins can read all incidents"
  ON public.incidents FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('responder', 'admin')
    )
  );

-- Citizens can create incidents (only for themselves)
CREATE POLICY "Citizens can create incidents"
  ON public.incidents FOR INSERT
  WITH CHECK (
    auth.uid() = citizen_id
    AND EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'citizen'
    )
  );

-- Responders can update incidents they're assigned to (status changes)
CREATE POLICY "Responders can update assigned incidents"
  ON public.incidents FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'responder'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'responder'
    )
  );

-- Admins can update any incident
CREATE POLICY "Admins can update any incident"
  ON public.incidents FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- ---------- RESPONDER LOCATIONS POLICIES ----------

-- Responders can upsert their own location
CREATE POLICY "Responders can upsert own location"
  ON public.responder_locations FOR INSERT
  WITH CHECK (
    auth.uid() = responder_id
    AND EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role = 'responder'
    )
  );

CREATE POLICY "Responders can update own location"
  ON public.responder_locations FOR UPDATE
  USING (auth.uid() = responder_id)
  WITH CHECK (auth.uid() = responder_id);

-- Admins and responders can read all responder locations
CREATE POLICY "Staff can read responder locations"
  ON public.responder_locations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.users
      WHERE id = auth.uid() AND role IN ('responder', 'admin')
    )
  );

-- ---------- STORAGE POLICIES ----------

-- Allow authenticated users to upload to incident-photos
CREATE POLICY "Authenticated users can upload photos"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'incident-photos'
    AND auth.role() = 'authenticated'
  );

-- Allow public read access to incident photos
CREATE POLICY "Public can view incident photos"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'incident-photos');

-- ============================================================
-- 6. REALTIME PUBLICATION
-- Enable realtime for tables that need live updates
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.incidents;
ALTER PUBLICATION supabase_realtime ADD TABLE public.responder_locations;

-- ============================================================
-- 7. HELPER FUNCTION: Get user role (used in app logic)
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_user_role(user_id UUID)
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT role FROM public.users WHERE id = user_id;
$$;

-- ============================================================
-- 8. TRIGGER: Auto-create user profile on signup
-- When a new user signs up via Supabase Auth, automatically
-- create their profile row in public.users
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.users (id, email, role, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'role', 'citizen'),
    COALESCE(NEW.raw_user_meta_data->>'full_name', 'User')
  );
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
