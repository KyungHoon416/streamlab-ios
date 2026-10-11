#!/usr/bin/env python3
"""Structural checks only. This is NOT a Swift compiler or Interface Builder."""
import re
import plistlib
from pbxproj import loads, source_paths
import xml.etree.ElementTree as ET
from pathlib import Path
root = Path(__file__).resolve().parent.parent
ui = root / 'Packages/StreamLabUI/Sources'
manifest = (root / 'Packages/StreamLabUI/Package.swift').read_text()
expected = {'Profile': ('Profiles', 'StreamLabProfileFeature'), 'Home': ('Home', 'StreamLabCatalogFeature'), 'Search': ('Search', 'StreamLabCatalogFeature'), 'Detail': ('Detail', 'StreamLabCatalogFeature')}
assert len(list(ui.rglob('*.storyboard'))) == 4
for name, (identifier, module) in expected.items():
    path = ui / module / name / (name + '.storyboard')
    storyboard = ET.parse(path).getroot()
    ids = [e.attrib['id'] for e in storyboard.iter() if 'id' in e.attrib]
    assert len(ids) == len(set(ids)), 'Duplicate storyboard IDs'
    ids = set(ids)
    assert storyboard.get('initialViewController') in ids
    for element in storyboard.iter():
        for attribute in ['firstItem', 'secondItem', 'destination']:
            if attribute in element.attrib:
                assert element.attrib[attribute] in ids
    controllers = storyboard.findall('.//viewController')
    assert len(controllers) == 1
    controller = controllers[0]
    assert controller.get('sceneMemberID') == 'viewController', f'{name}: missing scene controller membership'
    assert storyboard.get('initialViewController') == controller.get('id')
    assert controller.get('storyboardIdentifier') == identifier
    assert controller.get('customModule') == module
    cls = controller.get('customClass')
    source = (path.parent / (cls + '.swift')).read_text()
    assert f'class {cls}:' in source
    assert f'UIStoryboard(name: "{name}", bundle: .module)' in source
    assert f'withIdentifier: "{identifier}"' in source
    for outlet in controller.findall('./connections/outlet'):
        assert re.search(r'@IBOutlet[^\n]*\b' + outlet.get('property') + r'\s*:', source)
    assert f'.process("{name}/{name}.storyboard")' in manifest
sources = [p for folder in ['App', 'Packages', 'Tests']
           for p in (root / folder).rglob('*.swift')
           if not any(part.startswith('.') for part in p.relative_to(root).parts)]
assert not any(re.search(r'import SwiftUI|UIHostingController', p.read_text()) for p in sources)
assert 'StreamLabPresentation' in (root / 'Packages/StreamLabCore/Package.swift').read_text()
assert 'StreamLabPresentation' in manifest
assert 'SWIFT_TREAT_WARNINGS_AS_ERRORS: YES' in (root / 'project.yml').read_text()
assert 'case duplicateID' in (root / 'Packages/StreamLabCore/Sources/StreamLabDomain/Models/Models.swift').read_text()
project = (root / 'StreamLab.xcodeproj/project.pbxproj').read_text()
parsed_project = loads(project)
compiled_paths = source_paths(parsed_project)
for path in ['App/Application/AppDelegate.swift', 'App/Scene/SceneDelegate.swift', 'Tests/StreamLabUITests/StreamLabUITests.swift']:
    assert (root / path).is_file()
    assert path in compiled_paths, f'Missing Sources build phase entry: {path}'
assert 'App/Resources/Main.storyboard' not in project
scene_source = (root / 'App/Scene/SceneDelegate.swift').read_text()
for name in expected:
    assert f'{name}ViewController.instantiate()' in scene_source
ET.parse(root / 'StreamLab.xcodeproj/xcshareddata/xcschemes/StreamLab.xcscheme')
print('PASS: 4 separate feature Storyboards, sibling controllers, outlets/modules, package resource declarations, bundle-scoped factories, project paths, scheme XML, no SwiftUI')
print('NOT TESTED: Swift type checking, ibtool compilation, Auto Layout runtime, UIKit linking and execution')

info = plistlib.loads((root / 'App/Configuration/Info.plist').read_bytes())
config = info['UIApplicationSceneManifest']['UISceneConfigurations']['UIWindowSceneSessionRoleApplication'][0]
assert config['UISceneConfigurationName'] == 'StreamLab'
assert config['UISceneClassName'] == 'UIWindowScene'
assert config['UISceneDelegateClassName'] == '$(PRODUCT_MODULE_NAME).SceneDelegate'
assert 'UIMainStoryboardFile' not in info
assert 'UISceneStoryboardFile' not in config
objects = parsed_project['objects']
app_targets = [obj for obj in objects.values()
               if obj['isa'] == 'PBXNativeTarget' and obj.get('name') == 'StreamLab']
assert len(app_targets) == 1
configs = objects[app_targets[0]['buildConfigurationList']]['buildConfigurations']
assert {objects[c]['name'] for c in configs} >= {'Debug', 'Release'}
for config_id in configs:
    config = objects[config_id]
    assert config['buildSettings'].get('INFOPLIST_FILE') == 'App/Configuration/Info.plist', config['name']
assert 'INFOPLIST_KEY_UIApplicationSceneManifest_Generation' not in project
assert 'INFOPLIST_FILE: App/Configuration/Info.plist' in (root / 'project.yml').read_text()
print('PASS: explicit scene manifest and Debug/Release Info.plist references')
