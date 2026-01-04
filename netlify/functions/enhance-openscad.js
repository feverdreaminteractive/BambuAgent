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

        // Enhanced AI system for ultra-detailed 3D models
        const enhancedPrompt = `You are an ELITE 3D DESIGN MASTER creating ULTRA-SOPHISTICATED OpenSCAD models.

ULTRA-DETAIL REQUIREMENTS:
Create a model so detailed and sophisticated that it rivals commercial CAD software output.

REQUEST: ${prompt}

MAXIMUM SOPHISTICATION STANDARDS:
🔬 MICRO-DETAIL LEVEL:
- Include 0.1-0.3mm fine surface textures and patterns
- Add realistic wear patterns, tool marks, and manufacturing details
- Create complex internal mechanisms and moving parts
- Include precision-engineered tolerances and fits
- Add professional branding, part numbers, and certification marks

🏗️ STRUCTURAL COMPLEXITY:
- Multi-component assemblies with interacting parts
- Advanced parametric patterns and mathematical curves
- Complex boolean operations (difference, intersection, hull)
- Organic transitions using bezier curves and splines
- Variable wall thickness and stress-relief features

🎨 PROFESSIONAL AESTHETICS:
- CNC-machined surface finishes with tool marks
- Knurled grips with diamond crosshatch patterns
- Embossed logos and fine typography
- Multi-level relief with 10+ depth variations
- Aesthetic details like chamfers, fillets, and surface treatments

ADVANCED OPENSCAD MASTERY:
- Use for() loops for complex parametric arrays
- Implement hull() for smooth organic transitions
- Create custom modules for sophisticated components
- Apply minkowski() for professional edge rounding
- Use rotate_extrude() for threaded and curved features
- Employ intersection() for precision manufacturing details

GENERATE: Complete OpenSCAD code with extreme detail level, professional manufacturing quality, and commercial-grade sophistication.`;

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