# 파일 변경 목록 — 화면별 폴더 분리

원본 스타터 대비 변경 목록입니다. 기존 GitHub 저장소의 2,000개 Fixture와 Core 7개 테스트는 변경 없이 유지했습니다.

| 구분 | 파일 |
|---|---|
| 추가 | `App/Application/AppDelegate.swift` |
| 추가 | `App/Scene/SceneDelegate.swift` |
| 삭제 | `App/StreamLabApp.swift` |
| 추가 | `Docs/ADR/0004-uikit-storyboards.md` |
| 추가 | `Docs/Archive/STARTER_CORE_TEST_LOG.txt` |
| 삭제 | `Docs/CORE_TEST_LOG.txt` |
| 추가 | `Docs/IMAGE_LOADING_DESIGN.md` |
| 수정 | `Docs/PHASE1_REPORT.md` |
| 수정 | `Packages/StreamLabCore/Package.swift` |
| 삭제 | `Packages/StreamLabCore/Sources/StreamLabCatalogData/MockCatalogRepository.swift` |
| 추가 | `Packages/StreamLabCore/Sources/StreamLabCatalogData/Repositories/MockCatalogRepository.swift` |
| 삭제 | `Packages/StreamLabCore/Sources/StreamLabDomain/Models.swift` |
| 추가 | `Packages/StreamLabCore/Sources/StreamLabDomain/Models/Models.swift` |
| 추가 | `Packages/StreamLabCore/Sources/StreamLabPresentation/Stores/CatalogStore.swift` |
| 추가 | `Packages/StreamLabCore/Tests/StreamLabPresentationTests/CatalogStoreTests.swift` |
| 수정 | `Packages/StreamLabUI/Package.swift` |
| 삭제 | `Packages/StreamLabUI/Sources/StreamLabCatalogFeature/CatalogViewModels.swift` |
| 삭제 | `Packages/StreamLabUI/Sources/StreamLabCatalogFeature/CatalogViews.swift` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Detail/Detail.storyboard` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Detail/DetailViewController.swift` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Home/Home.storyboard` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Home/HomeViewController.swift` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Search/Search.storyboard` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabCatalogFeature/Search/SearchViewController.swift` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabDesignSystem/Cells/PosterCell.swift` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabDesignSystem/Headers/RailHeader.swift` |
| 삭제 | `Packages/StreamLabUI/Sources/StreamLabDesignSystem/StreamLabTheme.swift` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabDesignSystem/Theme/StreamLabTheme.swift` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabProfileFeature/Profile/Profile.storyboard` |
| 추가 | `Packages/StreamLabUI/Sources/StreamLabProfileFeature/Profile/ProfileViewController.swift` |
| 삭제 | `Packages/StreamLabUI/Sources/StreamLabProfileFeature/ProfileSelectionView.swift` |
| 수정 | `README.md` |
| 추가 | `StreamLab.xcodeproj/project.pbxproj` |
| 추가 | `StreamLab.xcodeproj/xcshareddata/xcschemes/StreamLab.xcscheme` |
| 추가 | `Tests/StreamLabUITests/StreamLabUITests.swift` |
| 수정 | `project.yml` |
| 추가 | `scripts/validate-project.py` |
| 추가 | `scripts/verify-mac.sh` |

`Docs/Validation/current/`에는 실제 정적 검사 결과와 실행하지 못한 빌드/테스트 로그를 보관합니다.

GitHub의 이전 통합 UIKit 구현인 App/StreamLabApp.swift, App/Features/StreamLabViewControllers.swift, Resources/Main.storyboard는 새 화면별 구조로 교체합니다.
