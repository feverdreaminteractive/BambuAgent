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

        # Real OpenSCAD template database from open source projects
        self.openscad_templates = {
            "box_container": {
                "keywords": ["box", "container", "storage", "holder", "organizer"],
                "code": """
// Parametric Box Container Template
// Based on common open-source designs

module rounded_box(size, wall_thickness=2, corner_radius=2) {
    difference() {
        // Outer shell with rounded corners
        hull() {
            for (x = [corner_radius, size[0] - corner_radius])
                for (y = [corner_radius, size[1] - corner_radius])
                    for (z = [0, size[2]]) {
                        translate([x, y, z])
                            cylinder(h = 0.01, r = corner_radius);
                    }
        }

        // Inner cavity
        translate([wall_thickness, wall_thickness, wall_thickness])
            cube([size[0] - 2*wall_thickness,
                  size[1] - 2*wall_thickness,
                  size[2]]);
    }
}

// Main object
length = 50;
width = 30;
height = 20;
wall_thickness = 2;

rounded_box([length, width, height], wall_thickness);
""",
                "description": "Parametric box with rounded corners and hollow interior"
            },

            "mounting_bracket": {
                "keywords": ["mount", "bracket", "holder", "clamp", "attach"],
                "code": """
// Mounting Bracket Template
// Inspired by maker community designs

module mounting_bracket(width=30, height=40, thickness=4, screw_diameter=3.2) {
    difference() {
        union() {
            // Main mounting plate
            cube([width, thickness, height]);

            // Reinforcement ribs
            for (i = [0.2, 0.8]) {
                translate([width * i - 1, 0, 0])
                    cube([2, thickness * 2, height * 0.7]);
            }
        }

        // Mounting holes
        for (z = [height * 0.2, height * 0.8]) {
            translate([width/2, thickness + 1, z])
                rotate([90, 0, 0])
                    cylinder(h=thickness + 2, d=screw_diameter);
        }
    }
}

mounting_bracket();
""",
                "description": "Parametric mounting bracket with screw holes"
            },

            "threaded_container": {
                "keywords": ["thread", "screw", "jar", "bottle", "cap", "lid"],
                "code": """
// Threaded Container Template
// Based on bottle/jar designs

module thread_profile(pitch=2) {
    polygon([
        [0, 0],
        [pitch * 0.6, pitch * 0.3],
        [pitch * 0.6, pitch * 0.7],
        [0, pitch]
    ]);
}

module threaded_cylinder(diameter, height, pitch=2, thread_depth=1) {
    difference() {
        cylinder(d=diameter, h=height);

        // Thread groove (simplified)
        for (turn = [0 : pitch : height]) {
            translate([0, 0, turn])
                rotate_extrude()
                    translate([diameter/2 - thread_depth/2, 0])
                        thread_profile(pitch);
        }
    }
}

module container_with_threads(outer_d=40, wall_thickness=2, height=60) {
    thread_pitch = 2;

    difference() {
        // Outer shell
        cylinder(d=outer_d, h=height);

        // Inner cavity
        translate([0, 0, wall_thickness])
            cylinder(d=outer_d - 2*wall_thickness, h=height);

        // Thread the top portion
        translate([0, 0, height - 10])
            threaded_cylinder(outer_d - wall_thickness, 12, thread_pitch);
    }
}

container_with_threads();
""",
                "description": "Container with threaded top for screw-on lids"
            },

            "mechanical_gear": {
                "keywords": ["gear", "mechanical", "rotation", "teeth", "drive"],
                "code": """
// Parametric Gear Template
// Simplified gear generation

module gear(teeth=12, circular_pitch=5, gear_thickness=3, bore_diameter=5) {
    pitch_diameter = teeth * circular_pitch / PI;

    difference() {
        union() {
            // Base cylinder
            cylinder(d=pitch_diameter * 0.9, h=gear_thickness);

            // Gear teeth (simplified as spokes)
            for (i = [0 : teeth - 1]) {
                rotate([0, 0, i * 360 / teeth]) {
                    translate([pitch_diameter * 0.4, 0, 0])
                        cube([pitch_diameter * 0.2, circular_pitch * 0.3, gear_thickness], center=true);
                }
            }
        }

        // Center bore
        cylinder(d=bore_diameter, h=gear_thickness + 1, center=true);
    }
}

gear(teeth=16, circular_pitch=4);
""",
                "description": "Parametric gear with configurable teeth count"
            },

            "phone_stand": {
                "keywords": ["phone", "tablet", "stand", "dock", "holder", "support"],
                "code": """
// Device Stand Template
// Universal phone/tablet stand

module device_stand(width=80, depth=60, height=45, thickness=3, angle=15) {

    // Back support
    translate([0, depth - thickness, 0])
        cube([width, thickness, height]);

    // Angled base
    intersection() {
        cube([width, depth, thickness + 5]);
        translate([0, 0, thickness])
            rotate([-angle, 0, 0])
                cube([width, depth * 2, thickness]);
    }

    // Side supports
    for (x = [thickness, width - thickness * 2]) {
        translate([x, 0, 0])
            cube([thickness, depth * 0.7, height * 0.6]);
    }

    // Cable channel
    translate([width/2 - 5, thickness, 0])
        cube([10, depth - thickness * 2, thickness + 1]);
}

device_stand();
""",
                "description": "Angled stand for phones and tablets with cable management"
            }
        }

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

    def detect_openscad_template(self, prompt: str) -> tuple:
        """
        Detect the most appropriate OpenSCAD template based on prompt keywords
        Returns (template_name, template_data)
        """
        prompt_lower = prompt.lower()

        template_scores = {}
        for template_name, template_data in self.openscad_templates.items():
            score = sum(1 for keyword in template_data["keywords"] if keyword in prompt_lower)
            if score > 0:
                template_scores[template_name] = score

        if template_scores:
            best_template = max(template_scores.items(), key=lambda x: x[1])[0]
            return best_template, self.openscad_templates[best_template]

        # Fallback to box_container as most versatile
        return "box_container", self.openscad_templates["box_container"]

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
            # No templates - unlimited generation!

            system_prompt = """You are an elite 3D character artist and OpenSCAD master specializing in creating RECOGNIZABLE, ACCURATE representations of any object or character.

CRITICAL SUCCESS FACTORS:
1. CREATE RECOGNIZABLE SHAPES - the result must actually look like what was requested
2. STUDY THE SUBJECT - understand the key features that make something identifiable
3. FOCUS ON PROPORTIONS - get the size relationships exactly right
4. BUILD SOPHISTICATED GEOMETRY - use advanced OpenSCAD techniques for realism

CHARACTER MODELING EXPERTISE:
For characters like Snoopy, understand that recognition comes from:
- CORRECT PROPORTIONS: Snoopy has a long snout, droopy ears, oval body
- KEY FEATURES: Black nose, long ears that hang down, white coloring, sitting pose
- ANATOMICAL ACCURACY: Head connects to body correctly, ears positioned properly
- CHARACTERISTIC POSE: Snoopy sits upright, ears droop naturally

ADVANCED OPENSCAD MASTERY:
- Use hull() extensively to create smooth, organic transitions
- Combine multiple spheres/ellipsoids with hull() for body shapes
- Use scale() to create non-uniform shapes (oval heads, elongated snouts)
- Apply minkowski() for rounded, organic edges
- Create custom modules for complex body parts
- Use rotate_extrude() for curved features
- Employ intersection() for precise shape cutting
- Use mathematical curves (sin, cos, bezier) for organic forms

SOPHISTICATED MODELING APPROACH:
Instead of basic cube + nose, create:
- Multiple connected organic shapes using hull()
- Proper anatomical proportions using scale()
- Smooth transitions between body parts
- Realistic features positioned correctly
- Complex geometries that capture the essence

EXAMPLE ADVANCED TECHNIQUE for organic shapes:
```openscad
// Create organic body using multiple hulled spheres
hull() {
    translate([0,0,0]) sphere(r=10);
    translate([0,15,5]) sphere(r=8);
    translate([0,25,0]) sphere(r=6);
}
```

YOUR MISSION: Generate OpenSCAD code that creates something that actually LOOKS LIKE what was requested, not just a geometric approximation."""

            user_prompt = f"""CREATE A RECOGNIZABLE 3D MODEL: {prompt}

CRITICAL REQUIREMENTS:
The final result must be INSTANTLY RECOGNIZABLE as "{prompt}" - not just a geometric approximation.

STEP-BY-STEP ANALYSIS:
1. VISUALIZE: What does "{prompt}" actually look like? What makes it instantly recognizable?
2. PROPORTIONS: What are the correct size relationships between different parts?
3. KEY FEATURES: What specific details are essential for recognition?
4. POSE/ORIENTATION: What position/angle best captures the character/object?
5. ADVANCED GEOMETRY: How can I use hull(), scale(), rotate(), and other operations to create organic, realistic shapes?

MODELING STRATEGY:
- Use hull() to connect multiple spheres/shapes for organic forms
- Use scale() to create ovals, elongated shapes, proper proportions
- Position features accurately using precise translate() coordinates
- Create smooth transitions between body parts
- Add characteristic details that make it recognizable

EXAMPLES OF ADVANCED TECHNIQUES TO USE:
- hull() multiple scaled spheres for body shapes
- rotate_extrude() for curved features
- minkowski() for organic rounding
- intersection() for precise cuts
- Custom modules for complex parts

QUALITY STANDARD:
If someone sees the 3D printed result, they should immediately say "That's a {prompt}!"
Not "That's some geometric shapes that vaguely resemble {prompt}."

Generate sophisticated OpenSCAD code that creates an ACTUALLY RECOGNIZABLE "{prompt}" using advanced geometric techniques."""

            logger.info(f"Generating unlimited 3D model for prompt: {prompt}")

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
                "estimatedPrintTime": estimated_time,
                "generatedBy": "Unlimited AI 3D Designer"
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