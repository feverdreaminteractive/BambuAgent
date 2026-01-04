exports.handler = async (event, context) => {
    console.log('Convert-to-STL function called');
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
        const { openscadCode } = JSON.parse(event.body);

        if (!openscadCode) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'OpenSCAD code is required' })
            };
        }

        // Use Claude API to convert OpenSCAD to STL
        const claudeKey = process.env.ANTHROPIC_API_KEY;

        if (!claudeKey) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'API key not configured' })
            };
        }

        // Ask Claude to convert the OpenSCAD code directly to STL format
        const conversionPrompt = `You are an expert 3D modeling engineer. Convert this OpenSCAD code to ASCII STL format.

IMPORTANT: Generate the EXACT model described in the OpenSCAD code as STL triangles.

OpenSCAD Code to Convert:
${openscadCode}

REQUIREMENTS:
- Output ONLY ASCII STL format (solid/facet/vertex/endloop/endfacet/endsolid)
- Generate thousands of triangles for complex models
- Include all details from the OpenSCAD: shapes, positions, rotations, scaling
- For complex shapes like spheres/cylinders, use high tessellation (16+ segments)
- For hull(), union(), difference() operations, generate the final merged geometry
- For for() loops, generate all iterations
- For modules, expand them into final geometry

OUTPUT FORMAT:
solid ModelName
facet normal nx ny nz
  outer loop
    vertex x1 y1 z1
    vertex x2 y2 z2
    vertex x3 y3 z3
  endloop
endfacet
[... more facets ...]
endsolid ModelName

Generate the complete STL file that represents the exact model described in the OpenSCAD code.`;

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
                max_tokens: 4000,
                messages: [{
                    role: 'user',
                    content: conversionPrompt
                }]
            })
        });

        if (!response.ok) {
            throw new Error(`Claude API failed: ${response.status}`);
        }

        const result = await response.json();
        let stlContent = result.content[0].text;

        // Clean up the STL content - extract just the STL part
        if (stlContent.includes('```')) {
            const stlStart = stlContent.indexOf('solid ');
            const stlEnd = stlContent.lastIndexOf('endsolid');

            if (stlStart !== -1 && stlEnd !== -1) {
                const endSolidLine = stlContent.indexOf('\n', stlEnd);
                stlContent = stlContent.substring(stlStart, endSolidLine !== -1 ? endSolidLine : stlEnd + 8);
            }
        }

        // Ensure it starts with 'solid' and ends with 'endsolid'
        if (!stlContent.trim().startsWith('solid')) {
            throw new Error('Generated content is not valid STL format');
        }

        return {
            statusCode: 200,
            headers,
            body: JSON.stringify({
                success: true,
                stlContent: stlContent.trim(),
                message: 'STL generated successfully by Claude AI'
            })
        };

    } catch (error) {
        console.error('STL conversion error:', error);
        console.error('Error stack:', error.stack);

        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                success: false,
                error: 'STL conversion failed',
                details: error.message,
                stack: error.stack
            })
        };
    }
};