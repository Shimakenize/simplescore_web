# Simple Score Web – Step7 Design Document

This document is the SINGLE SOURCE OF TRUTH for the application behavior
at Step7.  
Code, AI instructions, and future changes must follow this document.

---

## 1. Purpose

- Clarify current app behavior and structure
- Prevent regressions
- Enable safe AI-assisted development (Copilot / ChatGPT)
- Serve as a reference before Firebase or DB integration

This document records INTENTIONAL design decisions.

---

## 2. Platform & Scope

- Platform: Web only
- Framework: Flutter (Web)
- Persistence: None at Step7 (in-memory only)
- UI: Functional only (design polish deferred)

---

## 3. Screen Structure

HomeScreen  
- Entry point  
- Starts a new match  
- No persistence  
- No restore logic  

MatchScreen  
- Active match screen  
- Manages timer, scores, goal events  
- Handles match phase transitions  

ResultScreen  
- Read-only  
- Displays results  
- No state mutation  
- No auto-navigation  

---

## 4. Navigation Flow

HomeScreen → MatchScreen → ResultScreen

Rules:
- Navigation is explicit only
- No time-based auto transitions
- All transitions are button-driven

---

## 5. Match Phases

Phases:
- First Half
- Half Time (HT)
- Second Half
- Match End

Transitions:
- First Half → HT (button)
- HT → Second Half (button)
- Second Half → Match End (button)

Automatic transitions are intentionally NOT used
(to allow additional time and corrections).

---

## 6. Match State (In-Memory)

Core state:
- teamA / teamB
- scoreA / scoreB
- totalElapsedSec
- firstHalfElapsedSec
- secondHalfElapsedSec
- events

Events:
- Represent goals
- Include team and timestamp
- Order is preserved

---

## 7. Result Display

Result sections:
- Full Match
- First Half
- Second Half

Display rules:
- Same layout for all sections
- Clear visual separators
- Two-column layout
  - Left: Team A
  - Right: Team B
- Team names are NOT shown inside columns
- Time and values aligned to each side

---

## 8. Persistence (Design Only – No Implementation Yet)

### 8.1 Save

Timing:
- Called in MatchScreen._finishMatch()
- Immediately BEFORE navigating to ResultScreen

Storage key:
- latest_match_result

Saved data:
- teamA / teamB
- scoreA / scoreB
- totalElapsedSec
- firstHalfElapsedSec
- secondHalfElapsedSec
- extraFirstHalfElapsedSec
- extraSecondHalfElapsedSec
- pkA
- pkB
- events

Notes:
- Stored as JSON
- Web only (dart:html localStorage)
- UI and navigation must NOT change
- Best-effort (failure ignored)

---

### 8.2 Load

Timing:
- App startup only
- main() or HomeScreen.initState()

Behavior:
- Read localStorage if present
- Ignore errors
- No auto-navigation
- No auto-restore

Purpose:
- For future manual restore or review features
- Not part of Step7 UX

Clarifications:
- This load operation is intentionally SILENT.
- No UI change, no navigation, and no visible state difference is expected.
- Successful load cannot be confirmed by visual behavior.
- Correctness is defined as:
  - App starts normally even if data exists or is corrupted.
  - No crashes occur during startup.
- Data is loaded into an in-memory cache only, for future manual restore or review features.
- Temporary debug logging MAY be used during development to verify loading,
  but must be removed after confirmation.

---

### 8.3 Review Latest Match (Manual Load UI)

Purpose:
- Provide a manual way to view the saved `latest_match_result` from the initial screen.
- This is a “review” feature only. It does NOT restore active match state.

UI Placement:
- HomeScreen (initial screen) shows an optional button when saved data exists.
- Button example label: “View latest match”.
- If no saved data exists, the button is hidden or disabled.

Behavior:
- Button press navigates explicitly to ResultScreen.
- ResultScreen displays data from the loaded in-memory cache.
- Navigation is explicit only (button-driven).
- No automatic navigation on startup.
- No automatic match restoration.

Data Source:
- Uses the in-memory cache loaded at startup from section 8.2.
- If the cache is null or invalid, the feature is unavailable.

Error Handling:
- Best-effort.
- Corrupted or unexpected data must be ignored.
- The app must not crash.

Non-Goals:
- Viewing multiple match histories
- Editing past results
- Starting MatchScreen from loaded data
- Auto resume or auto restore

---

### 8.4 Team & Roster Management (My Teams)

Purpose:
- Provide practical team/member registration with persistence.
- Enable selecting Team A / Team B from registered teams while still allowing manual entry.
- Enable selecting a scorer from the registered roster when recording goals, while still allowing manual entry.

UI Placement:
- SetupScreen (initial screen):
  - Add a button: "My Teams" to manage team rosters.
  - Team A / Team B inputs support:
    - Dropdown selection from My Teams (registered team names)
    - Manual typing/editing at any time (even after selection)
- MatchScreen:
  - When adding a goal, scorer input supports:
    - Dropdown selection from the selected team’s roster (if available)
    - Manual typing/editing (jersey number and name)

Navigation:
- SetupScreen → MyTeamsScreen (explicit button press only)
- MyTeamsScreen → TeamEditorScreen (explicit selection only)
- All navigation is explicit (button-driven).
- No auto-navigation on startup.

Data Model:
- Team:
  - id (string, stable identifier)
  - name (string)
  - members: list of Member
- Member:
  - number (int) 0-99
  - name (string)

Constraints:
- Max teams: 10
- Member number range: 0-99
- Member number should be unique within a team (best-effort validation).
- Empty rows are ignored on save (best-effort).

Persistence (Web localStorage):
- Storage key: my_teams_v1
- Stored as JSON
- Best-effort (failures ignored)
- Save timing:
  - Explicit "Save" action in TeamEditorScreen
  - No auto-save while editing
- Load timing:
  - App startup only (main() or SetupScreen.initState())
- Persistence scope:
  - This is roster data only (team & members).
  - Must not auto-restore match state.

SetupScreen: Team Selection (Dropdown + Manual Input)
- Dropdown shows:
  - "(manual)" option
  - All registered team names (non-empty)
- Selecting a team from dropdown:
  - Copies the selected team name into the corresponding Team A / Team B text input.
  - Does NOT lock the input; user can freely edit the name afterward.
- Manual typing:
  - Always allowed regardless of dropdown selection.
- Passing identifiers:
  - When Team A / Team B is selected from My Teams, pass its teamId (id) into MatchScreen.
  - When "(manual)" is used, pass null for teamId.

MatchScreen: Scorer Selection (Roster Dropdown + Manual Input)
- When user presses "+ Goal" for Team A or Team B:
  - Open a scorer input dialog.
- Dialog behavior:
  - If roster exists for that team (based on teamId passed from Setup):
    - Show a dropdown listing roster members as "#<number> <name>" plus a "(manual)" option.
    - Selecting a member auto-fills jersey number and name fields.
  - Regardless of roster presence:
    - Jersey number field is editable (0-99, best-effort clamp/validation).
    - Name field is editable (optional).
- Event recording:
  - Store scorer info in the goal event payload:
    - playerNo (int)
    - playerName (string, possibly empty)
- Non-goals:
  - This feature does not enforce a strict roster-only policy.
  - Manual input remains available as an override.

Error Handling:
- Best-effort.
- Invalid/corrupted localStorage data:
  - Treated as no saved teams.
  - App must not crash.
- UI should remain usable even when roster data is missing.

Non-Goals:
- Firebase or DB
- Authentication
- Auto-sync across devices
- Auto-save while editing
- CSV import (future)
- Automatic injection of roster into match unless explicitly chosen by the user

---

## 9. Explicit Non-Goals

- Firebase or database
- Authentication
- Auto resume
- Background timers
- UI polish

---

## 10. AI Collaboration Rules

This document must be referenced when using AI tools.

Examples:
- “Implement according to section 8.1 Save”
- “Do not change behavior outside section 7”

---

## 11. Change Policy

- Behavior changes require document updates first
- Code-only changes are incomplete
- Regression fixes must respect this design

--- END OF FILE ---
