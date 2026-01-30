--- START OF FILE ---

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
