const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

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

        // Create temporary directory for this render
        const tmpDir = `/tmp/openscad-render-${Date.now()}`;
        fs.mkdirSync(tmpDir, { recursive: true });

        // Write OpenSCAD code to file
        const scadFile = path.join(tmpDir, 'model.scad');
        fs.writeFileSync(scadFile, openscadCode);

        let outputFile;
        let mimeType;

        if (format === 'stl') {
            outputFile = path.join(tmpDir, 'model.stl');
            mimeType = 'application/sla';

            // Render STL using OpenSCAD
            execSync(`openscad -o "${outputFile}" "${scadFile}"`, {
                timeout: 30000, // 30 second timeout
                stdio: 'pipe'
            });

        } else if (format === 'png') {
            outputFile = path.join(tmpDir, 'model.png');
            mimeType = 'image/png';

            // Render PNG preview using OpenSCAD
            execSync(`openscad -o "${outputFile}" --render --imgsize=512,512 "${scadFile}"`, {
                timeout: 30000,
                stdio: 'pipe'
            });

        } else {
            return {
                statusCode: 400,
                headers,
                body: JSON.stringify({ error: 'Unsupported format. Use "stl" or "png"' })
            };
        }

        // Check if file was created
        if (!fs.existsSync(outputFile)) {
            throw new Error('OpenSCAD rendering failed - no output file generated');
        }

        // Read the generated file
        const fileBuffer = fs.readFileSync(outputFile);

        // Clean up temporary files
        try {
            fs.rmSync(tmpDir, { recursive: true, force: true });
        } catch (cleanupError) {
            console.warn('Cleanup failed:', cleanupError.message);
        }

        if (format === 'png') {
            // Return PNG as base64 for display
            const base64Data = fileBuffer.toString('base64');
            return {
                statusCode: 200,
                headers: {
                    ...headers,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    success: true,
                    format: 'png',
                    data: `data:image/png;base64,${base64Data}`
                })
            };
        } else {
            // Return STL file info
            return {
                statusCode: 200,
                headers: {
                    ...headers,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    success: true,
                    format: 'stl',
                    size: fileBuffer.length,
                    message: 'STL file generated successfully'
                })
            };
        }

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