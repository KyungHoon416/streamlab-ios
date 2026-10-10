# Astra Phase 1 development instructions

Work from the current GitHub repository KyungHoon416/streamlab-ios. XcodeGen creates the Xcode project using project.yml.

1. Use macOS with Xcode and validate `./scripts/bootstrap-mac.sh`.
2. Build StreamLab target with Swift 6 strict concurrency enabled; fix errors rather than suppressing diagnostics.
3. Run `cd Packages/StreamLabCore && swift test` and report actual results.
4. Replace any temporary blue-screen test root with ProfileSelectionView and verify three profiles.
5. Exercise Home, Search, Detail, cursor pagination, Kids profile restrictions, task cancellation and stale-response fencing.
6. Create deterministic race tests and test profile switching during delayed async responses.
7. Verify Dynamic Type, VoiceOver, and minimum tap targets.
8. Record build/test logs and any remaining failures in Docs/PHASE1_REPORT.md.
9. Do not claim HLS playback is implemented. It belongs to Phase 2.
10. Keep StreamLab modules isolated and use only legally distributable demo assets.
