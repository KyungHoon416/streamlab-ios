import Testing
import StreamLabDomain

struct SubRipTests {
    @Test func normalizesBOMAndCRLFAndPreservesMultiline() {
        let cues = SubRip.parse("\u{FEFF}1\r\n00:00:01,250 --> 00:00:03,500\r\n한국어\r\nEnglish\r\n")
        #expect(cues.count == 1)
        #expect(cues.first?.start == 1.25)
        #expect(cues.first?.text == "한국어\nEnglish")
    }
    @Test func boundariesAndBackwardSeek() {
        let cues = SubRip.parse("1\n00:00:00,000 --> 00:00:10,000\nA\n\n2\n00:00:10,000 --> 00:00:20,000\nB")
        #expect(SubRip.text(at: 10, in: cues) == "B")
        #expect(SubRip.text(at: 20, in: cues).isEmpty)
        #expect(SubRip.text(at: 2, in: cues) == "A")
        #expect(SubRip.text(at: .nan, in: cues).isEmpty)
    }
    @Test func malformedCuesAreSkipped() {
        let cues = SubRip.parse("1\n00:00:61,000 --> 00:01:02,000\nbad\n\n2\n00:00:02,000 --> 00:00:01,000\nbad\n\n3\n00:00:03,000 --> 00:00:04,000\nvalid")
        #expect(cues.count == 1)
        #expect(cues.first?.text == "valid")
    }
    @Test func overlappingCuesAndGaps() {
        let cues = SubRip.parse("1\n00:00:02,000 --> 00:00:04,000\nB\n\n2\n00:00:01,000 --> 00:00:03,000\nA")
        #expect(SubRip.text(at: 2, in: cues) == "A\nB")
        #expect(SubRip.text(at: 0, in: cues).isEmpty)
        #expect(SubRip.parse("").isEmpty)
    }
}
