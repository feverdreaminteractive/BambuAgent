from fastapi import FastAPI, HTTPException, BackgroundTasks, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
import os
import logging
from typing import Dict, Any, Optional
import asyncio
from pathlib import Path

# Load environment variables
try:
    from dotenv import load_dotenv
    env_file = Path(__file__).parent.parent / f".env.{os.getenv('ENVIRONMENT', 'development')}"
    if env_file.exists():
        load_dotenv(env_file)
    else:
        # Fallback to .env
        load_dotenv(Path(__file__).parent.parent / ".env")
except ImportError:
    pass

from .services.claude_service import ClaudeService
from .services.openscad_service import OpenSCADService
from .services.slicer_service import SlicerService
from .services.bambu_service import BambuService

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="BambuAgent API",
    description="AI-powered 3D printing pipeline for Bambu A1 mini",
    version="1.0.0"
)

# CORS middleware for iOS app and web interface
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, restrict to your iOS app and domain
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files and templates
web_dir = Path(__file__).parent.parent.parent / "web"
templates = None

if web_dir.exists() and (web_dir / "static").exists():
    app.mount("/static", StaticFiles(directory=str(web_dir / "static")), name="static")

if web_dir.exists() and (web_dir / "templates").exists():
    templates = Jinja2Templates(directory=str(web_dir / "templates"))

# Initialize services
claude_service = ClaudeService()
openscad_service = OpenSCADService()
slicer_service = SlicerService()
bambu_service = BambuService()

# Request/Response models
class GenerateRequest(BaseModel):
    prompt: str
    user_id: Optional[str] = "default"

class CompileRequest(BaseModel):
    openscad_code: str
    filename: Optional[str] = "model"

class SliceRequest(BaseModel):
    stl_path: str
    filename: Optional[str] = "model"
    layer_height: Optional[float] = 0.2
    infill: Optional[float] = 15.0

class PrintRequest(BaseModel):
    file_path: str
    print_name: Optional[str] = "BambuAgent Print"

class GenerateResponse(BaseModel):
    openscad_code: str
    explanation: str
    estimated_print_time: Optional[str] = None

class CompileResponse(BaseModel):
    stl_path: str
    success: bool
    error_message: Optional[str] = None

class SliceResponse(BaseModel):
    gcode_path: str
    success: bool
    estimated_print_time: Optional[str] = None
    filament_used: Optional[str] = None
    error_message: Optional[str] = None

class PrintResponse(BaseModel):
    job_id: str
    status: str
    message: str

class PrinterStatusResponse(BaseModel):
    status: str
    current_job: Optional[Dict[str, Any]] = None
    bed_temperature: Optional[float] = None
    nozzle_temperature: Optional[float] = None
    progress: Optional[float] = None

@app.get("/")
async def root(request: Request):
    """Serve the web interface or API response"""
    if templates:
        return templates.TemplateResponse("index.html", {"request": request})
    else:
        # Fallback API response if web interface not available
        return {"message": "BambuAgent API is running", "status": "healthy"}

@app.get("/api")
async def api_root():
    """API health check endpoint"""
    return {"message": "BambuAgent API is running", "status": "healthy"}

@app.post("/generate", response_model=GenerateResponse)
async def generate_model(request: GenerateRequest):
    """
    Generate OpenSCAD code from a text prompt using Claude API
    """
    try:
        logger.info(f"Generating model for prompt: {request.prompt}")

        result = await claude_service.generate_openscad(request.prompt)

        return GenerateResponse(
            openscad_code=result["code"],
            explanation=result["explanation"],
            estimated_print_time=result.get("estimated_print_time")
        )

    except Exception as e:
        logger.error(f"Error generating model: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to generate model: {str(e)}")

@app.post("/compile", response_model=CompileResponse)
async def compile_model(request: CompileRequest):
    """
    Compile OpenSCAD code to STL using OpenSCAD CLI
    """
    try:
        logger.info(f"Compiling OpenSCAD code for: {request.filename}")

        stl_path = await openscad_service.compile_to_stl(
            request.openscad_code,
            request.filename
        )

        return CompileResponse(
            stl_path=stl_path,
            success=True
        )

    except Exception as e:
        logger.error(f"Error compiling model: {str(e)}")
        return CompileResponse(
            stl_path="",
            success=False,
            error_message=str(e)
        )

@app.post("/slice", response_model=SliceResponse)
async def slice_model(request: SliceRequest):
    """
    Slice STL file to G-code using OrcaSlicer CLI
    """
    try:
        logger.info(f"Slicing STL: {request.stl_path}")

        result = await slicer_service.slice_to_gcode(
            request.stl_path,
            request.filename,
            layer_height=request.layer_height,
            infill=request.infill
        )

        return SliceResponse(
            gcode_path=result["gcode_path"],
            success=True,
            estimated_print_time=result.get("print_time"),
            filament_used=result.get("filament_used")
        )

    except Exception as e:
        logger.error(f"Error slicing model: {str(e)}")
        return SliceResponse(
            gcode_path="",
            success=False,
            error_message=str(e)
        )

@app.post("/print", response_model=PrintResponse)
async def send_to_printer(request: PrintRequest, background_tasks: BackgroundTasks):
    """
    Send 3MF/G-code file to Bambu printer via MQTT/FTP
    """
    try:
        logger.info(f"Sending to printer: {request.file_path}")

        job_id = await bambu_service.send_print_job(
            request.file_path,
            request.print_name
        )

        return PrintResponse(
            job_id=job_id,
            status="queued",
            message="Print job sent to Bambu A1 mini"
        )

    except Exception as e:
        logger.error(f"Error sending to printer: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to send to printer: {str(e)}")

@app.get("/printer/status", response_model=PrinterStatusResponse)
async def get_printer_status():
    """
    Get current printer status via MQTT
    """
    try:
        logger.info("Getting printer status")

        status = await bambu_service.get_printer_status()

        return PrinterStatusResponse(
            status=status["status"],
            current_job=status.get("current_job"),
            bed_temperature=status.get("bed_temp"),
            nozzle_temperature=status.get("nozzle_temp"),
            progress=status.get("progress")
        )

    except Exception as e:
        logger.error(f"Error getting printer status: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to get printer status: {str(e)}")

@app.get("/printer/jobs")
async def list_printer_jobs():
    """
    List recent print jobs
    """
    try:
        jobs = await bambu_service.list_recent_jobs()
        return {"jobs": jobs}

    except Exception as e:
        logger.error(f"Error listing jobs: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to list jobs: {str(e)}")

@app.post("/pipeline/full")
async def full_pipeline(request: GenerateRequest, background_tasks: BackgroundTasks):
    """
    Complete pipeline: prompt → OpenSCAD → STL → G-code → print
    """
    try:
        logger.info(f"Starting full pipeline for: {request.prompt}")

        # Generate OpenSCAD code
        generate_result = await claude_service.generate_openscad(request.prompt)

        # Compile to STL
        stl_path = await openscad_service.compile_to_stl(
            generate_result["code"],
            "pipeline_model"
        )

        # Slice to G-code
        slice_result = await slicer_service.slice_to_gcode(
            stl_path,
            "pipeline_model"
        )

        # Send to printer
        job_id = await bambu_service.send_print_job(
            slice_result["gcode_path"],
            f"AI Generated: {request.prompt[:50]}"
        )

        return {
            "job_id": job_id,
            "message": "Full pipeline completed successfully",
            "openscad_code": generate_result["code"],
            "stl_path": stl_path,
            "gcode_path": slice_result["gcode_path"],
            "estimated_print_time": slice_result.get("print_time")
        }

    except Exception as e:
        logger.error(f"Error in full pipeline: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Pipeline failed: {str(e)}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)