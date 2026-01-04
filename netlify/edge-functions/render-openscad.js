export default async (request, context) => {
    // Handle CORS
    if (request.method === 'OPTIONS') {
        return new Response('', {
            status: 200,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'POST, OPTIONS'
            }
        });
    }

    if (request.method !== 'POST') {
        return new Response(JSON.stringify({ error: 'Method not allowed' }), {
            status: 405,
            headers: { 'Content-Type': 'application/json' }
        });
    }

    try {
        const { openscadCode, format = 'png', resolution = 512 } = await request.json();

        if (!openscadCode) {
            return new Response(JSON.stringify({ error: 'OpenSCAD code is required' }), {
                status: 400,
                headers: { 'Content-Type': 'application/json' }
            });
        }

        console.log('Rendering OpenSCAD with format:', format);

        // Use OpenSCAD Docker container for rendering
        const renderCommand = format === 'stl'
            ? `echo '${openscadCode.replace(/'/g, "'\\''")}' | docker run -i --rm -v /tmp:/tmp openscad/openscad openscad -o /tmp/output.${format} /dev/stdin`
            : `echo '${openscadCode.replace(/'/g, "'\\''")}' | docker run -i --rm -v /tmp:/tmp openscad/openscad openscad -o /tmp/output.${format} --render --imgsize=${resolution},${resolution} /dev/stdin`;

        // For Edge Functions, we'll use a different approach - call external rendering service
        // Since we can't run Docker directly in Edge Functions

        // Alternative: Use OpenSCAD.js or call external API
        const renderResponse = await fetch('https://api.openscad.cloud/render', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                code: openscadCode,
                format: format,
                resolution: resolution
            })
        });

        if (!renderResponse.ok) {
            throw new Error('External OpenSCAD service failed');
        }

        const result = await renderResponse.json();

        return new Response(JSON.stringify({
            success: true,
            format: format,
            data: result.data,
            renderTime: result.renderTime
        }), {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            }
        });

    } catch (error) {
        console.error('OpenSCAD rendering error:', error);

        return new Response(JSON.stringify({
            success: false,
            error: 'OpenSCAD rendering failed',
            details: error.message
        }), {
            status: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            }
        });
    }
};