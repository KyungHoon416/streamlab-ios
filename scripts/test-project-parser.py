#!/usr/bin/env python3
"""Regression checks for quoted and XcodeGen-style project representations."""
import unittest
from pathlib import Path
from pbxproj import loads, source_paths


class ProjectParserTests(unittest.TestCase):
    def test_checked_in_project_sources(self):
        project = loads((Path(__file__).resolve().parent.parent /
                         'StreamLab.xcodeproj/project.pbxproj').read_text())
        self.assertIn('App/Application/StreamLabApp.swift', source_paths(project))

    def test_group_relative_paths_and_comments(self):
        project = loads('''// !$*UTF8*$!
        { objects = {
          ROOT = { isa = PBXProject; mainGroup = MAIN; };
          MAIN = { isa = PBXGroup; children = (APP,); sourceTree = "<group>"; };
          APP = { isa = PBXGroup; path = App; children = (APPLICATION,); };
          APPLICATION = { isa = PBXGroup; path = Application; children = (FILE,); };
          FILE /* StreamLabApp.swift */ = { isa = PBXFileReference;
            path = StreamLabApp.swift; sourceTree = "<group>"; };
          BUILD = { isa = PBXBuildFile; fileRef = FILE /* StreamLabApp.swift */; };
          SOURCES = { isa = PBXSourcesBuildPhase; files = (BUILD,); };
          CONFIG = { isa = XCBuildConfiguration; buildSettings = {
            INFOPLIST_FILE = App/Configuration/Info.plist;
          }; };
        }; rootObject = ROOT; }''')
        self.assertEqual(source_paths(project), {'App/Application/StreamLabApp.swift'})
        self.assertEqual(project['objects']['CONFIG']['buildSettings']['INFOPLIST_FILE'],
                         'App/Configuration/Info.plist')
        project['objects']['SOURCES']['files'] = []
        self.assertEqual(source_paths(project), set(), 'An uncompiled reference must fail validation')
        project['objects']['SOURCES']['files'] = ['BUILD']
        project['objects']['APPLICATION']['path'] = 'WrongFolder'
        self.assertNotIn('App/Application/StreamLabApp.swift', source_paths(project))


if __name__ == '__main__':
    unittest.main()
