# Notification System - AutoDay

## ✅ Enhanced Features

### Dual Notification System
Your app now sends **TWO** notifications for each scheduled task:

1. **Reminder Notification (15 minutes before)**
   - Title: "Task Starting Soon"
   - Body: "⏰ [Task Name] starts in 15 minutes"
   - Sound: Default notification sound
   - Actions: Mark Complete, Snooze 10 min

2. **Due Time Notification (at exact due time)**
   - Title: "Task Due Now"
   - Body: "🔔 [Task Name] is due now!"
   - Sound: Critical alert sound (more prominent)
   - Actions: Mark Complete, Snooze 10 min

### Interactive Actions
Users can interact with notifications without opening the app:
- **Mark Complete**: Instantly marks the task as complete
- **Snooze 10 min**: Reschedules the notification for 10 minutes later

### Settings Dashboard
New notification status section showing:
- ✅ Authorization status (Authorized/Not Authorized)
- 📊 Count of pending scheduled notifications
- 🔔 Clear explanation of notification behavior

## How It Works

### When a Task is Created/Updated:
```
Task with due time set
    ↓
NotificationManager.scheduleNotification()
    ↓
Schedules TWO notifications:
    1. Reminder at (due time - 15 min)
    2. Due alert at (due time)
```

### Smart Scheduling:
- Only schedules notifications if times are in the future
- Automatically cancels old notifications when task is updated
- Cancels notifications when task is deleted
- Cancels notifications when task is marked complete

### When Task is Modified:
```
Task updated
    ↓
Cancel existing notifications
    ↓
Schedule new notifications with updated time
```

## Testing Notifications

### Test 1: Basic Notification
1. Create a task with due time 20 minutes from now
2. You should see 2 pending notifications in Settings
3. Wait 5 minutes → should receive "Task Starting Soon" notification
4. Wait 15 more minutes → should receive "Task Due Now" notification

### Test 2: Interactive Actions
1. When notification appears, swipe or long-press
2. Tap "Mark Complete" → task should be marked complete in app
3. Or tap "Snooze 10 min" → notification will appear again in 10 min

### Test 3: Immediate Due Time
1. Create a task with due time 10 minutes from now
2. Only 1 notification will be scheduled (due time)
3. The reminder won't be scheduled (would be in the past)

### Test 4: Past Due Time
1. Create a task with due time in the past
2. No notifications will be scheduled
3. Task is added normally

## Notification Permissions

### First Launch:
- App automatically requests notification permission
- User must approve to receive notifications

### If Denied:
- Toggle in Settings shows "Not Authorized"
- User must go to iOS Settings → AutoDay → Notifications to enable

### Re-requesting Permission:
If user denies, they can enable later:
1. iOS Settings
2. AutoDay
3. Notifications → Enable

## Technical Details

### Notification Identifiers:
- Reminder: `{taskId}-reminder`
- Due Time: `{taskId}`

This allows canceling both notifications independently.

### Cancellation:
When a task is:
- Deleted → Both notifications canceled
- Completed → Both notifications canceled
- Updated → Old notifications canceled, new ones scheduled

### Authorization Handling:
- Checks authorization before scheduling
- Auto-requests if not authorized
- Fails gracefully if denied

## Debug Commands

### View Pending Notifications:
In TaskManager or a View, call:
```swift
Task {
    await NotificationManager.shared.printPendingNotifications()
}
```

This prints to console:
```
=== Pending Notifications (4) ===
ID: ABC-123-reminder
Title: Task Starting Soon
Body: ⏰ Complete project starts in 15 minutes
Scheduled for: 2025-12-04 14:45:00
---
ID: ABC-123
Title: Task Due Now
Body: 🔔 Complete project is due now!
Scheduled for: 2025-12-04 15:00:00
---
```

## Troubleshooting

### Notifications Not Appearing
**Check:**
1. Settings → Notifications → Status = "Authorized"
2. Pending Reminders count > 0
3. Task has a due time set
4. Due time is in the future
5. iOS Settings → AutoDay → Allow Notifications is ON

### Notifications Silent
**Check:**
1. iPhone not in Silent Mode
2. iOS Settings → AutoDay → Sounds = ON
3. Do Not Disturb is OFF

### Actions Not Working
**Check:**
1. Notification categories are set up (done automatically on app launch)
2. Try force-quitting and restarting app
3. Check console for error messages

## Future Enhancements

Potential improvements:
- [ ] Customizable reminder time (5, 10, 15, 30 minutes)
- [ ] Multiple reminders per task
- [ ] Different notification sounds per task priority
- [ ] Notification history
- [ ] Rich notifications with task details
- [ ] Location-based reminders
- [ ] Smart reminders based on travel time

## Code Changes Made

### NotificationManager.swift
- ✅ Enhanced `scheduleNotification()` to schedule both reminder and due time notifications
- ✅ Updated `cancelNotification()` to cancel both notification types
- ✅ Added `getPendingNotifications()` for debugging
- ✅ Added `printPendingNotifications()` for console debugging

### SettingsView.swift
- ✅ Added notification status indicator
- ✅ Added pending notifications counter
- ✅ Enhanced notification footer with explanation
- ✅ Auto-updates count when view appears

All existing notification scheduling calls in ToDoView.swift continue to work automatically with the enhanced system!
