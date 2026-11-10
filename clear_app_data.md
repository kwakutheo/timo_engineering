# Resetting Timo's Engineering App on Windows (Fresh Install Guide)

When you uninstall the application from Windows, your local SQLite database, client records, invoices, and password credentials remain saved on your computer by default. 

Follow this guide to completely erase all local app traces so you can reinstall and launch the application as a **brand-new, first-time installation**.

---

## Method 1: Fast One-Click Reset (Recommended)

This method automatically clears all local database files, backups, exports, and sync caches.

1. **Close or uninstall** Timo's Engineering.
2. Press <kbd>Win</kbd> + <kbd>X</kbd> and choose **Windows Terminal** or **PowerShell**.
3. Copy and run the following command:

```powershell
Remove-Item -Recurse -Force "$env:LOCALAPPDATA\Timo Invoice", "$env:LOCALAPPDATA\timo_enginerring", "$env:APPDATA\timo_enginerring", "$env:APPDATA\com.example\timo_enginerring" -ErrorAction SilentlyContinue
```

4. Now proceed to [Clear Stored Passwords](#step-2-clear-stored-passwords--master-pin) below.

---

## Method 2: Manual Removal via File Explorer

If you prefer doing it manually without using the terminal:

1. **Close or uninstall** the application.
2. Press <kbd>Win</kbd> + <kbd>R</kbd> to open the **Run** box.
3. Type `%LOCALAPPDATA%` and hit **Enter**.
4. Find the folder named **`Timo Invoice`** and delete it permanently (<kbd>Shift</kbd> + <kbd>Delete</kbd>).
   - If you also see a folder named `timo_enginerring`, delete it as well.
5. Press <kbd>Win</kbd> + <kbd>R</kbd> again, type `%APPDATA%`, and hit **Enter**.
6. If a folder named `timo_enginerring` or `com.example` exists there, delete it.

---

## Step 2: Clear Stored Passwords & Master PIN

The app uses Windows Credential Manager to securely store your master password, security questions, and user profile.

1. Press <kbd>Win</kbd> + <kbd>R</kbd>, paste the following command, and press **Enter**:
   ```cmd
   control /name Microsoft.CredentialManager
   ```
2. Click on **Windows Credentials**.
3. Scroll down to the **Generic Credentials** section.
4. Look for any entries associated with:
   - `flutter_secure_storage`
   - `pin_hash`
   - `pin_salt`
   - `timo`
5. Click the dropdown arrow on each and click **Remove**.

---

## Step 3: Optional – Clear Cloud Database (Supabase)

If you have cloud sync enabled, the app will automatically download any existing cloud records once reinstalled and connected to the internet. 

If you want a **100% clean slate with zero cloud records**:
1. Log into your [Supabase Dashboard](https://supabase.com/dashboard).
2. Go to the **SQL Editor** in your project.
3. Run the following query to clear all records:
   ```sql
   TRUNCATE TABLE invoice_items, invoices, clients CASCADE;
   ```

---

## Verification

When you reinstall and launch the application:
- You will be greeted with the **"Create Master Password"** setup screen.
- You will be prompted to select and answer your security recovery questions.
- The dashboard and invoice list will start completely empty (0 invoices, 0 clients).
