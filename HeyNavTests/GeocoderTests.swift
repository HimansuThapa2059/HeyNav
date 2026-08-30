import Foundation
import Testing
@testable import HeyNav

/// Decoding is checked against real Open-Meteo response bodies rather than a live call,
/// so the suite stays hermetic.
struct GeocoderTests {
    @Test func decodesASearchResult() throws {
        let json = """
        {"results":[{"id":1282898,"name":"Pokhara","latitude":28.26689,"longitude":83.96851,
        "elevation":1008.0,"feature_code":"PPLA","country_code":"NP","timezone":"Asia/Kathmandu",
        "population":600051,"country":"Nepal","admin1":"Gandaki Pradesh","admin2":"Kaski"}],
        "generationtime_ms":0.7}
        """
        let places = try Geocoder.decode(Data(json.utf8))
        #expect(places.count == 1)
        #expect(places[0].name == "Pokhara")
        #expect(places[0].latitude == 28.26689)
        #expect(places[0].subtitle == "Gandaki Pradesh, Nepal")
    }

    /// Open-Meteo omits `results` entirely instead of sending an empty array, which a
    /// non-optional property would decode as an error rather than "no matches".
    @Test func treatsAMissingResultsKeyAsNoMatches() throws {
        let places = try Geocoder.decode(Data(#"{"generationtime_ms":0.99}"#.utf8))
        #expect(places.isEmpty)
    }

    @Test func toleratesMissingOptionalFields() throws {
        let json = #"{"results":[{"id":1,"name":"Nowhere","latitude":0.0,"longitude":0.0}]}"#
        let places = try Geocoder.decode(Data(json.utf8))
        #expect(places[0].subtitle == "")
    }

    @Test func malformedJsonThrows() {
        #expect(throws: (any Error).self) {
            try Geocoder.decode(Data("not json".utf8))
        }
    }
}
