# Reading Aloud Functionality

This document outlines the requirements for implementing a reading aloud functionality in our application. The feature will allow users to have text content read aloud to the application with the application will estimate how well the user pronounced the words.

## Requirements

### 1. **Text Input**
The application must allow users to input text that they want to be read aloud. This can be done through a text box or by selecting text from existing content within the application.

#### Implementation Details:
**UI Components:**
- Multi-line `TextField` widget with character counter
- Integration with existing Library page stories
- "Use Current Story" button in Reading Aloud page
- **Story Library Integration**: Direct selection from Library page with "Read Aloud" action

**Implementation Steps:**
1. **Create ReadingAloudPage widget** with optional `TextStory` parameter for pre-selected content
2. **Text Input Section**: `TextFormField` with unlimited lines, character counter (max 5000 chars)
3. **Story Library Integration**: 
   - Add "Read Aloud" button to each story card in Library page
   - Navigate to ReadingAloudPage with selected story data
   - Display story title, author, and preview in selection dialog
4. **Content Integration**: Auto-populate text field with selected story content
5. **Text Validation**: Minimum 10 characters, maximum 5000 characters, whitespace trimming

**Story Selection Workflow:**
1. User opens Library page
2. User selects a story and taps "Read Aloud" button
3. App navigates to ReadingAloudPage with story pre-loaded
4. User can modify text if needed before starting practice
5. App remembers last selected story for convenience

### 2. **Speech Synthesis**
The application must utilize a speech synthesis engine to convert the input text into spoken words. This engine should support multiple languages and voices.

#### Implementation Details:
**Dependencies to Add:**
```yaml
dependencies:
  flutter_tts: ^3.8.5  # Text-to-Speech
```

**Implementation Steps:**
1. **TTS Service Class**: Create `TextToSpeechService` with initialization, speak, and stop methods
2. **Language & Voice Support**: Query available languages/voices, store in SharedPreferences
3. **Voice Settings UI**: Dropdowns for language/voice selection, sliders for speed/pitch/volume
4. **Error Handling**: Fallback to default voice if selected voice unavailable

### 3. **Pronunciation Assessment**
The application must include a mechanism to assess the user's pronunciation of the read-aloud text. This could involve recording the user's speech and comparing it to the synthesized speech.

#### Implementation Details:
**AI Integration Strategy:**
- Use existing AI model configuration system. If AI API for some function is not present then use settings for the "default" function.
- Create new function: "pronunciation-assessment"
- Send audio recording + expected text to AI for analysis

**Dependencies to Add:**
```yaml
dependencies:
  flutter_sound: ^9.2.13  # Audio recording/playback
  path_provider: ^2.1.2   # File system access
  flutter_ffmpeg: ^0.4.2  # Audio compression/conversion
```

**Implementation Steps:**
1. **Audio Recording Service**: `AudioRecordingService` class with initialize, start/stop recording methods
2. **Recording Workflow**: Visual recording indicator, save to temporary WAV file
3. **Audio Compression Optimization**:
   - Convert WAV to MP3/OGG format before AI transmission
   - Use `flutter_ffmpeg` for efficient compression
   - Target compression ratio: 10:1 (WAV to MP3)
   - Maintain audio quality for accurate assessment
   - Implement background compression to avoid UI blocking
4. **AI Assessment Integration**: Use `getAIModelConfigForFunction('pronunciation-assessment')` to send compressed audio + text
5. **PronunciationResult Model**: Overall score (0.0-1.0), word-by-word assessments, feedback text

### 4. **Feedback Mechanism**
The application must provide feedback to the user on their pronunciation accuracy. This could be in the form of visual indicators (e.g., green for correct, red for incorrect) or textual feedback.

#### Implementation Details:
**Visual Feedback Components:**
- Circular progress indicator for overall score (0-100%)
- Color coding: Red (<50%), Yellow (50-75%), Green (>75%)
- Word-by-word color coding in text display

**Implementation Steps:**
1. **Feedback UI Widget**: `PronunciationFeedback` widget with overall score, word feedback, detailed panel
2. **Color Coding Logic**: `getAccuracyColor(double accuracy)` function for consistent coloring
3. **Detailed Feedback Panel**: Expandable section with accuracy stats and phoneme suggestions
4. **Accessibility**: High contrast support and screen reader compatibility

### 5. **User Controls**
The application must include controls for the user to play, pause, and stop the reading aloud functionality. Users should also be able to adjust the reading speed and voice settings.

#### Implementation Details:
**Control Panel Components:**
- Playback controls: Play (▶️), Pause (⏸️), Stop (⏹️)
- Recording controls: Record (🔴), Stop Recording
- Settings: Voice/language dropdowns, speed/pitch/volume sliders

**Implementation Steps:**
1. **Control State Management**: `ReadingAloudController` with `PlaybackState` enum and settings
2. **Control Buttons**: Row of `ElevatedButton.icon` widgets with appropriate icons and labels
3. **Settings Panel**: Expandable settings section with all audio configuration options
4. **State Synchronization**: Ensure UI reflects current playback/recording state accurately

### 6. **User Self-Evaluation**
The application must allow users to listen to their own pronunciation recordings and compare them with the synthesized speech.

#### Implementation Details:
**Comparison Interface:**
- Dual playback controls for reference and user recordings
- Waveform visualization (optional advanced feature)
- Side-by-side analysis with phoneme breakdown

**Implementation Steps:**
1. **Audio Playback Service**: `AudioPlaybackService` with separate players for reference and user audio
2. **Comparison UI**: `PronunciationComparison` widget with playback controls and analysis
3. **Playback Methods**: Individual play, simultaneous play with slight delay for comparison
4. **Data Persistence**: Save recordings to app documents directory for future comparison

## Additional Implementation Considerations

### Error Handling:
- Network connectivity checks for AI assessment
- Audio recording permissions (microphone access)
- TTS engine availability and fallback options
- File system access and storage limitations
- Using application work log. Here will be logged important events and errors related to reading aloud functionality, also including:
    - Text messages sent to AI
    - Response messages received from AI
- There is a log viewer in the application settings to review these logs for debugging purposes

### Performance Optimization:
- Lazy loading of audio files
- Background processing for AI assessment
- Memory management for audio data
- **Audio compression**: Convert WAV to MP3/OGG (10:1 compression ratio) to reduce network traffic for AI assessment
- Caching of TTS voice configurations

### Accessibility:
- Screen reader support for all controls
- High contrast mode for feedback colors
- Keyboard navigation support
- Large touch targets for mobile devices

### Data Persistence:
- Save recordings to app documents directory
- Store assessment results in local database
- Export functionality for progress tracking
- Backup and restore capabilities

### Integration with Existing Architecture:
- Leverage existing `AIModelConfig` system for AI assessment
- Use `SharedPreferences` for user settings persistence
- Follow existing UI patterns and theming
- Integrate with current navigation structure

This detailed implementation plan provides a comprehensive roadmap for building the reading aloud functionality, leveraging the existing VT-Polyglot architecture and AI integration system.

