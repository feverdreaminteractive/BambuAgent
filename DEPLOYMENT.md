# BambuAgent Deployment Guide

## Required API Keys & Services

### 1. 🤖 **Claude AI API Key** (REQUIRED)
**What it does**: Powers the AI model generation from text prompts
**How to get**:
1. Go to https://console.anthropic.com
2. Sign up or login with your account
3. Navigate to "API Keys" in the dashboard
4. Click "Create Key"
5. Copy the key (starts with `sk-ant-`)
6. Add to environment: `ANTHROPIC_API_KEY=sk-ant-your-key-here`

**Cost**: Pay-per-use, typically $0.01-0.10 per generation

### 2. 🖨️ **Bambu A1 Mini Printer** (REQUIRED for printing)
**What it does**: Receives and prints the generated 3D models
**How to get**:
1. On your printer's LCD screen:
   - Go to **Settings** → **WiFi** → **View Info**
   - Note the **IP Address** (e.g., 192.168.1.150)
2. Get the **Access Code**:
   - Go to **Settings** → **WiFi** → **Access Code**
   - Note the 8-digit code
3. Add to environment:
   ```
   BAMBU_PRINTER_IP=192.168.1.150
   BAMBU_ACCESS_CODE=12345678
   ```

### 3. 🔧 **Optional Software** (for full pipeline)
**OpenSCAD** - Converts AI code to STL files
- Download: https://openscad.org/downloads.html
- Set: `OPENSCAD_PATH=/path/to/openscad`

**OrcaSlicer** - Converts STL to G-code
- Download: https://github.com/SoftFever/OrcaSlicer/releases
- Set: `ORCA_SLICER_PATH=/path/to/orca-slicer`

## Quick Setup

1. **Copy the production environment file**:
   ```bash
   cp backend/.env.production backend/.env
   ```

2. **Edit with your actual keys**:
   ```bash
   nano backend/.env
   # or
   code backend/.env
   ```

3. **Replace these values**:
   - `your_claude_api_key_here` → Your actual Claude API key
   - `192.168.1.100` → Your printer's actual IP
   - `12345678` → Your printer's actual access code

4. **Test locally**:
   ```bash
   cd backend
   python -m uvicorn app.main:app --reload
   ```

## Netlify Deployment

1. **Push to GitHub**:
   ```bash
   git add .
   git commit -m "Add production environment"
   git push
   ```

2. **Deploy to Netlify**:
   - Connect your GitHub repo to Netlify
   - Set build command: `pip install -r backend/requirements.txt`
   - Set publish directory: `web`

3. **Add Environment Variables in Netlify**:
   - Go to Site settings → Environment variables
   - Add all the variables from your `.env.production` file

## Testing the Deployment

1. **Check API health**: Visit `/api` endpoint
2. **Test AI generation**: Try the web interface
3. **Verify printer connection**: Check printer status in settings

## Troubleshooting

**"ANTHROPIC_API_KEY not found"** → Add your Claude API key
**"Bambu printer not configured"** → Check IP and access code
**"OpenSCAD not found"** → Install OpenSCAD or use web-only mode
**"Connection failed"** → Verify printer is on same network

## Cost Estimation

- **Claude API**: ~$0.01-0.10 per model generation
- **Netlify Hosting**: Free tier available (100GB bandwidth)
- **Total**: < $5/month for moderate usage

## Security Notes

- Never commit actual API keys to Git
- Use environment variables for all secrets
- Restrict CORS origins in production
- Consider rate limiting for public deployments