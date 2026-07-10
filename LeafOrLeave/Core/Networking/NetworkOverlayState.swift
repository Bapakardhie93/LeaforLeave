import Foundation

enum NetworkOverlayState: Equatable { case hidden, offline(since: Date), validating, recovered }
