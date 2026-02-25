---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [PROFILE_SCREEN_PLAN.md](../../lib/presentation/screens/profile/PROFILE_SCREEN_PLAN.md) - Implementation details with code examples
>
> **Related:** [DATABASE Overview](../data/DATABASE_OVERVIEW.md) | [AUTH Overview](../architecture/AUTH_OVERVIEW.md) | [Provider Guide Overview](../guides/PROVIDER_GUIDE_OVERVIEW.md)
---

# Profile Screen Overview

## Purpose

The Profile Screen displays and allows editing of user information. It demonstrates interactive Provider usage with edit mode, form validation, and save operations.

## Key Features

| Feature | Description |
|---------|-------------|
| **View Mode** | Display user name, email, avatar |
| **Edit Mode** | Toggle to edit profile fields |
| **Form Validation** | Validate inputs before saving |
| **Profile Picture** | Display and enlarge avatar |
| **Statistics** | Show user activity summary |
| **Logout** | Sign out with confirmation |

## User Flow

```
┌─────────────────────────────────────────────────┐
│                 Profile Screen                   │
│                                          [Edit]  │
│                                                  │
│           ┌───────────────┐                     │
│           │     Avatar    │  ← Tap to enlarge   │
│           │      (JD)     │                     │
│           └───────────────┘                     │
│                                                  │
│              John Doe                           │
│           john@email.com                        │
│                                                  │
│  ─────────────────────────────────────────────  │
│                                                  │
│  │ Sessions │ Distance │ Calories │            │
│  │    12    │   45 km  │   1200   │            │
│                                                  │
│              [ Logout ]                         │
│                                                  │
└─────────────────────────────────────────────────┘
```

## Edit Mode

When edit mode is activated:

| Element | View Mode | Edit Mode |
|---------|-----------|-----------|
| **Name** | Text display | TextField |
| **Email** | Text display | TextField |
| **AppBar** | Edit button | Cancel button |
| **Save** | Hidden | Save button visible |

## State Management

The Profile Provider manages:
- User data loading
- Edit mode toggle
- Temporary form values
- Save operation
- Validation errors

## Interaction Flow

### Entering Edit Mode
1. User taps Edit button
2. Current values copied to temp fields
3. TextFields appear with current data
4. Save and Cancel buttons shown

### Saving Changes
1. User modifies fields
2. User taps Save
3. Validation runs
4. If valid, data saved to database
5. Edit mode exits, view updates

### Canceling Edit
1. User taps Cancel
2. Temp values discarded
3. Returns to view mode
4. No changes saved

## Profile Picture

- Displays user initials in colored circle
- Tappable to show enlarged view
- Uses Hero animation for smooth transition
- Future: Support for image upload

## Statistics Section

Displays user achievements:
- Total sessions completed
- Total distance covered
- Estimated calories burned

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Authentication | [AUTH.md](../../AUTH.md) | [AUTH_OVERVIEW](../architecture/AUTH_OVERVIEW.md) |
| Progress Screen | [PROGRESS_SCREEN_PLAN.md](../../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) | [PROGRESS_SCREEN_OVERVIEW](./PROGRESS_SCREEN_OVERVIEW.md) |
| Provider Pattern | [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) | [PROVIDER_GUIDE_OVERVIEW](../guides/PROVIDER_GUIDE_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
