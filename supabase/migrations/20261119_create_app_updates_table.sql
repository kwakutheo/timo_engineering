-- Table to manage application auto-updates for Android & Windows
CREATE TABLE IF NOT EXISTS app_updates (
  id TEXT PRIMARY KEY,
  version TEXT NOT NULL,              -- e.g. '2.1.0'
  build_number INTEGER NOT NULL,      -- e.g. 2
  release_notes TEXT DEFAULT '',
  windows_url TEXT DEFAULT '',        -- direct download link for Windows setup .exe
  android_url TEXT DEFAULT '',        -- direct download link for Android .apk
  is_mandatory BOOLEAN DEFAULT false,
  published_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable Public Read Access so clients can check for updates
ALTER TABLE app_updates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public read access to app_updates"
ON app_updates FOR SELECT
USING (true);
