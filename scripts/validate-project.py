#!/usr/bin/env python3
"""Structural checks only; never a substitute for SwiftUI compilation or execution."""
import plistlib
import re
import xml.etree.ElementTree as ET
from pathlib import Path
from pbxproj import loads, source_paths

root = Path(__file__).resolve().parent.parent
ui = root / "Packages/StreamLabUI/Sources"
manifest = (root / "Packages/StreamLabUI/Package.swift").read_text()
sources = [p for folder in ("App", "Packages", "Tests")
           for p in (root / folder).rglob("*.swift")
           if not any(part.startswith(".") for part in p.relative_to(root).parts)]
assert not list(ui.rglob("*.storyboard")), "Obsolete Storyboard resources remain"
# SwiftUI owns all screens. UIKit is limited to media/scene adapters, including
# UIImage artwork passed to the system Now Playing card (not an app screen).
bridges = {
    # Protected data notifications and a first-frame display link.
    "App/Scene/AppRootView.swift",
    "Packages/StreamLabUI/Sources/StreamLabCatalogFeature/State/CatalogAccount.swift",
    "Packages/StreamLabUI/Sources/StreamLabCatalogFeature/State/KeychainLockDiagnosticView.swift",
    # Poster layer, layout tracing and poster adapter tests.
    "Packages/StreamLabUI/Sources/StreamLabDesignSystem/Images/ArtworkImageSurface.swift",
    "Packages/StreamLabUI/Sources/StreamLabDesignSystem/Theme/HomeStartupTrace.swift",
    # Opt-in deterministic scrolling for measured C/PV comparisons only.
    "Packages/StreamLabUI/Sources/StreamLabDesignSystem/Theme/HomeScrollMeasurementProbe.swift",
    "Packages/StreamLabUI/Tests/StreamLabCatalogFeatureTests/ArtworkSurfaceTests.swift",
    # System memory-warning notification only; all rendering remains SwiftUI.
    "Packages/StreamLabUI/Sources/StreamLabDesignSystem/Images/ArtworkMemoryLifecycle.swift",
    "App/Application/DownloadBackgroundDelegate.swift",
    # System notification settings and foreground/background state only.
    "Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Downloads/DownloadNotifications.swift",
    "Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Downloads/OfflineDownloadStore.swift",
    "Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Playback/PlayerSurface.swift",
    "Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Playback/PlaybackOrientation.swift",
    "Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Playback/PlaybackNowPlaying.swift",
}
for p in sources:
    text = p.read_text()
    assert not re.search(r"UIHostingController|UIStoryboard|@IBOutlet|class (AppDelegate|SceneDelegate)", text), p
    if "import UIKit" in text:
        assert p.relative_to(root).as_posix() in bridges, p
assert all((root / p).is_file() for p in bridges)

assert ".storyboard" not in manifest
assert "StreamLabPresentation" in manifest
app = (root / "App/Application/StreamLabApp.swift").read_text()
assert "@main" in app and "StreamLabApp: App" in app and "WindowGroup" in app
entrypoints = [p for p in sources if re.search(r"^\s*@main\b", p.read_text(), re.M)]
assert len(entrypoints) == 1, entrypoints
for module, name in (("StreamLabProfileFeature", "Profile/ProfileSelectionView"),
                     ("StreamLabCatalogFeature", "Home/HomeView"),
                     ("StreamLabCatalogFeature", "Search/SearchView"),
                     ("StreamLabCatalogFeature", "Detail/DetailView")):
    text = (ui / module / (name + ".swift")).read_text()
    assert "import SwiftUI" in text and ": View" in text
home = (ui / "StreamLabCatalogFeature/Home/HomeView.swift").read_text()
search = (ui / "StreamLabCatalogFeature/Search/SearchView.swift").read_text()
assert "LazyHStack" in home and "LazyVStack" in home and "LazyVStack" in search
for name in ("Home/HomeView", "Search/SearchView", "Detail/DetailView"):
    text = (ui / "StreamLabCatalogFeature" / (name + ".swift")).read_text()
    assert "@StateObject" in text and ".onDisappear" in text and ".onChange(of: phase)" in text
root_view = (root / "App/Scene/AppRootView.swift").read_text()
assert ".id(session.id)" in root_view and "session?.invalidate()" in root_view
assert "NavigationStack" in root_view and "TabView" in root_view

project = loads((root / "StreamLab.xcodeproj/project.pbxproj").read_text())
compiled = source_paths(project)
expected = {"App/Application/StreamLabApp.swift", "App/Scene/AppRootView.swift",
            "Tests/StreamLabUITests/StreamLabUITests.swift"}
assert expected <= set(compiled), (expected, compiled)
assert all((root / p).is_file() for p in compiled), compiled
assert not any(p.endswith(("/AppDelegate.swift", "/SceneDelegate.swift")) for p in compiled)
info = plistlib.loads((root / "App/Configuration/Info.plist").read_bytes())
assert "UISceneConfigurations" not in info.get("UIApplicationSceneManifest", {})
assert "UIMainStoryboardFile" not in info
objects = project["objects"]
targets = {key: obj for key, obj in objects.items() if obj["isa"] == "PBXNativeTarget"}
app_target = next(obj for obj in targets.values() if obj["name"] == "StreamLab")
configs = objects[app_target["buildConfigurationList"]]["buildConfigurations"]
for config_id in configs:
    assert objects[config_id]["buildSettings"]["INFOPLIST_FILE"] == "App/Configuration/Info.plist"
scheme = ET.parse(root / "StreamLab.xcodeproj/xcshareddata/xcschemes/StreamLab.xcscheme")
for reference in scheme.findall(".//BuildableReference"):
    assert reference.get("BlueprintIdentifier") in targets, reference.attrib
# Check the installed catalog, including launches outside Xcode.
app_id = next(key for key, target in targets.items() if target is app_target)
assert info["StreamLabCatalog"] == "$(STREAMLAB_CATALOG)"
for name, use_firebase in (("StreamLab", True), ("StreamLab-Firebase", True), ("StreamLab-Demo", False)):
    shared = ET.parse(root / f"StreamLab.xcodeproj/xcshareddata/xcschemes/{name}.xcscheme")
    for action, base in (("LaunchAction", "Debug"), ("ProfileAction", "Release"), ("ArchiveAction", "Release")):
        chosen = shared.find(action).get("buildConfiguration")
        assert chosen == ("Firebase" + base if use_firebase else base), (name, action, chosen)
        settings = next(objects[key]["buildSettings"] for key in configs if objects[key]["name"] == chosen)
        assert settings["STREAMLAB_CATALOG"] == ("firebase" if use_firebase else "demo")
    for action in ("LaunchAction", "ProfileAction"):
        ref = shared.find(f"{action}/BuildableProductRunnable/BuildableReference")
        assert ref is not None and ref.get("BlueprintIdentifier") == app_id, (name, action)
        args = shared.findall(f"{action}/CommandLineArguments/CommandLineArgument")
        enabled = {arg.get("argument") for arg in args if arg.get("isEnabled") == "YES"}
        assert ("--firebase-catalog" in enabled) == (name == "StreamLab-Firebase"), (name, action, enabled)
# C4 aliases must pass identical diagnostic arguments to Run and Profile.
measurement_schemes = {
    "StreamLab-C4-Scroll-C": ("Release", {"--trace-home-startup", "--measure-home-scroll", "--home-render-experiment=C"}),
    "StreamLab-C4-Scroll-PV": ("Release", {"--trace-home-startup", "--measure-home-scroll", "--home-render-experiment=PV"}),
    "StreamLab-C4-Download-Energy": ("FirebaseRelease", {"--firebase-catalog", "--trace-download-energy"}),
}
for name, (config, expected) in measurement_schemes.items():
    shared = ET.parse(root / f"StreamLab.xcodeproj/xcshareddata/xcschemes/{name}.xcscheme")
    assert shared.find("ProfileAction").get("shouldUseLaunchSchemeArgsEnv") == "NO"
    for action in ("LaunchAction", "ProfileAction"):
        assert shared.find(action).get("buildConfiguration") == config
        ref = shared.find(f"{action}/BuildableProductRunnable/BuildableReference")
        assert ref.get("BlueprintIdentifier") == app_id
        args = shared.findall(f"{action}/CommandLineArguments/CommandLineArgument")
        assert {a.get("argument") for a in args if a.get("isEnabled") == "YES"} == expected
    assert name + ":" in (root / "project.yml").read_text()

assert "SWIFT_TREAT_WARNINGS_AS_ERRORS: YES" in (root / "project.yml").read_text()
print("PASS: SwiftUI App + four feature views, lazy containers, profile identity, lifecycle wiring")
print("PASS: package declarations, compiled source paths, scheme target IDs and Info.plist")
print("NOT TESTED: Swift type checking, iOS build, SwiftUI layout/accessibility/runtime")

