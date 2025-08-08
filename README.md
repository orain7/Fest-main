# ShowGo - Event Management Platform

## Admin Setup Instructions

### How to Make a User an Admin

After a user has successfully signed up, you can make them an admin by following these steps:

1. **Go to your Supabase Dashboard**
   - Visit [supabase.com](https://supabase.com)
   - Sign in to your account
   - Select your ShowGo project

2. **Navigate to Table Editor**
   - Click on "Table Editor" in the left sidebar
   - Select the `user_profiles` table

3. **Find the User**
   - Look for the user you want to make an admin
   - You can search by email or full name

4. **Edit the Role**
   - Click on the `role` field for that user
   - Change the value from `'user'` to `'admin'`
   - Click the checkmark to save

5. **Verify Admin Access**
   - The user will now have admin privileges
   - They can create events and access admin features
   - Admin status will show in their user menu

### Default Admin Emails
The system also recognizes these emails as admins automatically:
- `admin@showgo.com`
- `support@showgo.com`

### Troubleshooting Signup Issues

If users can't sign up:

1. **Check Supabase Auth Settings**
   - Go to Authentication → Settings in Supabase
   - Ensure "Enable email confirmations" is **DISABLED** for immediate access
   - Check that "Enable sign ups" is **ENABLED**

2. **Verify Database Migration**
   - Ensure the migration has been applied successfully
   - Check that the `user_profiles` table exists
   - Verify the trigger functions are created

3. **Check Environment Variables**
   - Ensure `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` are correct
   - Restart the development server after changing env variables

### Database Schema
```sql
-- User Profiles Table
user_profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  full_name TEXT,
  email TEXT,
  role TEXT DEFAULT 'user' CHECK (role IN ('user', 'admin')),
  avatar_url TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Features by Role

**Regular Users:**
- Browse and view events
- Register for events
- View their registered events in dashboard
- Edit their profile

**Admin Users:**
- All regular user features
- Create new events
- Edit existing events
- View all registrations
- Access admin dashboard (coming soon)

## Development Setup

1. Clone the repository
2. Install dependencies: `npm install`
3. Set up environment variables in `.env`
4. Run the development server: `npm run dev`
5. Apply database migrations in Supabase
6. Create your first admin user following the instructions above