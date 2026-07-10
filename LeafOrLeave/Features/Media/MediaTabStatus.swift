import Foundation

enum MediaPlaybackState: String, Codable { case none, paused, playingAudio, playingVideo, pictureInPicture }
struct MediaTabStatus: Equatable { var playbackState: MediaPlaybackState = .none; var isMuted = false; var title: String?; var artist: String?; var artworkURL: URL?; var duration: TimeInterval?; var currentTime: TimeInterval? }
