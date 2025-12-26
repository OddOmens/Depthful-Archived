# Depthful

**Note: This project is archived and no longer actively maintained. It is provided as-is for educational purposes and community use.**

Depthful is a thoughtful journaling app designed to help you capture, organize, and reflect on your thoughts, ideas, and experiences. Built with SwiftUI and Core Data, it features support for text, voice recordings, photos, and rich markdown formatting.

## Features

- **Thought Management**: Create, edit, and organize thoughts with tags and search.
- **Rich Text**: Full Markdown support including bold, italic, lists, and code blocks.
- **Voice Recordings**: Record audio notes with real-time waveform visualization and automatic transcription.
- **Photos**: Attach images to your entries.
- **Analytics**: Track your writing streaks, word counts, and most used tags.
- **Customization**: Dark mode support, custom app icons, and theme options.
- **Local First**: All data is stored locally on device using Core Data.

## Requirements

- iOS 17.4+
- Xcode 15.0+
- Swift 5.0+

## Getting Started

1. Clone the repository.
2. Open `Depthful.xcodeproj` in Xcode.
3. Wait for packages to resolve.
4. Select your target simulator or device.
5. Build and Run (`Cmd + R`).

## Architecture

The app is built using modern SwiftUI practices:
- **Core Data**: For local persistence of thoughts, tags, and recordings.
- **SwiftUI**: For all UI components.
- **AVFoundation**: For voice recording and playback.
- **Speech**: For voice-to-text transcription.

## Privacy

Depthful was designed with privacy in mind. All data is stored locally on the user's device. No data is collected or transmitted to external servers.

## Disclaimer

This software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose and noninfringement. In no event shall the authors or copyright holders be liable for any claim, damages or other liability, whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.
