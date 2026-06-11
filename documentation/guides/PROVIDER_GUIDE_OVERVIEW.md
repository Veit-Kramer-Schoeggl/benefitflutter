---
> **Documentation Type:** OVERVIEW (Concepts & Architecture)
>
> **Technical Version:** [PROVIDER_GUIDE.md](../../lib/presentation/PROVIDER_GUIDE.md) - Implementation details with code examples
>
> **Related:** [FEATURES Overview](../architecture/FEATURES_OVERVIEW.md) | [Screen Overviews](../screens/)
---

# Provider Pattern Overview

## What is the Provider Pattern?

Provider is a state management pattern for Flutter based on the ChangeNotifier pattern (similar to the Observer pattern). It enables automatic UI updates when data changes, making it easier to build reactive applications.

## The Newsletter Analogy

Think of Provider like a newsletter subscription:

| Concept | Analogy | What It Does |
|---------|---------|--------------|
| **Provider** | Newsletter publisher | Holds and manages data |
| **Consumer** | Subscriber | Listens for updates |
| **notifyListeners()** | Send newsletter | Notifies all subscribers |
| **Widget rebuild** | Read newsletter | UI updates automatically |

## Architecture Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Screen    │────►│  Provider   │────►│ Repository  │
│    (UI)     │     │  (State)    │     │   (Data)    │
└─────────────┘     └─────────────┘     └─────────────┘
       │                  │
       │                  │
  Consumer<T>()    notifyListeners()
  (auto rebuild)   (notify widgets)
       │                  │
       ▼                  ▼
┌─────────────┐    ┌─────────────┐
│   Widgets   │◄───│  ViewModel  │
│ (reusable)  │    │ (join data) │
└─────────────┘    └─────────────┘
```

## The 5 Components

### 1. Repository
- **What:** Data source (API, database)
- **Purpose:** Fetch and store data
- **Benefit:** Swappable via abstract interface + implementation (SQLite is the production implementation)

### 2. Provider
- **What:** State management + business logic
- **Purpose:** Hold state, call repository, notify UI
- **Benefit:** Central state management

### 3. ViewModel
- **What:** Data transformation layer
- **Purpose:** Combine and format data for UI
- **Benefit:** Clean separation of concerns

### 4. Screen
- **What:** Main view orchestrator
- **Purpose:** Initialize provider, handle states
- **Benefit:** Clear UI structure

### 5. Widgets
- **What:** Reusable UI components
- **Purpose:** Display data, no business logic
- **Benefit:** Reusable and testable

## State Handling

Every screen handles 4 states:

| State | When | UI Shows |
|-------|------|----------|
| **Loading** | Fetching data | Spinner/skeleton |
| **Error** | Request failed | Error message + retry |
| **Empty** | No data | Empty state message |
| **Success** | Data loaded | Content list/view |

## Key Methods

| Method | Purpose | Usage |
|--------|---------|-------|
| `context.read<T>()` | Get provider once | In event handlers |
| `context.watch<T>()` | Subscribe to changes | In build methods |
| `Consumer<T>` | Auto-rebuild widget | Wrap UI that needs updates |
| `notifyListeners()` | Trigger UI update | After state changes |

## Benefits

| Benefit | Description |
|---------|-------------|
| **Automatic Updates** | No manual setState() calls |
| **Separation** | Business logic separate from UI |
| **Testability** | Easy to mock and test |
| **Scalability** | Grows with app complexity |
| **Performance** | Rebuilds only affected widgets |

## Related Documentation

| Topic | Technical | Overview |
|-------|-----------|----------|
| Feature Modules | [FEATURES.md](../../lib/features/FEATURES.md) | [FEATURES_OVERVIEW](../architecture/FEATURES_OVERVIEW.md) |
| Activity Screen | [ACTIVITY_SCREEN_PLAN.md](../../lib/presentation/screens/activity/ACTIVITY_SCREEN_PLAN.md) | [ACTIVITY_SCREEN_OVERVIEW](../screens/ACTIVITY_SCREEN_OVERVIEW.md) |
| Progress Screen | [PROGRESS_SCREEN_PLAN.md](../../lib/presentation/screens/progress/PROGRESS_SCREEN_PLAN.md) | [PROGRESS_SCREEN_OVERVIEW](../screens/PROGRESS_SCREEN_OVERVIEW.md) |

[Back to Documentation Index](../README.md)
