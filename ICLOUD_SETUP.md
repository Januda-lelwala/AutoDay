# iCloud Sync Setup for AutoDay

## Overview
AutoDay now supports iCloud sync to keep your tasks synchronized across all your Apple devices (iPhone, iPad, Mac) using the same Apple ID.

## Features Added

### 1. **iCloudSyncManager** (`iCloudSyncManager.swift`)
- Manages all iCloud synchronization using `NSUbiquitousKeyValueStore`
- Automatically detects iCloud availability
- Handles real-time sync from other devices
- Provides merge logic for tasks from multiple devices

### 2. **Enhanced TaskManager**
- Integrated iCloud sync with local storage
- Automatic sync when tasks are added, modified, or deleted
- Smart merging of local and cloud tasks on startup
- Toggle to enable/disable iCloud sync

### 3. **Settings UI**
- iCloud sync toggle in Settings
- Visual status indicator (Available/Not Available)
- Last sync timestamp
- Clear instructions for users

## How It Works

1. **Local Storage (UserDefaults)**: Tasks are always saved locally first
2. **iCloud Sync**: When enabled, tasks are also synced to iCloud Key-Value Store
3. **Real-time Updates**: Changes from other devices are automatically pulled and merged
4. **Smart Merging**: If the same task exists on multiple devices, they're merged using task IDs

## Xcode Configuration Steps

### Step 1: Enable iCloud Capability
1. Open your project in Xcode
2. Select the **AutoDay** target
3. Go to the **Signing & Capabilities** tab
4. Click the **+ Capability** button
5. Add **iCloud**
6. Check the following boxes:
   - ✅ **Key-value storage**
   - ✅ **CloudKit** (optional, for future expansion)

### Step 2: Configure Bundle Identifier
1. Make sure you have a unique **Bundle Identifier** (e.g., `com.yourname.AutoDay`)
2. The entitlements file uses this identifier: `iCloud.$(CFBundleIdentifier)`

### Step 3: Add Entitlements File
The `AutoDay.entitlements` file has been created. Xcode should automatically link it when you add the iCloud capability. If not:
1. Select your target
2. Go to **Build Settings**
3. Search for "Code Signing Entitlements"
4. Set it to: `AutoDay/AutoDay.entitlements`

### Step 4: Configure Your Apple Developer Account
1. In Xcode, go to **Preferences** > **Accounts**
2. Add your Apple ID if not already added
3. Select your team in the **Signing & Capabilities** tab

### Step 5: Testing iCloud Sync

#### On Simulator:
1. Go to **Settings** app on simulator
2. Sign in with an Apple ID
3. Enable iCloud Drive
4. Run your app

#### On Physical Device:
1. Make sure you're signed in to iCloud on your device
2. Build and run the app
3. Create some tasks
4. Install on another device with the same Apple ID
5. Tasks should sync automatically!

## Usage

### Enable/Disable iCloud Sync
1. Open AutoDay
2. Tap the gear icon (Settings)
3. Scroll to **iCloud Sync** section
4. Toggle **iCloud Sync** on/off

### Check Sync Status
- **Green checkmark with cloud**: iCloud is available and working
- **Red X with cloud**: iCloud is not available (check if signed in to iCloud)
- **Last Sync**: Shows when tasks were last synced

## Limitations

### iCloud Key-Value Store Limits:
- Maximum 1 MB total storage
- Maximum 1024 keys
- Good for storing task lists (can handle thousands of tasks)

If you need more storage in the future, consider migrating to:
- **CloudKit** for larger data
- **iCloud Documents** for file-based storage

## Troubleshooting

### "iCloud Not Available" Error
**Solution**: 
- Make sure you're signed in to iCloud on your device
- Check Settings > [Your Name] > iCloud
- Enable iCloud Drive

### Tasks Not Syncing
**Solution**:
1. Check iCloud sync is enabled in Settings
2. Make sure you're using the same Apple ID on all devices
3. Check internet connection
4. Force quit and restart the app

### Sync Conflicts
The app automatically merges tasks using their unique IDs. Local tasks take precedence in conflicts.

## Data Privacy
- All task data is stored in your personal iCloud account
- Data is encrypted in transit and at rest
- Only accessible by devices signed in with your Apple ID
- No third-party servers involved

## Future Enhancements
- Push notifications when tasks sync from other devices
- Conflict resolution UI for manual merging
- Export/backup tasks to iCloud Documents
- Shared task lists with family members (using CloudKit sharing)

## Code Structure

```
AutoDay/Content/
├── iCloudSyncManager.swift    # Handles iCloud sync operations
├── TaskManager.swift           # Task management with iCloud integration
└── SettingsView.swift          # UI for iCloud settings

AutoDay/
└── AutoDay.entitlements        # iCloud capabilities configuration
```

## Important Notes

1. **Development vs Production**: 
   - Development builds use development iCloud container
   - Production builds use production iCloud container
   - They don't sync with each other

2. **Team ID Required**:
   - You need a valid Apple Developer account
   - Free accounts work but have limitations

3. **First Launch**:
   - The app will merge local and cloud tasks on first launch with iCloud enabled
   - Subsequent launches will sync automatically

## Testing Checklist

- [ ] Enable iCloud capability in Xcode
- [ ] Sign in to iCloud on test devices
- [ ] Create tasks on Device A
- [ ] Verify tasks appear on Device B
- [ ] Complete a task on Device B
- [ ] Verify completion syncs to Device A
- [ ] Delete a task on Device A
- [ ] Verify deletion syncs to Device B
- [ ] Test with airplane mode (should use local storage)
- [ ] Re-enable network and verify sync resumes

---

**Need Help?** Check the Xcode console for sync logs and error messages.
