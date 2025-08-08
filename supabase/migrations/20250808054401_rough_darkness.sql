/*
  # Fix Authentication and User Profile Policies

  1. Security
    - Update RLS policies for better user profile access
    - Fix trigger function for profile creation
    - Ensure proper permissions for authenticated users

  2. Changes
    - Update user profile policies
    - Fix profile creation trigger
    - Add better error handling
*/

-- Drop existing policies to recreate them
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON user_profiles;

-- Recreate user profile policies with better logic
CREATE POLICY "Users can view their own profile"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Admins can view all profiles"
  ON user_profiles
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

CREATE POLICY "Admins can update all profiles"
  ON user_profiles
  FOR UPDATE
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Update the trigger function to handle errors better
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (id, full_name, email, role)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
    NEW.email,
    'user'
  );
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log the error but don't fail the user creation
    RAISE WARNING 'Failed to create user profile for %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Ensure the trigger exists
DROP TRIGGER IF EXISTS create_user_profile_trigger ON auth.users;
CREATE TRIGGER create_user_profile_trigger
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile();

-- Update registrations policies to work with user_id
DROP POLICY IF EXISTS "Users can view their own registrations" ON registrations;
DROP POLICY IF EXISTS "Users can insert their own registrations" ON registrations;
DROP POLICY IF EXISTS "Users can update their own registrations" ON registrations;
DROP POLICY IF EXISTS "Users can delete their own registrations" ON registrations;

CREATE POLICY "Users can view their own registrations"
  ON registrations
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id OR 
    user_email = (SELECT email FROM auth.users WHERE id = auth.uid())
  );

CREATE POLICY "Users can insert their own registrations"
  ON registrations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id OR 
    user_email = (SELECT email FROM auth.users WHERE id = auth.uid())
  );

CREATE POLICY "Users can update their own registrations"
  ON registrations
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id OR 
    user_email = (SELECT email FROM auth.users WHERE id = auth.uid())
  );

CREATE POLICY "Users can delete their own registrations"
  ON registrations
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id OR 
    user_email = (SELECT email FROM auth.users WHERE id = auth.uid())
  );

-- Add admin policy for registrations
CREATE POLICY "Admins can view all registrations"
  ON registrations
  FOR SELECT
  TO authenticated
  USING (
    (SELECT email FROM auth.users WHERE id = auth.uid()) = ANY(ARRAY['admin@showgo.com', 'support@showgo.com']) OR
    (SELECT role FROM user_profiles WHERE id = auth.uid()) = 'admin'
  );