# Admin Account Creation - See Admin Dashboard Without Login Bypass

## Status: 🚀 In Progress

### Step 1: [ ] Create Supabase Admin Account (Manual Signup)
1. Run the app if not running: `flutter run`
2. From home screen → person icon → Signup
3. Use these credentials:
   - **Email:** `admin@foodtaxi.local`
   - **Password:** `Admin123!`
   - **First Name:** Admin
   - **Surname:** User
   - **Phone:** `09123456789`
   - **Address:** 
     | Field | Value |
     |-------|--------|
     | Province | Metro Manila |
     | Municipality | Quezon City |
     | Barangay | Diliman |
     | Street | Sample St |
     | House # | 123 |
4. Submit → Account created!

### Step 2: [ ] Set Admin Role in Supabase Dashboard
1. Go to https://zsctswdvoknmdsimqrvr.supabase.co
2. Login with your Supabase account
3. **Authentication** → **Users**
4. Find `admin@foodtaxi.local` → **Edit**
5. **User Metadata:** `{"role": "admin"}`
6. **Save**

### Step 3: [ ] Test Admin Login
1. In app: Login screen
2. Email: `admin@foodtaxi.local`, Pass: `Admin123!`
3. ✅ Should navigate directly to Admin Dashboard!

### Step 4: ✅ Direct Admin Button Added!
- New orange admin icon in top-right home screen.
- Tap → Admin Dashboard instantly!
- To remove: Delete the IconButton in lib/main.dart actions.

### Notes
- Password strength validated.
- Address required for signup.
- Email confirmation? Check spam if needed.

**Next:** Complete Step 1 manually, mark as done, reply 'step1 done'.
