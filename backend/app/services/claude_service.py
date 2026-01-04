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

        # Theme-based model templates for better AI generation
        self.model_templates = {
            "functional": {
                "keywords": ["tool", "holder", "bracket", "mount", "organizer", "container", "box", "hook"],
                "template": """
// Functional design with practical considerations
wall_thickness = 2;
tolerance = 0.2;
corner_radius = 1;

module rounded_cube(size, radius) {
    hull() {
        for(x = [radius, size[0]-radius])
            for(y = [radius, size[1]-radius])
                for(z = [0, size[2]])
                    translate([x, y, z])
                        cylinder(h=0.1, r=radius);
    }
}""",
                "guidelines": "Focus on wall thickness 2mm+, add tolerance for moving parts, include mounting holes, consider print orientation"
            },
            "decorative": {
                "keywords": ["figurine", "statue", "ornament", "decoration", "art", "sculpture", "character", "miniature"],
                "template": """
// Decorative model with detail considerations
base_height = 2;
detail_scale = 1;
support_angle = 45;

module decorative_base(diameter) {
    cylinder(h=base_height, d=diameter);
}""",
                "guidelines": "Add stable base, avoid overhangs >45°, scale details appropriately, consider support material"
            },
            "mechanical": {
                "keywords": ["gear", "bearing", "joint", "hinge", "mechanism", "moving", "rotation", "slider"],
                "template": """
// Mechanical part with precision requirements
clearance = 0.15;
bearing_tolerance = 0.1;
thread_pitch = 1.5;

module bearing_hole(diameter, height) {
    cylinder(h=height, d=diameter + bearing_tolerance);
}""",
                "guidelines": "Include proper clearances, consider thermal expansion, add bearing surfaces, ensure smooth operation"
            },
            "household": {
                "keywords": ["kitchen", "bathroom", "cleaning", "storage", "utility", "domestic", "home", "appliance"],
                "template": """
// Household item with durability focus
food_safe_finish = true;
uv_resistant = true;
easy_clean_surfaces = true;

module smooth_surface(size) {
    hull() {
        translate([1,1,0]) cylinder(h=size[2], r=1);
        translate([size[0]-1,1,0]) cylinder(h=size[2], r=1);
        translate([1,size[1]-1,0]) cylinder(h=size[2], r=1);
        translate([size[0]-1,size[1]-1,0]) cylinder(h=size[2], r=1);
    }
}""",
                "guidelines": "Use smooth surfaces for easy cleaning, consider food safety if applicable, ensure durability"
            },
            "toy": {
                "keywords": ["toy", "game", "puzzle", "educational", "child", "play", "fun", "interactive"],
                "template": """
// Toy design with safety considerations
min_feature_size = 3;
no_sharp_edges = true;
child_safe = true;

module safe_rounded_edge(length, thickness) {
    hull() {
        sphere(r=thickness/2);
        translate([length, 0, 0]) sphere(r=thickness/2);
    }
}""",
                "guidelines": "Remove sharp edges, ensure parts >3mm to prevent choking, use durable materials, test moving parts"
            }
        }

    def detect_model_theme(self, prompt: str) -> str:
        """
        Detect the most appropriate model theme based on prompt keywords
        """
        prompt_lower = prompt.lower()

        theme_scores = {}
        for theme, data in self.model_templates.items():
            score = sum(1 for keyword in data["keywords"] if keyword in prompt_lower)
            if score > 0:
                theme_scores[theme] = score

        if theme_scores:
            return max(theme_scores.items(), key=lambda x: x[1])[0]
        return "functional"  # Default theme

    async def generate_openscad(self, prompt: str, user_api_key: str = None) -> Dict[str, Any]:
        """
        Generate OpenSCAD code from a text prompt using Claude API with theme-based templates
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
            # Detect theme and get template
            theme = self.detect_model_theme(prompt)
            template_data = self.model_templates[theme]

            system_prompt = f"""You are an expert OpenSCAD programmer specializing in {theme} 3D models. Generate clean, functional OpenSCAD code based on user prompts.

THEME: {theme.upper()}
Template Guidelines: {template_data['guidelines']}

Use this template foundation when applicable:
{template_data['template']}

General Guidelines:
1. Create practical, printable 3D models optimized for the {theme} category
2. Use appropriate dimensions (consider a 256x256x256mm build volume)
3. Include comments explaining the design approach
4. Ensure the model is centered and oriented for printing
5. Add small features like chamfers or fillets where appropriate
6. Keep complexity reasonable for FDM 3D printing
7. Follow {theme}-specific best practices for durability and functionality
8. Always end with a final union() or difference() if needed

Return your response in this format:
- Brief explanation of the design approach and why it fits the {theme} category
- Complete OpenSCAD code incorporating template elements where relevant
- Estimated print time"""

            user_prompt = f"""Create a 3D model for: {prompt}

Requirements:
- Suitable for FDM 3D printing on Bambu A1 mini
- No overhangs greater than 45 degrees without support
- Minimum wall thickness of 0.8mm
- Optimized for {theme} category use case
- Follow {theme}-specific design principles
- Incorporate template elements where they enhance the design
- Practical and functional design"""

            logger.info(f"Detected theme '{theme}' for prompt: {prompt}")

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
                "explanation": f"[{theme.upper()} THEME] {explanation}",
                "estimatedPrintTime": estimated_time,
                "theme": theme
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