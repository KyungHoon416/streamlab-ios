# Paste into GPT-6 Astra after attaching this project ZIP and the challenge document

You are the Staff iOS engineer implementing StreamLab Phase 1. You have access to a Mac with Xcode and the attached `StreamLab-Phase1` starter project and `Netflix_iOS_과제.docx`.

**Instructions**
1. Inspect every starter file and the challenge. Preserve the working `StreamLabCore` contract and deterministic 2,000-item fixture; do not rewrite it without need.
2. Install or check XcodeGen, run `./scripts/bootstrap-mac.sh`, open the generated `StreamLab.xcodeproj` and run a simulator build. Fix all compiler/linker/package-resolution errors. Do not claim to have built unless an actual Xcode build command exited 0.
3. Run `cd Packages/StreamLabCore && swift test`. Keep the 7 existing tests green. Extend tests for cancellation and rapid profile switches where feasible.
4. Ensure Swift 6 strict concurrency diagnostics are zero in app and both packages. Fix actor/isolation violations correctly, never by hiding warnings or using unsafe global state.
5. Manually validate flows: select Alex/Jamie/Kids, view hero and five rails, browse details, fast search, pagination, switch profiles and verify no cross-profile visibility. Use an iPhone 16 or other available simulator and include device/OS in results.
6. Where the source assignment says *image lazy loading*, current starter has offline, lazily constructed placeholder poster art. If real remote images are added, use a legally distributable source with caching and cancellation; document licensing and missing paths. Do not fetch Netflix assets.
7. Verify accessibility labels and Dynamic Type, particularly poster cards and 44x44pt tap areas. Fix gaps without changing module boundaries.
8. Add a real test proving stale search responses never overwrite the latest query. Model realistic reversals using a deterministic injected clock/repository instead of relying on a flaky network delay.
9. Update `Docs/PHASE1_REPORT.md` with exact build/test commands, simulator screenshot paths (if created), failures/fixes, known gaps and final Phase 1 status. Keep play/download buttons honest: HLS player is a Phase 2 feature.
10. Do not start Phase 2 until Phase 1 acceptance criteria pass or the remaining blockers are explicitly documented.

**Required output**
- Real updated source files (not illustrative snippets).
- Xcode simulator build log summary and Swift test summary.
- Matrix of `Docs/PHASE1_SPEC.md` requirements (pass/partial/fail/not-tested).
- Changed files and explanation of each substantive fix.
- Phase 2 proposed contracts for PlayerEngine + PlayerState machine; no incomplete placeholder implementation.

**Do not** claim Netflix affiliation, use private APIs, submit copyrighted media, invent test results, or suppress compile errors with `try?`/`catch {}`.
