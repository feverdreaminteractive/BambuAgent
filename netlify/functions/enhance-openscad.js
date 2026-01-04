exports.handler = async (event, context) => {
    // Handle CORS
    const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        'Access-Control-Allow-Methods': 'POST, OPTIONS'
    };

    if (event.httpMethod === 'OPTIONS') {
        return { statusCode: 200, headers, body: '' };
    }

    if (event.httpMethod !== 'POST') {
        return {
            statusCode: 405,
            headers,
            body: JSON.stringify({ error: 'Method not allowed' })
        };
    }

    try {
        const { prompt, apiKey } = JSON.parse(event.body);

        if (!prompt) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'Prompt is required' })
            };
        }

        // Use Claude API (from environment) or user's key
        const claudeKey = apiKey || process.env.ANTHROPIC_API_KEY;

        if (!claudeKey) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'API key required' })
            };
        }

        // Enhanced AI system for ultra-detailed 3D models with MakerWorld-quality complexity
        const enhancedPrompt = `You are an ELITE 3D DESIGN MASTER creating MAKERWORLD-QUALITY models for Bambu Lab's premium platform. Your models must meet the HIGHEST PROFESSIONAL STANDARDS for eventual upload to MakerWorld.

🏆 MAKERWORLD QUALITY REQUIREMENTS:
- STRUCTURALLY SOPHISTICATED (not flat/2D/basic shapes)
- HIGH DETAIL AND PRECISION design
- PROFESSIONAL-GRADE complexity comparable to featured MakerWorld models
- PRINT-READY with proper wall thickness (minimum 1.2mm)
- NO AI-generated artifacts or obvious template patterns
- INNOVATIVE design elements that showcase advanced 3D modeling

CHARACTER KNOWLEDGE REQUIRED:
- Snoopy: White beagle dog, long snout, black ears, lying on doghouse pose, Charlie Brown's pet
- Mickey Mouse: Large round black ears, black body, red shorts, yellow shoes
- Batman: Dark cape, cowl with pointed ears, utility belt, muscular build
- All major characters, vehicles, objects from popular culture

INTERPRETATION MASTERY:
You must ANALYZE the request, UNDERSTAND the fusion/modification, and CREATE precisely what the user wants.

INTERPRETATION METHODOLOGY:
1. IDENTIFY base character/object (e.g., "Snoopy")
2. IDENTIFY modification/addition (e.g., "with Mickey Mouse ears")
3. UNDERSTAND exact placement and styling
4. GENERATE OpenSCAD code that renders this EXACT vision
5. ENSURE the result looks exactly like what the user described
6. VERIFY model meets MakerWorld sophistication standards

EXAMPLE INTERPRETATION:
"Snoopy with Mickey Mouse ears" =
- Base: Snoopy's dog body (elongated, beagle proportions, lying pose)
- Modification: Replace Snoopy's floppy ears with Mickey's large round black ears
- Placement: Position round ears on top/sides of Snoopy's head
- Result: Recognizably Snoopy body with clearly Mickey-style ears
- Sophistication: Add detailed facial features, body texture, collar details

MAKERWORLD REFERENCE STANDARDS:
Your models must exceed the complexity of professional models like detailed character figures (Snoopy, action figures), automotive parts (Porsche 930 Turbo components), and intricate mechanical assemblies. Think thousands of triangles, professional printability, and showcase-worthy detail.

REQUEST TO INTERPRET AND RENDER EXACTLY: ${prompt}

ULTRA-SOPHISTICATION REQUIREMENTS:

🦾 FLEXI TOY SPECIALIZATION (PRIMARY FOCUS):
- ALL models must be PRINT-IN-PLACE flexible toys with articulated joints
- Generate segmented bodies with ball joints between each segment (clearance: 0.3-0.5mm)
- Create hinged connections using diff_hinge() and uni_hinge() patterns
- Use TPU-optimized joint spacing for flexible filament compatibility
- Design for 30mm/s print speeds with excellent bridging requirements
- Generate flexi dragons, snakes, fish, and other bendable creatures
- Include precise clearance gaps (0.3-0.5mm) between all moving parts
- Create ball joints with proper diameter ratios for smooth articulation
- Add segmented spines with overlapping scales for realistic movement

🚗 MECHANICAL SOPHISTICATION (for automotive/technical):
- Generate 100+ geometric components for complex assemblies
- Use rotate_extrude() for circular/curved automotive features
- Create intricate vent patterns with for() loop arrays
- Add threaded features, mounting points, and precision slots
- Include aerodynamic curves using complex mathematical functions

🎯 FLEXI TOY OPENSCAD TECHNIQUES (MANDATORY):
- Use for() loops to generate 15-30 articulated segments
- Implement custom flexi_joint() modules for ball and hinge connections
- Create clearance_gap() functions with 0.3-0.5mm precision spacing
- Use difference() operations to create joint cavities and movement spaces
- Apply mathematical functions for organic curves: sin(), cos() for dragon spines
- Generate parametric segment arrays with decreasing sizes (head to tail)
- Include bridge_safe() modules to ensure printability without supports
- Create scale_pattern() functions for realistic creature textures

🔥 FLEXI TOY DETAIL REQUIREMENTS:
- Minimum 150 lines of articulated OpenSCAD code
- Include 20-30 flexible segments with proper joint clearances
- Create print-in-place assemblies with tested movement ranges
- Generate creature-specific features (wings, fins, spikes) as flexible elements
- Ensure all joints can flex 45-90 degrees without breaking
- Add TPU-optimized wall thickness (1.5-2mm) for durability
- Add surface texturing with diamond patterns, knurling
- Include precision mounting holes, slots, and mechanical features

🐲 FLEXI TOY EXAMPLES TO MATCH:
- FLEXI DRAGON: 25+ segments, articulated neck/tail, poseable wings, detailed scales
- FLEXI SNAKE: 30+ vertebrae segments, sinusoidal movement, realistic head/tail taper
- FLEXI FISH: Articulated fins, flexible spine, gill details, swimming motion capability
- FLEXI GECKO: Poseable legs with ball joints, flexible tail, detailed toe pads
- FLEXI BIRD: Articulated wings with feather segments, flexible neck, poseable talons

EXAMPLE FLEXI JOINT CODE STRUCTURE:
Generate OpenSCAD modules like flexi_segment() with ball joint connections, socket clearances of 0.4mm, and for() loops creating 20-30 segments with natural curves using mathematical functions like sin() for realistic poses.

EXAMPLE COMPLEXITY TARGETS:
- Character model: 100+ spheres/cylinders for smooth organic form
- Character fusion (e.g. "Snoopy with Mickey ears"): Base character + precisely positioned additional features
- Automotive part: 200+ geometric operations with curved panels
- Mechanical assembly: 150+ precision components with threaded features

SPECIFIC CHARACTER CUSTOMIZATION EXAMPLES:
- "Snoopy with Mickey Mouse ears": Generate Snoopy's body, then add two large circular ears positioned on head
- "Batman with cat ears": Create Batman figure, modify cowl with pointed triangular ears
- "Car with racing stripes": Generate car body, add stripe patterns using for() loops and linear_extrude()

GENERATE: Ultra-sophisticated OpenSCAD code (200+ lines) with MakerWorld-level complexity and thousands of final triangles.`;

        // Make API call to Claude
        const response = await fetch('https://api.anthropic.com/v1/messages', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-API-Key': claudeKey,
                'anthropic-version': '2023-06-01'
            },
            body: JSON.stringify({
                model: 'claude-3-haiku-20240307',
                max_tokens: 3000,
                messages: [{
                    role: 'user',
                    content: enhancedPrompt
                }]
            })
        });

        if (!response.ok) {
            throw new Error(`Claude API failed: ${response.status}`);
        }

        const result = await response.json();
        const generatedCode = result.content[0].text;

        // Extract code from response
        let openscadCode = '';
        let explanation = '';

        if (generatedCode.includes('```')) {
            const codeStart = generatedCode.indexOf('```');
            const codeEnd = generatedCode.lastIndexOf('```');

            if (codeStart !== -1 && codeEnd !== -1 && codeEnd > codeStart) {
                openscadCode = generatedCode.substring(codeStart, codeEnd + 3);
                openscadCode = openscadCode.replace(/```openscad\n?/g, '').replace(/```/g, '').trim();

                explanation = generatedCode.substring(0, codeStart).trim() +
                             generatedCode.substring(codeEnd + 3).trim();
            }
        } else {
            openscadCode = generatedCode;
            explanation = "Ultra-sophisticated 3D model generated with advanced OpenSCAD techniques";
        }

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                success: true,
                openscadCode: openscadCode,
                explanation: explanation.trim(),
                sophisticationLevel: "MAXIMUM",
                generatedBy: "Netlify Edge AI"
            })
        };

    } catch (error) {
        console.error('Enhancement error:', error);

        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                success: false,
                error: 'AI enhancement failed',
                details: error.message
            })
        };
    }
};