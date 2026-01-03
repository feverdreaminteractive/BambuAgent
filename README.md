# BambuAgent

An AI-powered 3D printing pipeline that generates 3D models from text prompts and sends them to a Bambu A1 mini printer.

## Overview

BambuAgent takes a text prompt (e.g., "a small desk organizer with 3 pen holders"), generates OpenSCAD code using Claude AI, compiles it to STL, slices it with OrcaSlicer, and sends the print job directly to your Bambu A1 mini printer.

## Architecture

```
iOS App (SwiftUI) → FastAPI Backend → Bambu A1 mini
                         ↓
                  Claude API → OpenSCAD → OrcaSlicer
```

## Features

- **AI-Generated 3D Models**: Uses Claude AI to generate OpenSCAD code from natural language
- **Automated Pipeline**: Complete workflow from prompt to print
- **Bambu Integration**: Direct communication with Bambu A1 mini via MQTT/FTP
- **Real-time Status**: Monitor printer status and job progress
- **iOS App**: Native SwiftUI interface for mobile control

## Project Structure

```
BambuAgent/
├── ios-app/           # SwiftUI iOS application
├── backend/           # Python FastAPI backend
│   ├── app/
│   │   ├── services/  # Core services
│   │   └── main.py    # FastAPI application
│   ├── tests/         # Test files
│   └── scripts/       # Utility scripts
└── README.md
```

## Setup Instructions

### Prerequisites

1. **OpenSCAD**: Install from [openscad.org](https://openscad.org) or via Homebrew:
   ```bash
   brew install openscad
   ```

2. **OrcaSlicer**: Download from [github.com/SoftFever/OrcaSlicer](https://github.com/SoftFever/OrcaSlicer/releases)

3. **Bambu A1 mini**:
   - Set to LAN mode (not cloud mode)
   - Note the printer's IP address
   - Get access code from printer LCD menu

4. **Claude API Key**: Get from [console.anthropic.com](https://console.anthropic.com)

### Backend Setup

1. **Clone and navigate to backend**:
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
   # Create .env file
   cat > .env << EOF
   ANTHROPIC_API_KEY=your_claude_api_key_here
   BAMBU_PRINTER_IP=192.168.1.100  # Your printer's IP
   BAMBU_ACCESS_CODE=12345678      # From printer LCD menu
   BAMBU_DEVICE_SERIAL=your_printer_serial
   EOF
   ```

5. **Start the backend**:
   ```bash
   uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```

The API will be available at `http://localhost:8000` with interactive docs at `http://localhost:8000/docs`.

### iOS App Setup

1. **Open Xcode**:
   ```bash
   open ios-app/BambuAgent.xcodeproj  # When created
   ```

2. **Configure backend URL** in the iOS app to point to your Mac's IP address.

## API Endpoints

### Core Pipeline
- `POST /generate` - Generate OpenSCAD code from text prompt
- `POST /compile` - Compile OpenSCAD to STL
- `POST /slice` - Slice STL to 3MF with OrcaSlicer
- `POST /print` - Send 3MF to printer

### Printer Control
- `GET /printer/status` - Get current printer status
- `GET /printer/jobs` - List recent print jobs

### Convenience
- `POST /pipeline/full` - Complete pipeline in one call
- `GET /` - Health check

## Example Usage

### 1. Generate a Model
```bash
curl -X POST "http://localhost:8000/generate" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a small phone stand with cable management"}'
```

### 2. Full Pipeline
```bash
curl -X POST "http://localhost:8000/pipeline/full" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "a desktop pen holder with 4 compartments"}'
```

### 3. Check Printer Status
```bash
curl "http://localhost:8000/printer/status"
```

## Testing

Run the test script to validate your setup:

```bash
python scripts/test_pipeline.py
```

This will test each component:
- Claude API connection
- OpenSCAD compilation
- OrcaSlicer integration
- Bambu printer communication

## Troubleshooting

### OpenSCAD Issues
- Ensure OpenSCAD is installed and in PATH
- Check `/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD` exists

### OrcaSlicer Issues
- Verify OrcaSlicer installation path
- Ensure CLI tools are accessible

### Bambu Printer Issues
- Confirm printer is in LAN mode
- Check IP address and access code
- Ensure printer is on same network as your Mac
- Verify MQTT port 8883 is accessible

### Claude API Issues
- Verify API key is correct
- Check API rate limits
- Ensure internet connection

## Development

### Adding New Features
1. Add service methods in `backend/app/services/`
2. Add API endpoints in `backend/app/main.py`
3. Update iOS app to use new endpoints

### Testing
```bash
# Run backend tests
pytest backend/tests/

# Run specific test
python scripts/test_pipeline.py --step generate
```

## Limitations

- Requires local network access to Bambu printer
- OpenSCAD models are limited by AI generation capabilities
- Print success depends on model complexity and printer settings
- Currently supports Bambu A1 mini only

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes and test thoroughly
4. Submit a pull request

## License

MIT License - see LICENSE file for details

## Support

For issues:
1. Check the troubleshooting section
2. Run the test script to isolate problems
3. Check logs in the FastAPI backend
4. Open an issue with full error details

---

**Note**: This project is for educational and personal use. Ensure your 3D prints are safe and appropriate for your printer's capabilities.