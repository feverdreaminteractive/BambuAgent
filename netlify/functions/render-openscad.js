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

        // Since OpenSCAD is not available in Netlify Functions environment,
        // return a message indicating Three.js fallback should be used
        return {
            statusCode: 200,
            headers: {
                ...headers,
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({
                success: false,
                error: 'OpenSCAD not available in serverless environment',
                fallbackRequired: true,
                message: 'Please use Three.js preview fallback for rendering',
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