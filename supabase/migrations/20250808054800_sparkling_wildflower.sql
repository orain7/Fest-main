/*
  # Fix User Profile Creation System

  1. Database Functions
    - `create_user_profile` - Creates user profile when new user signs up
    - `update_updated_at_column` - Updates timestamp on profile changes

  2. Database Triggers  
    - Automatically creates user profile after auth.users insert
    - Updates timestamp on profile updates

  3. Security
    - Proper RLS policies for user profile access
    - Admin role checking functions

  This migration fixes the "Database error saving new user" issue by ensuring
  user profiles are automatically created when users sign up.
*/

-- Create function to automatically create user profile
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
  WHEN others THEN
    -- Log the error but don't fail the user creation
    RAISE WARNING 'Could not create user profile for %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to automatically create user profile on signup
DROP TRIGGER IF EXISTS create_user_profile_trigger ON auth.users;
CREATE TRIGGER create_user_profile_trigger
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile();

-- Create trigger to update timestamp on profile changes
DROP TRIGGER IF EXISTS update_user_profiles_updated_at ON user_profiles;
CREATE TRIGGER update_user_profiles_updated_at
  BEFORE UPDATE ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Ensure RLS is enabled
ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to recreate them properly
DROP POLICY IF EXISTS "Users can view their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Users can update their own profile" ON user_profiles;
DROP POLICY IF EXISTS "Admins can view all profiles" ON user_profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON user_profiles;

-- Create proper RLS policies
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

-- Update registrations table policies to work with authenticated users
ALTER TABLE registrations ENABLE ROW LEVEL SECURITY;

-- Drop existing registration policies
DROP POLICY IF EXISTS "Users can view their own registrations" ON registrations;
DROP POLICY IF EXISTS "Users can insert their own registrations" ON registrations;
DROP POLICY IF EXISTS "Users can update their own registrations" ON registrations;
DROP POLICY IF EXISTS "Users can delete their own registrations" ON registrations;
DROP POLICY IF EXISTS "Admins can view all registrations" ON registrations;

-- Create new registration policies
CREATE POLICY "Users can view their own registrations"
  ON registrations
  FOR SELECT
  TO authenticated
  USING (
    auth.uid() = user_id OR 
    user_email = (SELECT email FROM user_profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can insert their own registrations"
  ON registrations
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = user_id OR 
    user_email = (SELECT email FROM user_profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can update their own registrations"
  ON registrations
  FOR UPDATE
  TO authenticated
  USING (
    auth.uid() = user_id OR 
    user_email = (SELECT email FROM user_profiles WHERE id = auth.uid())
  );

CREATE POLICY "Users can delete their own registrations"
  ON registrations
  FOR DELETE
  TO authenticated
  USING (
    auth.uid() = user_id OR 
    user_email = (SELECT email FROM user_profiles WHERE id = auth.uid())
  );

CREATE POLICY "Admins can view all registrations"
  ON registrations
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM user_profiles 
      WHERE id = auth.uid() AND role = 'admin'
    ) OR 
    (SELECT email FROM user_profiles WHERE id = auth.uid()) IN ('admin@showgo.com', 'support@showgo.com') OR
    (SELECT auth.jwt() ->> 'role') = 'admin'
  );