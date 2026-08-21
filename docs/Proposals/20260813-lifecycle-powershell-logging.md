# Proposal: Lifecycle PowerShell Conformance and Logging Divergence Notes

proposal_id: VI-20260813-lifecycle-powershell-logging
status: pending-review
repository: VolumeInventory
created: 20260813_194051
version: 2.5.0
scope: VolumeInventory; read-only observations under D:/Git_Repositories

## Summary

Bring VolumeInventory PowerShell structure into Workspace_GC lifecycle methodology and record the current cross-repository Logging.psm1 divergence in a target-local, easy-to-find review artifact.

## Implemented Local Slice

- Updated `src/VolumeInventory.ps1` helper functions to include `[CmdletBinding()]` and explicit `param()` blocks.
- Updated `src/VolumeInventory.ps1` header metadata to version `2.5.0` and date `2026-08-13`.
- Added Pester coverage requiring helper functions to remain advanced and self-contained.
- Updated `docs/CHANGELOG.md` with the `2.5.0` method-clean structural conformance entry.

## Validation

- Parser check: `Parser OK: src/VolumeInventory.ps1`.
- Pester: `Passed: 3 Failed: 0`.

## Logging.psm1 Divergence Observations

Read-only scan under `D:/Git_Repositories` found three distinct `Logging.psm1` variants:

| Repo or folder | Proper repo | Path | LastWriteTime | SHA256 | Observation |
| --- | --- | --- | --- | --- | --- |
| SharedModules | yes | `D:/Git_Repositories/SharedModules/Modules/Logging.psm1` | `20260719_164225` | `C4E619F47A86CF41575348DFD7DAA618258C47F7B0158D34B635C8E1F23E67C0` | Newest copy; exports context API and legacy `Write-Log`. |
| BackgroundModifier | yes | `D:/Git_Repositories/BackgroundModifier/Modules/Logging.psm1` | `20260719_164217` | `7D0A7DAB83C4D4D9247BE15309EB244B9856F66AD06E3D6F7683655421935AC1` | Local solution-specific logging copy with `Write-ContentMutationLog`. |
| BackgroundModifier_AC | yes | `D:/Git_Repositories/BackgroundModifier_AC/Modules/Logging.psm1` | `20260719_164217` | `7D0A7DAB83C4D4D9247BE15309EB244B9856F66AD06E3D6F7683655421935AC1` | Same content as BackgroundModifier. |
| BootOpsHub | no | `D:/Git_Repositories/BootOpsHub/SolutionCode/Modules/Logging.psm1` | `20260719_164219` | `383AF2B6CE22AC3DD1582635665014F7AA9189577365E01F99AC8E670C55AA50` | Non-proper repo copy; minimal logging helpers. |

Because the explicit task scope forbids modifications outside VolumeInventory and SharedModules, no proposal files were written into BackgroundModifier or BackgroundModifier_AC. If that scope is later expanded, create target-local proposal files in those proper repos to migrate or justify their local Logging.psm1 copies.

## Preferred Logging Direction

SharedModules appears to be the preferred baseline by timestamp and interface documentation. No evidence from this scan indicates that `SharedModules/Modules/Logging.psm1` is outdated.

For repositories that need shared logging, prefer importing `D:/Git_Repositories/SharedModules/Modules/Logging.psm1` and using:

- `Initialize-LogContext`
- `Write-LogHeader`
- `Write-LogMessage`
- `Write-TraceLog`
- `Write-LogFinalStatus`
- `Close-LogContext`

Keep local `Write-Log` compatibility only as a temporary migration bridge. If a repository has solution-specific behavior such as content mutation audit logging, keep it in a separate repo-local module or propose promotion to SharedModules after review.

## Proposed Next Steps

1. Accept the VolumeInventory structural conformance changes after review.
2. Keep VolumeInventory free of a copied `Logging.psm1` unless a concrete logging requirement is introduced.
3. Use SharedModules as the central logging baseline for future migrations.
4. When scope allows, create separate target-local proposals in BackgroundModifier and BackgroundModifier_AC for their divergent local logging modules.
