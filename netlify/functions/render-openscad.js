// OpenSCAD rendering via Netlify Functions
// Note: OpenSCAD binary not available in serverless environment

exports.handler = async (event, context) => {
    // Handle CORS
    const headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS'
    };

    if (event.httpMethod === 'OPTIONS') {
        return {
            statusCode: 200,
            headers,
            body: ''
        };
    }

    if (event.httpMethod !== 'POST') {
        return {
            statusCode: 405,
            headers,
            body: JSON.stringify({ error: 'Method not allowed' })
        };
    }

    try {
        const { openscadCode, format = 'stl' } = JSON.parse(event.body);

        if (!openscadCode) {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'OpenSCAD code is required' })
            };
        }

        // Try multiple OpenSCAD rendering services with fallbacks
        const renderServices = [
            {
                name: 'OpenSCAD.cloud',
                url: 'https://openscad.cloud/api/render',
                method: 'POST',
                body: {
                    scadCode: openscadCode,
                    format: format,
                    resolution: '512x512'
                }
            },
            {
                name: 'MakeWithTech API',
                url: 'https://models.makewithtech.com/api/render',
                method: 'POST',
                body: {
                    code: openscadCode,
                    output: format,
                    width: 512,
                    height: 512
                }
            },
            {
                name: 'OpenSCAD MCP Service',
                url: 'https://openscad-mcp.herokuapp.com/render',
                method: 'POST',
                body: {
                    openscad_code: openscadCode,
                    format: format,
                    camera: {
                        position: [50, 50, 50],
                        target: [0, 0, 0]
                    },
                    image_size: [512, 512]
                }
            }
        ];

        // Try each service in order
        for (const service of renderServices) {
            try {
                console.log(`Attempting render with ${service.name}...`);

                const renderResponse = await fetch(service.url, {
                    method: service.method,
                    headers: {
                        'Content-Type': 'application/json',
                        'User-Agent': 'BambuAgent/1.0'
                    },
                    body: JSON.stringify(service.body),
                    timeout: 30000 // 30 second timeout
                });

                if (renderResponse.ok) {
                    const result = await renderResponse.json();

                    // Handle different response formats
                    let imageData = result.data || result.image || result.png || result.output;

                    if (imageData) {
                        return {
                            statusCode: 200,
                            headers: {
                                ...headers,
                                'Content-Type': 'application/json'
                            },
                            body: JSON.stringify({
                                success: true,
                                format: format,
                                data: imageData.startsWith('data:') ? imageData : `data:image/png;base64,${imageData}`,
                                renderTime: result.renderTime || result.duration || 'N/A',
                                message: `Rendered via ${service.name}`,
                                service: service.name
                            })
                        };
                    }
                }

                console.log(`${service.name} failed with status:`, renderResponse.status);

            } catch (serviceError) {
                console.log(`${service.name} error:`, serviceError.message);
                // Continue to next service
            }
        }

        // Fallback: Return indication that Three.js should be used
        return {
            statusCode: 200,
            headers: {
                ...headers,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                success: false,
                error: 'OpenSCAD rendering not available',
                fallbackRequired: true,
                message: 'Using Three.js preview fallback',
                format: format,
                openscadCode: openscadCode
            })
        };

    } catch (error) {
        console.error('OpenSCAD rendering error:', error);

        return {
            statusCode: 500,
            headers,
            body: JSON.stringify({
                success: false,
                error: 'OpenSCAD rendering failed',
                details: error.message
            })
        };
    }
};