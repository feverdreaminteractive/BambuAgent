# BambuAgent

An AI-powered 3D printing pipeline that generates 3D models from text prompts and sends them to a Bambu A1 mini printer. Features native WiFi connectivity, modern iOS design system, and seamless integration with your Bambu printer.

## Overview

BambuAgent takes a text prompt (e.g., "a small desk organizer with 3 pen holders"), generates OpenSCAD code using Claude AI, compiles it to STL, slices it with OrcaSlicer, and sends the print job directly to your Bambu A1 mini printer over WiFi.

## Architecture

```
iOS App (SwiftUI + Observation) → FastAPI Backend → Bambu A1 mini
                                      ↓
                              Claude API → OpenSCAD → OrcaSlicer
```

## Features

### iOS App
- **Modern SwiftUI Interface**: Built with iOS 17+ and Observation framework
- **Native WiFi Discovery**: Automatic network scanning and Bambu printer detection
- **Bambu Design System**: Custom UI components with Bambu branding and haptic feedback
- **Real-time Status**: Live printer monitoring and job progress tracking
- **Swift Concurrency**: Async/await throughout for smooth performance

### Backend Pipeline
- **AI-Generated 3D Models**: Uses Claude AI to generate OpenSCAD code from natural language
- **Automated Pipeline**: Complete workflow from prompt to print
- **Bambu Integration**: Direct communication with Bambu A1 mini via MQTT/FTP
- **Cross-platform**: Python backend runs on macOS, works with any Bambu printer

## Tech Stack
- **iOS 17+, SwiftUI, Swift Concurrency, Observation framework**
- **Python 3.11+, FastAPI, uvicorn**
- **OpenSCAD** (installed via Homebrew)
- **OrcaSlicer** (installed, has CLI)
- **Bambu A1 mini** on LAN mode

## Project Structure

```
BambuAgent/
├── ios-app/                    # Native iOS application
│   ├── BambuAgent.xcodeproj   # Xcode project
│   └── BambuAgent/
│       ├── Services/          # WiFi, Printer, API managers
│       ├── Views/             # SwiftUI views
│       ├── Models/            # Data models
│       └── DesignSystem/      # UI components & styling
├── backend/                   # Python FastAPI backend
│   ├── app/
│   │   ├── services/         # Core services
│   │   └── main.py           # FastAPI application
│   ├── scripts/              # Utility scripts
│   └── tests/                # Test files
└── README.md
```

## Setup Instructions

### Prerequisites

1. **Xcode 15+** with iOS 17+ SDK
2. **OpenSCAD**: Install from [openscad.org](https://openscad.org) or via Homebrew:
   ```bash
   brew install openscad
   ```
3. **OrcaSlicer**: Download from [github.com/SoftFever/OrcaSlicer](https://github.com/SoftFever/OrcaSlicer/releases)
4. **Bambu A1 mini**:
   - Set to LAN mode (not cloud mode)
   - Note the printer's IP address
   - Get access code from printer LCD menu
5. **Claude API Key**: Get from [console.anthropic.com](https://console.anthropic.com)

### Backend Setup

1. **Navigate to backend**:
   ```bash
   cd BambuAgent/backend
   ```

2. **Create virtual environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On macOS/Linux
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**:
   ```bash
   # Copy example config
   cp .env.example .env

   # Edit .env with your values
   ANTHROPIC_API_KEY=your_claude_api_key_here
   BAMBU_PRINTER_IP=192.168.1.100  # Your printer's IP
   BAMBU_ACCESS_CODE=12345678      # From printer LCD menu
   BAMBU_DEVICE_SERIAL=your_printer_serial
   ```

5. **Start the backend**:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

The API will be available at `http://localhost:8000` with interactive docs at `http://localhost:8000/docs`.

### iOS App Setup

1. **Open Xcode project**:
   ```bash
   open ios-app/BambuAgent.xcodeproj
   ```

2. **Configure backend URL**:
   - Open `APIService.swift`
   - Update `serverURL` to point to your Mac's IP address (e.g., `http://192.168.1.50:8000`)

3. **Build and run** on device or simulator

## Key Features

### WiFi & Network Discovery
- **Automatic Network Scanning**: Discovers available WiFi networks
- **Bambu Printer Detection**: Uses Bonjour/mDNS to find Bambu printers on network
- **Signal Strength Monitoring**: Visual indicators for connection quality
- **Seamless Connection**: Guides through WiFi setup if needed

### Native iOS Design System
- **Bambu Color Palette**: Brand-consistent green, blue, and orange accents
- **Custom Components**: StatusIndicator, ProgressRing, WiFiSignalIndicator
- **Haptic Feedback**: Responsive tactile feedback throughout the app
- **Adaptive Interface**: Works on iPhone and iPad with proper scaling

### Modern Swift Architecture
- **Observation Framework**: Eliminates @Published and @ObservedObject boilerplate
- **Swift Concurrency**: Async/await for all network operations
- **Environment Values**: Clean dependency injection with @Environment
- **Structured Concurrency**: Proper task management and cancellation

## API Endpoints

### Core Pipeline
- `POST /generate` - Generate OpenSCAD code from text prompt
- `POST /compile` - Compile OpenSCAD to STL
- `POST /slice` - Slice STL to 3MF with OrcaSlicer
- `POST /print` - Send 3MF to printer
- `POST /pipeline/full` - Complete pipeline in one call

### Printer Control
- `GET /printer/status` - Get current printer status
- `GET /printer/jobs` - List recent print jobs

## Usage Examples

### 1. Generate a Model (iOS App)
1. Tap "Generate Model" on home screen
2. Enter prompt: "a simple phone stand with 45 degree angle"
3. Wait for AI generation
4. Review generated model and tap "Print"

### 2. API Usage (Direct)
```bash
# Generate model
curl -X POST "http://localhost:8000/generate" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a desktop pen holder with 4 compartments"}'

# Full pipeline
curl -X POST "http://localhost:8000/pipeline/full" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a minimalist phone stand"}'
```

### 3. Check Status
```bash
curl "http://localhost:8000/printer/status"
```

## Testing

Run the comprehensive test script:
```bash
cd backend
python scripts/test_pipeline.py
```

Test specific components:
```bash
python scripts/test_pipeline.py --step generate
python scripts/test_pipeline.py --step printer
```

## Troubleshooting

### iOS App Issues
- **"No printers found"**: Ensure Bambu printer is on same WiFi network and in LAN mode
- **"Backend not connected"**: Check serverURL in APIService.swift points to correct IP
- **Build errors**: Ensure iOS 17+ deployment target and Xcode 15+

### Backend Issues
- **OpenSCAD not found**: Verify installation with `which openscad`
- **OrcaSlicer issues**: Check installation path in `slicer_service.py`
- **Printer connection fails**: Verify IP address and access code in .env file

### Network Issues
- **WiFi discovery empty**: iOS privacy restrictions limit network scanning
- **Printer not detected**: Ensure printer is in LAN mode, not cloud mode
- **Connection timeouts**: Check firewall settings and network configuration

## Development

### Adding New Features
1. **iOS**: Add views in `Views/`, services in `Services/`, update models in `Models/`
2. **Backend**: Add endpoints in `main.py`, services in `services/`
3. **Design System**: Extend components in `DesignSystem/DesignSystem.swift`

### Git Workflow
```bash
git add .
git commit -m "feat: add new feature"
git push origin main
```

## Limitations

- **iOS Network Access**: Limited WiFi scanning due to iOS privacy restrictions
- **Printer Discovery**: Requires Bambu printers to be in LAN mode
- **Model Complexity**: AI-generated models limited by OpenSCAD capabilities
- **Print Success**: Depends on model printability and printer settings

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For issues:
1. Check the troubleshooting section above
2. Run `backend/scripts/test_pipeline.py` to isolate problems
3. Check iOS app logs in Xcode console
4. Open an issue with full error details and device information

---

**BambuAgent** - Making 3D printing as easy as describing what you want. From idea to physical object in minutes, not hours.