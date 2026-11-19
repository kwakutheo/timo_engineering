# How to Publish Updates for Android & Windows

This app has an automatic update system built-in. Clients running the app on Windows or Android will automatically detect new versions, display an in-app update prompt, download the update with a progress bar, and install it.

---

## 1. Initial Setup (One-time in Supabase)

1. Open your Supabase Project Dashboard (`https://supabase.com/dashboard/project/pgysnqsimewpwgmztjom`).
2. Go to the **SQL Editor** on the left menu.
3. Paste and run the migration in `supabase/migrations/20261119_create_app_updates_table.sql`:
   ```sql
   CREATE TABLE IF NOT EXISTS app_updates (
     id TEXT PRIMARY KEY,
     version TEXT NOT NULL,
     build_number INTEGER NOT NULL,
     release_notes TEXT DEFAULT '',
     windows_url TEXT DEFAULT '',
     android_url TEXT DEFAULT '',
     is_mandatory BOOLEAN DEFAULT false,
     published_at TIMESTAMP WITH TIME ZONE DEFAULT now()
   );

   ALTER TABLE app_updates ENABLE ROW LEVEL SECURITY;

   CREATE POLICY "Allow public read access to app_updates"
   ON app_updates FOR SELECT
   USING (true);
   ```
4. Go to **Storage** on the left menu and click **New Bucket**:
   * Name: `releases`
   * Check **Public bucket** (so users can download the files).
   * Click **Save**.

---

## 2. When You Have a New Version to Release

### Step A: Bump the Version in `pubspec.yaml`
Open `pubspec.yaml` and increment the version:
```yaml
version: 2.1.0+2    # 2.1.0 is version, 2 is build_number
```

### Step B: Build the Binaries

* **For Android:**
  ```bash
  flutter build apk --release
  ```
  The APK is created at: `build/app/outputs/flutter-apk/app-release.apk`

* **For Windows:**
  ```bash
  flutter build windows --release
  ```
  The release files are created at: `build/windows/x64/runner/Release/`
  *(Tip: You can zip this folder or package it into a setup installer e.g. using Inno Setup or an executable installer).*

### Step C: Upload Binaries to Supabase Storage
1. Go to your `releases` bucket in Supabase Storage.
2. Upload `app-release.apk` (you can rename it e.g. `timo_v2.1.0.apk`).
3. Upload your Windows installer or zip (e.g. `timo_setup_v2.1.0.exe`).
4. Click the three dots next to each uploaded file and select **Copy URL**.

### Step D: Announce the Update in Supabase
In Supabase **Table Editor**, go to `app_updates` and insert a new row:

| Column | Example Value | Note |
|---|---|---|
| `id` | `v2.1.0` | Unique ID (or UUID) |
| `version` | `2.1.0` | Must match or exceed your new version |
| `build_number` | `2` | Must be higher than the current build number |
| `release_notes` | `- Added automatic updates\n- Improved report line spacing` | Shown in the update popup |
| `windows_url` | `https://pgysnqsimewpwgmztjom.supabase.co/storage/v1/object/public/releases/timo_setup_v2.1.0.exe` | Direct download link |
| `android_url` | `https://pgysnqsimewpwgmztjom.supabase.co/storage/v1/object/public/releases/timo_v2.1.0.apk` | Direct download link |
| `is_mandatory` | `false` (or `true`) | If `true`, the user cannot skip the update |

---

## 3. What Happens on Your Clients' Devices

1. The next time any client opens the app (or taps **Security & Settings → Check for updates**), the app automatically detects the new version.
2. An **"Update Available!"** dialog appears showing your release notes and new version number.
3. The client taps **"Update Now"**:
   * A progress bar tracks the download in megabytes.
   * **On Windows:** The installer automatically launches and the app closes cleanly to complete the installation.
   * **On Android:** Android's native package installer immediately pops up asking: *"Do you want to update this application?"*
