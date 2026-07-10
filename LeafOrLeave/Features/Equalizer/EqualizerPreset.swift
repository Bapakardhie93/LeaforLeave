import Foundation

enum EqualizerCompatibility: String, Codable { case available, unavailable, blockedBySite, protectedMedia, failed }
struct EqualizerPreset: Identifiable, Codable, Equatable, Hashable {
    var id: String { name }; let name: String; let gains: [Double]
    static let all = [
        EqualizerPreset(name: "Flat", gains: Array(repeating: 0, count: 10)),
        EqualizerPreset(name: "Bass Booster", gains: [6,5,4,2,0,0,0,0,0,0]),
        EqualizerPreset(name: "Vocal Booster", gains: [-2,-1,0,2,4,5,3,1,0,-1]),
        EqualizerPreset(name: "Rock", gains: [4,3,1,-1,-2,1,3,4,4,3]),
        EqualizerPreset(name: "Late Night", gains: [2,2,1,0,-1,-1,0,1,2,2])]
}
