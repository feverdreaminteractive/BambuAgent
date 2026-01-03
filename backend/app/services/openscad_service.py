import os
import asyncio
import subprocess
import tempfile
from typing import Optional
import logging

logger = logging.getLogger(__name__)

class OpenSCADService:
    def __init__(self):
        # Common OpenSCAD installation paths on macOS
        self.openscad_paths = [
            "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD",
            "/usr/local/bin/openscad",
            "/opt/homebrew/bin/openscad"
        ]
        self.openscad_cmd = self._find_openscad()

    def _find_openscad(self) -> Optional[str]:
        """Find OpenSCAD executable"""
        for path in self.openscad_paths:
            if os.path.exists(path):
                logger.info(f"Found OpenSCAD at: {path}")
                return path

        # Try to find in PATH
        try:
            result = subprocess.run(["which", "openscad"], capture_output=True, text=True)
            if result.returncode == 0:
                path = result.stdout.strip()
                logger.info(f"Found OpenSCAD in PATH: {path}")
                return path
        except Exception:
            pass

        logger.warning("OpenSCAD not found. Please install OpenSCAD.")
        return None

    async def compile_to_stl(self, openscad_code: str, filename: str = "model") -> str:
        """
        Compile OpenSCAD code to STL file
        """
        if not self.openscad_cmd:
            raise Exception("OpenSCAD not found. Please install OpenSCAD.")

        # Create temp directory for this compilation
        temp_dir = tempfile.mkdtemp(prefix="bambu_agent_")
        scad_path = os.path.join(temp_dir, f"{filename}.scad")
        stl_path = os.path.join(temp_dir, f"{filename}.stl")

        try:
            # Write OpenSCAD code to file
            with open(scad_path, 'w') as f:
                f.write(openscad_code)

            logger.info(f"Compiling {scad_path} to {stl_path}")

            # Run OpenSCAD compilation
            cmd = [
                self.openscad_cmd,
                "-o", stl_path,
                "--export-format=binstl",
                scad_path
            ]

            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )

            stdout, stderr = await process.communicate()

            if process.returncode != 0:
                error_msg = stderr.decode() if stderr else "Unknown OpenSCAD error"
                logger.error(f"OpenSCAD compilation failed: {error_msg}")
                raise Exception(f"OpenSCAD compilation failed: {error_msg}")

            if not os.path.exists(stl_path):
                raise Exception("STL file was not created by OpenSCAD")

            logger.info(f"Successfully compiled to: {stl_path}")
            return stl_path

        except Exception as e:
            logger.error(f"Error during OpenSCAD compilation: {str(e)}")
            # Clean up temp directory on error
            try:
                import shutil
                shutil.rmtree(temp_dir)
            except:
                pass
            raise

    def validate_openscad_syntax(self, openscad_code: str) -> bool:
        """
        Validate OpenSCAD syntax without generating STL
        """
        if not self.openscad_cmd:
            return False

        temp_dir = tempfile.mkdtemp(prefix="bambu_agent_validate_")
        scad_path = os.path.join(temp_dir, "validate.scad")

        try:
            with open(scad_path, 'w') as f:
                f.write(openscad_code)

            # Run syntax check only
            cmd = [self.openscad_cmd, "--check-file", scad_path]

            result = subprocess.run(cmd, capture_output=True, text=True)

            return result.returncode == 0

        except Exception:
            return False
        finally:
            # Clean up
            try:
                import shutil
                shutil.rmtree(temp_dir)
            except:
                pass

    def get_openscad_info(self) -> dict:
        """
        Get OpenSCAD version and installation info
        """
        if not self.openscad_cmd:
            return {"installed": False, "path": None, "version": None}

        try:
            result = subprocess.run([self.openscad_cmd, "--version"],
                                  capture_output=True, text=True)
            version = result.stdout.strip() if result.returncode == 0 else "Unknown"

            return {
                "installed": True,
                "path": self.openscad_cmd,
                "version": version
            }
        except Exception as e:
            return {
                "installed": False,
                "path": self.openscad_cmd,
                "version": None,
                "error": str(e)
            }