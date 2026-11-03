import Testing
import StreamLabDomain

@Test func memoryRunCountsPlayedClosesAndRequiresFourDistinctSamples() {
    var run = PlaybackMemoryRun(baseline: 10)
    run.close(played: false)
    run.sample(999)
    #expect(run.closed == 0 && run.checkpoints.isEmpty)
    for boundary in [5, 10, 15, 20] {
        for _ in 0..<5 { run.close(played: true) }
        #expect(run.awaitingSample && !run.finished)
        run.close(played: true)
        #expect(run.closed == boundary)
        run.sample(UInt64(boundary))
        run.sample(999)
    }
    run.close(played: true)
    #expect(run.finished && run.closed == 20 && run.checkpoints == [5, 10, 15, 20])
}
