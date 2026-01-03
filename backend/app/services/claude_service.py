import os
import asyncio
from typing import Dict, Any
import logging
from anthropic import Anthropic

logger = logging.getLogger(__name__)

class ClaudeService:
    def __init__(self):
        self.api_key = os.getenv("ANTHROPIC_API_KEY")
        if not self.api_key:
            logger.warning("ANTHROPIC_API_KEY not found in environment")

        self.client = Anthropic(api_key=self.api_key) if self.api_key else None

    async def generate_openscad(self, prompt: str, user_api_key: str = None) -> Dict[str, Any]:
        """
        Generate OpenSCAD code from a text prompt using Claude API
        """
        # Use user-provided API key if available, otherwise fall back to environment key
        api_key = user_api_key or self.api_key
        client = Anthropic(api_key=api_key) if api_key else None

        if not client:
            # Return a simple cube for testing when API key is not available
            return {
                "openscadCode": """
// Simple test cube
cube([20, 20, 20], center=true);
""",
                "explanation": "Test cube generated (no API key configured)",
                "estimatedPrintTime": "15 minutes"
            }

        try:
            system_prompt = """You are an expert OpenSCAD programmer. Generate clean, functional OpenSCAD code based on user prompts.

Guidelines:
1. Create practical, printable 3D models
2. Use appropriate dimensions (consider a 256x256x256mm build volume)
3. Include comments explaining the design
4. Ensure the model is centered and oriented for printing
5. Add small features like chamfers or fillets where appropriate
6. Keep complexity reasonable for 3D printing
7. Always end with a final union() or difference() if needed

Return your response in this format:
- Brief explanation of the design approach
- Complete OpenSCAD code
- Estimated print time"""

            user_prompt = f"""Create a 3D model for: {prompt}

Requirements:
- Suitable for FDM 3D printing on Bambu A1 mini
- No overhangs greater than 45 degrees without support
- Minimum wall thickness of 0.8mm
- Practical and functional design"""

            message = client.messages.create(
                model="claude-3-haiku-20240307",
                max_tokens=2000,
                system=system_prompt,
                messages=[
                    {"role": "user", "content": user_prompt}
                ]
            )

            response_text = message.content[0].text

            # Parse the response to extract code
            code_start = response_text.find("```openscad")
            if code_start == -1:
                code_start = response_text.find("```")

            if code_start != -1:
                code_end = response_text.find("```", code_start + 3)
                if code_end != -1:
                    # Extract code between markers
                    openscad_code = response_text[code_start:code_end].split("\n", 1)[1]
                    explanation = response_text[:code_start].strip()
                else:
                    # No closing markers, take everything after opening
                    openscad_code = response_text[code_start:].split("\n", 1)[1]
                    explanation = "Generated OpenSCAD code from prompt"
            else:
                # No code markers found, assume entire response is code
                openscad_code = response_text
                explanation = "Generated OpenSCAD code from prompt"

            # Extract estimated print time if mentioned
            estimated_time = None
            lines = response_text.lower().split("\n")
            for line in lines:
                if "time" in line and any(unit in line for unit in ["minute", "hour", "min", "hr"]):
                    estimated_time = line.strip()
                    break

            return {
                "openscadCode": openscad_code.strip(),
                "explanation": explanation,
                "estimatedPrintTime": estimated_time
            }

        except Exception as e:
            logger.error(f"Claude API error: {str(e)}")
            # Return fallback code
            return {
                "openscadCode": f"""
// Fallback design for: {prompt}
// Simple parametric box
length = 50;
width = 30;
height = 20;
wall_thickness = 2;

difference() {{
    cube([length, width, height], center=true);
    translate([0, 0, wall_thickness])
        cube([length-wall_thickness*2, width-wall_thickness*2, height], center=true);
}}
""",
                "explanation": f"Fallback design generated due to API error: {str(e)}",
                "estimatedPrintTime": "30 minutes"
            }