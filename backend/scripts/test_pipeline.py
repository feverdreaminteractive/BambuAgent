#!/usr/bin/env python3
"""
BambuAgent Pipeline Test Script

Tests each component of the 3D printing pipeline:
1. Claude API connection
2. OpenSCAD compilation
3. OrcaSlicer integration
4. Bambu printer communication

Usage:
    python test_pipeline.py [--step STEP] [--prompt "custom prompt"]

Examples:
    python test_pipeline.py                    # Test all steps
    python test_pipeline.py --step generate    # Test only Claude generation
    python test_pipeline.py --step compile     # Test only OpenSCAD compilation
"""

import asyncio
import argparse
import sys
import os
from pathlib import Path

# Add the app directory to Python path
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.services.claude_service import ClaudeService
from app.services.openscad_service import OpenSCADService
from app.services.slicer_service import SlicerService
from app.services.bambu_service import BambuService

# Test configuration
TEST_PROMPT = "a simple rectangular phone stand with a 45 degree angle"

class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'

def print_status(message: str, status: str = "info"):
    colors = {
        "success": Colors.GREEN,
        "error": Colors.RED,
        "warning": Colors.YELLOW,
        "info": Colors.BLUE
    }
    color = colors.get(status, Colors.END)
    print(f"{color}[{status.upper()}]{Colors.END} {message}")

async def test_claude_service(prompt: str = TEST_PROMPT):
    """Test Claude API integration"""
    print_status("Testing Claude API service...", "info")

    try:
        claude = ClaudeService()

        # Check if API key is configured
        if not claude.api_key:
            print_status("No ANTHROPIC_API_KEY found - will use fallback", "warning")

        result = await claude.generate_openscad(prompt)

        print_status("Claude generation successful!", "success")
        print(f"Generated code length: {len(result['code'])} characters")
        print(f"Explanation: {result['explanation'][:100]}...")

        return result

    except Exception as e:
        print_status(f"Claude service failed: {str(e)}", "error")
        return None

def test_openscad_service(openscad_code: str = None):
    """Test OpenSCAD compilation"""
    print_status("Testing OpenSCAD service...", "info")

    try:
        openscad = OpenSCADService()

        # Check installation
        info = openscad.get_openscad_info()
        if not info["installed"]:
            print_status("OpenSCAD not found - please install OpenSCAD", "error")
            return None

        print_status(f"OpenSCAD found at: {info['path']}", "success")
        print(f"Version: {info.get('version', 'Unknown')}")

        # Use provided code or fallback
        if not openscad_code:
            openscad_code = """
// Test cube
cube([20, 20, 20], center=true);
"""

        # Test syntax validation
        if openscad.validate_openscad_syntax(openscad_code):
            print_status("OpenSCAD syntax validation passed", "success")
        else:
            print_status("OpenSCAD syntax validation failed", "warning")

        return {"openscad_service": openscad, "code": openscad_code}

    except Exception as e:
        print_status(f"OpenSCAD service failed: {str(e)}", "error")
        return None

async def test_slicer_service():
    """Test OrcaSlicer integration"""
    print_status("Testing OrcaSlicer service...", "info")

    try:
        slicer = SlicerService()

        # Check installation
        info = slicer.get_slicer_info()
        if not info["installed"]:
            print_status("OrcaSlicer not found - will use fallback", "warning")
        else:
            print_status(f"OrcaSlicer found at: {info['path']}", "success")
            print(f"Version: {info.get('version', 'Unknown')}")

        return slicer

    except Exception as e:
        print_status(f"Slicer service failed: {str(e)}", "error")
        return None

async def test_bambu_service():
    """Test Bambu printer connection"""
    print_status("Testing Bambu printer service...", "info")

    try:
        bambu = BambuService()

        # Check configuration
        info = bambu.get_connection_info()
        print(f"Printer IP: {info['printer_ip'] or 'Not configured'}")
        print(f"Access code configured: {info['access_code_configured']}")

        if not info['printer_ip'] or not info['access_code_configured']:
            print_status("Bambu printer not configured - check environment variables", "warning")
            return bambu

        # Test connection
        connected = await bambu.connect_mqtt()
        if connected:
            print_status("Bambu MQTT connection successful!", "success")

            # Test status
            status = await bambu.get_printer_status()
            print(f"Printer status: {status.get('status', 'unknown')}")

        else:
            print_status("Bambu MQTT connection failed", "error")

        return bambu

    except Exception as e:
        print_status(f"Bambu service failed: {str(e)}", "error")
        return None

async def test_full_pipeline(prompt: str = TEST_PROMPT):
    """Test the complete pipeline"""
    print_status("Testing complete pipeline...", "info")

    try:
        # Step 1: Generate OpenSCAD code
        print_status("Step 1: Generating OpenSCAD code...", "info")
        claude_result = await test_claude_service(prompt)
        if not claude_result:
            print_status("Pipeline failed at generation step", "error")
            return False

        # Step 2: Compile to STL
        print_status("Step 2: Compiling to STL...", "info")
        openscad_result = test_openscad_service(claude_result["code"])
        if not openscad_result:
            print_status("Pipeline failed at compilation step", "error")
            return False

        openscad_service = openscad_result["openscad_service"]
        stl_path = await openscad_service.compile_to_stl(
            openscad_result["code"],
            "test_model"
        )
        print_status(f"STL compiled successfully: {stl_path}", "success")

        # Step 3: Slice to G-code
        print_status("Step 3: Slicing to G-code...", "info")
        slicer = await test_slicer_service()
        if not slicer:
            print_status("Pipeline failed at slicing step", "error")
            return False

        slice_result = await slicer.slice_to_gcode(stl_path, "test_model")
        print_status(f"Slicing completed: {slice_result['gcode_path']}", "success")

        # Step 4: Test printer connection
        print_status("Step 4: Testing printer connection...", "info")
        bambu = await test_bambu_service()
        if not bambu:
            print_status("Pipeline failed at printer connection step", "error")
            return False

        print_status("Full pipeline test completed successfully!", "success")
        return True

    except Exception as e:
        print_status(f"Full pipeline test failed: {str(e)}", "error")
        return False

async def main():
    parser = argparse.ArgumentParser(description="Test BambuAgent pipeline components")
    parser.add_argument("--step", choices=["generate", "compile", "slice", "printer", "full"],
                      default="full", help="Which step to test")
    parser.add_argument("--prompt", default=TEST_PROMPT,
                      help="Custom prompt for testing generation")

    args = parser.parse_args()

    print_status("BambuAgent Pipeline Test", "info")
    print(f"Testing step: {args.step}")
    print("-" * 50)

    if args.step == "generate":
        await test_claude_service(args.prompt)
    elif args.step == "compile":
        test_openscad_service()
    elif args.step == "slice":
        await test_slicer_service()
    elif args.step == "printer":
        await test_bambu_service()
    elif args.step == "full":
        await test_full_pipeline(args.prompt)

    print("-" * 50)
    print_status("Test completed", "info")

if __name__ == "__main__":
    # Load environment variables if .env exists
    env_path = Path(__file__).parent.parent / ".env"
    if env_path.exists():
        from dotenv import load_dotenv
        load_dotenv(env_path)

    asyncio.run(main())