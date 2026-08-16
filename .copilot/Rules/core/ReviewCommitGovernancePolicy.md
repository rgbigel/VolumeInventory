---
name: ReviewCommitGovernancePolicy
description: Authoritative governance policy for Review-Gated Commits, Acceptance with Edits, and Forced Commit Overrides.
globs: "*"
---
# File: ReviewCommitGovernancePolicy.md

Module: ReviewCommitGovernancePolicy  
Purpose: Defines mandatory review-gated commit rules, review disposition handling, forced commit overrides, and audit logging.  
Path: .copilot/Rules/ReviewCommitGovernancePolicy.md  
Authors: Rolf, Workspace_AI Governance  
Version: 1.0.0  
Status: Authoritative Policy  
Date: 2026-08-16  

---

## 1. Governance Rules

### RULE-REV-001: Mandatory Review-Gated Commits
Every Git commit action for source code, configuration, or structural assets in any LCM-governed repository requires a prior validated review disposition (`ACCEPTED` or `ACCEPTED_WITH_EDITS`) produced via the formal review process (e.g., Beyond Compare 5 via `Invoke-BeyondCompareReview.ps1` / `Submit-ReviewResult.ps1` / `RR.ps1`, or explicit user review in chat/CR).

### RULE-REV-002: Accepted with Edits Qualification
When a review outcome is recorded as `Accepted with Edits` (or `Accepted with Change`):
1. The modified codebase `MUST` execute and satisfy all repository quality gates (`Test-RepoReadiness.ps1`).
2. The modifications `MUST NOT` introduce rule violations, regression errors, or broken dependencies.
3. Upon satisfying all quality gates, the state `SHALL` be classified as fully `ACCEPTED` and committed to Git.

### RULE-REV-003: Override & Force Authority for Rejected/Deferred States
If a review outcome is `REJECTED` or `DEFERRED`:
1. Automated commit and push pipelines `MUST` halt immediately.
2. Committing or pushing changes in a rejected or deferred state `IS FORBIDDEN` unless explicitly commanded by the user with a forced override instruction (e.g., `-Force` parameter or unambiguous explicit override prompt).

### RULE-REV-004: Precedence Over General Permission Rules
The review-gating rules (`RULE-REV-001` through `RULE-REV-003`) take strict precedence over any general "all commands are permitted" or automated background execution policies in effect across the workspace.

### RULE-REV-005: Universal Audit & Change Request Traceability
Every review disposition (`Accepted`, `AcceptedWithEdits`, `Rejected`, `Deferred`) `MUST` be recorded with an immutable timestamp, reviewer identity, repository HEAD SHA, and notes into:
1. `Workspace_Inventory/logs/cm_activity.log` (Append-only CM audit ledger).
2. `Workspace_Inventory/data/reviews/REVIEW-<Repo>-<Timestamp>.json` (Structured review evidence).
3. The active Change Request (CR) record in `Workspace_Inventory/data/change_requests.json` and mirrored proposal Markdown files when modifying governed baselines.
