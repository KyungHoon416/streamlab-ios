import Testing
import StreamLabDesignSystem

struct HomeRenderExperimentTests {
    @Test func independentFactorsAndSafeDefault() {
        let expected: [(String, Bool, Bool)] = [("C", false, false), ("P", true, false),
                                               ("V", false, true), ("PV", true, true)]
        for (mode, poster, split) in expected {
            let selection = HomeRenderExperiment.resolve(arguments: ["StreamLab", "--home-render-experiment=\(mode)"])
            #expect(selection.rawValue == mode)
            #expect(selection.singleLayerPoster == poster)
            #expect(selection.splitHome == split)
        }
        #expect(HomeRenderExperiment.resolve(arguments: []) == .combined)
        #expect(HomeRenderExperiment.resolve(arguments: ["--home-render-experiment=typo"]) == .combined)
        #expect(HomeRenderExperiment.resolve(arguments: ["--home-render-experiment=P", "--home-render-experiment=V"]) == .split)
    }
}
