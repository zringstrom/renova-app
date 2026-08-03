import Testing
@testable import RecoveryKit

@Suite("CSVBuilder")
struct CSVBuilderTests {
    @Test func plainFieldUnquoted() {
        #expect(CSVBuilder.escapeField("plain") == "plain")
    }

    @Test func emptyFieldUnquoted() {
        #expect(CSVBuilder.escapeField("") == "")
    }

    @Test func fieldWithCommaIsQuoted() {
        #expect(CSVBuilder.escapeField("a,b") == "\"a,b\"")
    }

    @Test func fieldWithQuoteIsQuotedAndDoubled() {
        #expect(CSVBuilder.escapeField("say \"hi\"") == "\"say \"\"hi\"\"\"")
    }

    @Test func fieldWithNewlineIsQuoted() {
        #expect(CSVBuilder.escapeField("line1\nline2") == "\"line1\nline2\"")
    }

    @Test func fieldWithCommaAndQuoteRoundTrips() {
        let raw = "Great, but \"tight\" hips"
        let escaped = CSVBuilder.escapeField(raw)
        #expect(escaped == "\"Great, but \"\"tight\"\" hips\"")
        // Round trip: a naive CSV-unquote (strip outer quotes, undouble inner) recovers the original.
        var unquoted = escaped
        if unquoted.hasPrefix("\""), unquoted.hasSuffix("\"") {
            unquoted.removeFirst()
            unquoted.removeLast()
            unquoted = unquoted.replacingOccurrences(of: "\"\"", with: "\"")
        }
        #expect(unquoted == raw)
    }

    @Test func unicodeFieldPassesThroughUnquoted() {
        #expect(CSVBuilder.escapeField("café — 日本語 🏃") == "café — 日本語 🏃")
    }

    @Test func rowJoinsWithCommas() {
        #expect(CSVBuilder.row(["a", "b,c", "d"]) == "a,\"b,c\",d")
    }

    @Test func buildProducesHeaderAndCRLFLines() {
        let csv = CSVBuilder.build(header: ["a", "b"], rows: [["1", "2"], ["3", "4"]])
        #expect(csv == "a,b\r\n1,2\r\n3,4\r\n")
    }

    @Test func buildHandlesEmptyFields() {
        let csv = CSVBuilder.build(header: ["a", "b"], rows: [["", "x"]])
        #expect(csv == "a,b\r\n,x\r\n")
    }

    @Test func buildWithEmbeddedCommaQuoteAndNewline() {
        let csv = CSVBuilder.build(header: ["note"], rows: [["Hi, \"friend\"\nbye"]])
        #expect(csv == "note\r\n\"Hi, \"\"friend\"\"\nbye\"\r\n")
    }
}
