import Foundation

/// Generic, spreadsheet-safe CSV writer (RFC 4180-ish): quotes any field
/// containing a comma, a double quote, or a newline; doubles embedded quotes;
/// CRLF line endings (Numbers/Excel expect these on export). Pure string
/// formatting — no knowledge of `ExportDay` or any app model lives here.
public enum CSVBuilder {
    /// Quotes `field` only when required, doubling any interior `"`.
    public static func escapeField(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// One CSV line (no trailing line ending) from already-stringified fields.
    public static func row(_ fields: [String]) -> String {
        fields.map(escapeField).joined(separator: ",")
    }

    /// Full document: header row + data rows, CRLF-terminated, trailing CRLF
    /// after the last row (standard, and what most spreadsheet apps expect).
    public static func build(header: [String], rows: [[String]]) -> String {
        var lines = [row(header)]
        lines.append(contentsOf: rows.map(row))
        return lines.map { $0 + "\r\n" }.joined()
    }
}
