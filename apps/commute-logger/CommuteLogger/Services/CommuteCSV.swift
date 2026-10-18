import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// All trips as a CSV file for the share sheet. Rendered lazily, only when the user actually shares.
struct CommuteCSV: Transferable {
    var samples: [CommuteSample]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { csv in
            Data(csv.render().utf8)
        }
        .suggestedFileName("Commutes.csv")
    }

    func render() -> String {
        let iso = ISO8601DateFormatter()
        iso.timeZone = .current
        var lines = ["direction,departure,arrival,duration_min,distance_km,stopped_min,maps_estimate_min,mode,delay_causes"]
        for s in samples.sorted(by: { $0.departure < $1.departure }) {
            let fields = [
                s.direction.rawValue,
                iso.string(from: s.departure),
                iso.string(from: s.arrival),
                String(format: "%.1f", s.duration / 60),
                s.distanceMeters > 0 ? String(format: "%.2f", s.distanceMeters / 1000) : "",
                s.distanceMeters > 0 ? String(format: "%.1f", s.stationarySeconds / 60) : "",
                s.predictedSeconds.map { String(format: "%.1f", $0 / 60) } ?? "",
                s.mode.rawValue,
                s.causes.map(\.rawValue).joined(separator: ";"),
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
