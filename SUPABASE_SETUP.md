# CareSync - Supabase Setup Guide

This guide walks you through setting up Supabase for the CareSync medical logging app.

## Step 1: Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in (or create an account)
2. Click **"New Project"**
3. Fill in:
   - **Name**: `caresync` (or your preferred name)
   - **Database Password**: Generate a strong password (save this!)
   - **Region**: Choose the closest to your users
4. Click **"Create new project"** and wait for it to initialize (~2 minutes)

## Step 2: Get Your API Credentials

1. In your Supabase dashboard, go to **Settings** (gear icon) → **API**
2. Copy these values:
   - **Project URL** (looks like `https://xxxxx.supabase.co`)
   - **anon public** key (under "Project API keys")

3. Open `lib/core/config/env_config.dart` in your Flutter project and update:

```dart
abstract class EnvConfig {
  static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
}
```

## Step 3: Run the Database Schema

1. In Supabase dashboard, go to **SQL Editor** (left sidebar)
2. Click **"New query"**
3. Copy the entire contents of `supabase/schema.sql` from your project
4. Paste it into the SQL Editor
5. Click **"Run"** (or press Cmd/Ctrl + Enter)

You should see "Success. No rows returned" - this means all tables were created.

## Step 4: Verify Tables Were Created

1. Go to **Table Editor** (left sidebar)
2. You should see these tables:
   - `profiles`
   - `user_devices`
   - `patients`
   - `doctors`
   - `pharmacists`
   - `first_responders`
   - `prescriptions`
   - `prescription_items`
   - `dispensing_records`
   - `medical_conditions`
   - `emergency_access_logs`

## Step 5: Configure Authentication

### Enable Email Auth (already enabled by default)
1. Go to **Authentication** → **Providers**
2. Ensure **Email** is enabled
3. Optional: Disable "Confirm email" for testing (Authentication → Settings → toggle off "Enable email confirmations")

### Configure Auth Settings
1. Go to **Authentication** → **Settings**
2. Under "General":
   - Set **Site URL** to your app's URL (or `http://localhost:3000` for testing)
3. Under "Email Templates" (optional):
   - Customize the confirmation and reset password emails

## Step 6: Deploy the Emergency Web Page (Optional but Recommended)

For the emergency QR code feature, you need a web endpoint that displays patient data when scanned.

### Option A: Using Supabase Edge Functions (Recommended)

1. Install Supabase CLI:
```bash
npm install -g supabase
```

2. Login to Supabase:
```bash
supabase login
```

3. Link your project:
```bash
cd /path/to/caresync
supabase link --project-ref YOUR_PROJECT_ID
```

4. Create the edge function:
```bash
supabase functions new emergency
```

5. Replace the contents of `supabase/functions/emergency/index.ts` with the code provided in `supabase/functions/emergency/index.ts` in your project.

6. Deploy:
```bash
supabase functions deploy emergency
```

### Option B: Using the Flutter Web Build

The emergency page is also available in the Flutter web build. After building:
```bash
flutter build web
```

Host the `build/web` folder on any static hosting (Vercel, Netlify, Firebase Hosting).

## Step 7: Create Storage Bucket for Avatars

1. Go to **Storage** in Supabase dashboard (left sidebar)
2. Click **"Create a new bucket"**
3. Set bucket name to `avatars`
4. Enable **"Public bucket"** (so avatar images are publicly accessible)
5. Click **"Create bucket"**

### Storage Policies (Optional but Recommended)

In the SQL Editor, run this to allow users to upload their own avatars:

```sql
-- Allow users to upload their own avatar
CREATE POLICY "Users can upload their avatar"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'avatars' 
  AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to update their own avatar
CREATE POLICY "Users can update their avatar"
ON storage.objects FOR UPDATE
TO authenticated
USING (bucket_id = 'avatars' AND owner = auth.uid());

-- Allow public read access to avatars
CREATE POLICY "Public avatar access"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'avatars');
```

## Step 8: Set Up Row Level Security (RLS)

The schema already includes RLS policies, but verify they're enabled:

1. Go to **Table Editor**
2. Click on each table
3. In the table view, click the shield icon (🛡️) or go to **Policies**
4. Verify "Enable RLS" is ON for all tables

## Step 9: Test the Setup

### Test User Registration
1. Run your Flutter app: `flutter run`
2. Select a role (e.g., Patient)
3. Create an account with email/password
4. Check Supabase dashboard:
   - **Authentication** → **Users** - you should see the new user
   - **Table Editor** → **profiles** - you should see a profile row

### Test Profile Creation
The trigger function should automatically create a profile when a user signs up. If not working:

1. Go to **SQL Editor**
2. Run this to check if the trigger exists:
```sql
SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
```

## Troubleshooting

### "Infinite recursion detected in policy" error (Error code 42P17)

This error occurs because some RLS policies on the `profiles` table reference the same table, creating a loop.

**Fix:** Run the `supabase/schema_fix.sql` file in SQL Editor:

1. Go to **SQL Editor** in Supabase dashboard
2. Click **"New query"**
3. Copy the entire contents of `supabase/schema_fix.sql`
4. Paste and click **"Run"**

This creates a helper function `get_user_role()` that bypasses RLS and updates all policies to use it.

### Medical conditions or patient data not showing (empty screens)

This happens when a patient record wasn't created for the user. 

**Fix:** Run the `supabase/schema_fix_v2.sql` file in SQL Editor:

1. Go to **SQL Editor** in Supabase dashboard
2. Click **"New query"** 
3. Copy the entire contents of `supabase/schema_fix_v2.sql`
4. Paste and click **"Run"**

This will:
- Fix the RLS policies to allow patients to create their own records
- Add a trigger to auto-create patient records when a user signs up as a patient
- Create patient records for any existing patient users who don't have one

### "Permission denied" errors
- Check that RLS policies are correctly set up
- Verify the user's role in the `profiles` table matches expected permissions
- **Make sure you've run both `schema_fix.sql` and `schema_fix_v2.sql`** after the main `schema.sql`

### Profile not created on signup
Run this in SQL Editor to manually create the trigger:
```sql
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
```

### "Invalid API key" error
- Double-check you're using the `anon` key (not the `service_role` key)
- Verify there are no extra spaces in your env_config.dart

### Tables not visible
- Refresh the page
- Check the **public** schema is selected in Table Editor

## Environment Variables (Production)

For production, don't hardcode credentials. Use environment variables:

```bash
# Build with environment variables
flutter build apk \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

Then in `env_config.dart`:
```dart
abstract class EnvConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'YOUR_DEV_URL',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY', 
    defaultValue: 'YOUR_DEV_KEY',
  );
}
```

## Quick Reference: Supabase Dashboard URLs

- **Dashboard**: https://supabase.com/dashboard/project/YOUR_PROJECT_ID
- **Table Editor**: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/editor
- **SQL Editor**: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/sql
- **Authentication**: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/auth/users
- **API Docs**: https://supabase.com/dashboard/project/YOUR_PROJECT_ID/api

## Next Steps

1. ✅ Create Supabase project
2. ✅ Add credentials to Flutter app
3. ✅ Run database schema
4. ✅ Configure authentication
5. ⬜ Test user registration
6. ⬜ Deploy emergency web page (optional)
7. ⬜ Set up email templates (optional)

