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
        const enhancedPrompt = `You are an ELITE 3D DESIGN MASTER creating ULTRA-SOPHISTICATED OpenSCAD models that match MakerWorld and Printables quality.

REFERENCE QUALITY STANDARDS:
Your models must match the complexity of professional models like detailed character figures (Snoopy, action figures), automotive parts (Porsche 930 Turbo components), and intricate mechanical assemblies. Think thousands of triangles, not dozens.

REQUEST: ${prompt}

ULTRA-SOPHISTICATION REQUIREMENTS:

🦾 ORGANIC COMPLEXITY (for characters/figures):
- Generate 50+ spheres and cylinders for smooth organic shapes
- Use hull() operations between 10+ objects for seamless body transitions
- Create facial features with precise sphere/cylinder positioning
- Handle character customization and feature fusion (e.g. "Snoopy with Mickey ears")
- Position additional features with mathematical precision using translate() and rotate()
- Add clothing details with complex extrusions and boolean operations
- Include fine surface textures using minkowski() with small spheres
- Create character variations by combining multiple iconic design elements

🚗 MECHANICAL SOPHISTICATION (for automotive/technical):
- Generate 100+ geometric components for complex assemblies
- Use rotate_extrude() for circular/curved automotive features
- Create intricate vent patterns with for() loop arrays
- Add threaded features, mounting points, and precision slots
- Include aerodynamic curves using complex mathematical functions

🎯 ADVANCED OPENSCAD TECHNIQUES (MANDATORY):
- Use for() loops to generate 20+ repeated elements
- Implement hull() between multiple objects for smooth transitions
- Create 5+ custom modules for complex sub-assemblies
- Use intersection() and difference() for precision cutouts
- Apply mathematical functions: sin(), cos(), sqrt() for curves
- Generate parametric arrays with nested for() loops

🔥 EXTREME DETAIL LEVEL:
- Minimum 200 lines of sophisticated OpenSCAD code
- Include 50+ individual geometric operations
- Create multi-level assemblies with 3+ depth layers
- Add surface texturing with diamond patterns, knurling
- Include precision mounting holes, slots, and mechanical features

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