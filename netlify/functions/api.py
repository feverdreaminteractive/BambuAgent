"""
Netlify Function to run BambuAgent FastAPI backend
"""
import sys
import os

# Add the backend directory to the path
backend_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'backend')
sys.path.append(backend_dir)

from mangum import Mangum
from backend.app.main import app

# Create the Netlify-compatible handler
handler = Mangum(app, lifespan="off")