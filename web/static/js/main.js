// BambuAgent Web Interface
class BambuAgent {
    constructor() {
        this.apiUrl = window.location.origin;
        this.isGenerating = false;
        this.init();
    }

    init() {
        this.bindEvents();
        this.checkApiStatus();
    }

    bindEvents() {
        const generateBtn = document.getElementById('generateBtn');
        const fullPipelineBtn = document.getElementById('fullPipelineBtn');
        const promptInput = document.getElementById('prompt');

        generateBtn.addEventListener('click', () => this.generateModel());
        fullPipelineBtn.addEventListener('click', () => this.runFullPipeline());

        // Enter key support
        promptInput.addEventListener('keypress', (e) => {
            if (e.key === 'Enter' && e.ctrlKey) {
                this.generateModel();
            }
        });
    }

    async checkApiStatus() {
        try {
            const response = await fetch(`${this.apiUrl}/`);
            if (response.ok) {
                this.updateStatusIndicator('api', 'connected', 'Connected');
            } else {
                this.updateStatusIndicator('api', 'error', 'Error');
            }
        } catch (error) {
            this.updateStatusIndicator('api', 'disconnected', 'Disconnected');
        }
    }

    updateStatusIndicator(type, status, text) {
        const statusElement = document.getElementById(`${type}Status`);
        const statusTextElement = document.getElementById(`${type}StatusText`);

        // Remove existing status classes
        statusElement.className = statusElement.className.replace(/bg-\w+-\d+/g, '');

        // Add new status class
        switch (status) {
            case 'connected':
                statusElement.classList.add('bg-green-500');
                statusElement.innerHTML = `
                    <svg class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                `;
                break;
            case 'error':
                statusElement.classList.add('bg-red-500');
                statusElement.innerHTML = `
                    <svg class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                `;
                break;
            case 'loading':
                statusElement.classList.add('bg-yellow-500');
                statusElement.innerHTML = `
                    <div class="animate-spin h-5 w-5 border-2 border-white border-t-transparent rounded-full"></div>
                `;
                break;
            default:
                statusElement.classList.add('bg-gray-500');
                statusElement.innerHTML = `
                    <svg class="h-5 w-5 text-white" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                `;
        }

        statusTextElement.textContent = text;
    }

    async generateModel() {
        const prompt = document.getElementById('prompt').value.trim();
        if (!prompt) {
            this.showNotification('Please enter a description of what you want to 3D print', 'error');
            return;
        }

        this.setGenerating(true);
        this.updateStatusIndicator('generation', 'loading', 'Generating...');

        try {
            const response = await fetch(`${this.apiUrl}/generate`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    prompt: prompt,
                    userId: 'web_user'
                })
            });

            const data = await response.json();

            if (response.ok) {
                this.displayResults(data);
                this.updateStatusIndicator('generation', 'connected', 'Complete');
                this.showNotification('Model generated successfully!', 'success');
            } else {
                throw new Error(data.detail || 'Generation failed');
            }
        } catch (error) {
            console.error('Generation error:', error);
            this.updateStatusIndicator('generation', 'error', 'Failed');
            this.showNotification(`Generation failed: ${error.message}`, 'error');
        } finally {
            this.setGenerating(false);
        }
    }

    async runFullPipeline() {
        const prompt = document.getElementById('prompt').value.trim();
        if (!prompt) {
            this.showNotification('Please enter a description of what you want to 3D print', 'error');
            return;
        }

        this.setGenerating(true);
        this.updateStatusIndicator('generation', 'loading', 'Processing...');

        try {
            const response = await fetch(`${this.apiUrl}/pipeline/full`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    prompt: prompt,
                    userId: 'web_user'
                })
            });

            const data = await response.json();

            if (response.ok) {
                this.displayFullPipelineResults(data);
                this.updateStatusIndicator('generation', 'connected', 'Complete');
                this.showNotification('Model generated and sent to printer!', 'success');
            } else {
                throw new Error(data.detail || 'Pipeline failed');
            }
        } catch (error) {
            console.error('Pipeline error:', error);
            this.updateStatusIndicator('generation', 'error', 'Failed');
            this.showNotification(`Pipeline failed: ${error.message}`, 'error');
        } finally {
            this.setGenerating(false);
        }
    }

    setGenerating(generating) {
        this.isGenerating = generating;
        const generateBtn = document.getElementById('generateBtn');
        const fullPipelineBtn = document.getElementById('fullPipelineBtn');

        generateBtn.disabled = generating;
        fullPipelineBtn.disabled = generating;

        if (generating) {
            generateBtn.innerHTML = `
                <div class="animate-spin h-5 w-5 mr-2 border-2 border-white border-t-transparent rounded-full"></div>
                Generating...
            `;
            fullPipelineBtn.innerHTML = `
                <div class="animate-spin h-5 w-5 mr-2 border-2 border-green-400 border-t-transparent rounded-full"></div>
                Processing...
            `;
        } else {
            generateBtn.innerHTML = `
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"></path>
                </svg>
                Generate Model
            `;
            fullPipelineBtn.innerHTML = `
                <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"></path>
                </svg>
                Generate & Print
            `;
        }
    }

    displayResults(data) {
        const resultsSection = document.getElementById('resultsSection');
        const resultsContent = document.getElementById('resultsContent');

        resultsContent.innerHTML = `
            <div class="bg-gray-800 rounded-lg p-4">
                <h4 class="font-semibold mb-2 text-green-400">Generated OpenSCAD Code</h4>
                <pre class="text-sm text-gray-300 overflow-x-auto bg-gray-900 p-3 rounded"><code>${this.escapeHtml(data.openscadCode)}</code></pre>
            </div>

            <div class="bg-gray-800 rounded-lg p-4">
                <h4 class="font-semibold mb-2 text-blue-400">Explanation</h4>
                <p class="text-gray-300">${this.escapeHtml(data.explanation)}</p>
            </div>

            ${data.estimatedPrintTime ? `
            <div class="bg-gray-800 rounded-lg p-4">
                <h4 class="font-semibold mb-2 text-yellow-400">Estimated Print Time</h4>
                <p class="text-gray-300">${this.escapeHtml(data.estimatedPrintTime)}</p>
            </div>` : ''}

            <div class="flex space-x-4">
                <button onclick="bambuAgent.compileModel('${this.escapeHtml(data.openscadCode)}')"
                        class="px-4 py-2 bg-blue-600 hover:bg-blue-700 rounded-md text-white font-medium">
                    Compile to STL
                </button>
                <button onclick="bambuAgent.copyToClipboard('${this.escapeHtml(data.openscadCode)}')"
                        class="px-4 py-2 bg-gray-600 hover:bg-gray-700 rounded-md text-white font-medium">
                    Copy Code
                </button>
            </div>
        `;

        resultsSection.classList.remove('hidden');
    }

    displayFullPipelineResults(data) {
        const resultsSection = document.getElementById('resultsSection');
        const resultsContent = document.getElementById('resultsContent');

        resultsContent.innerHTML = `
            <div class="bg-green-900/20 border border-green-500/30 rounded-lg p-4">
                <h4 class="font-semibold mb-2 text-green-400 flex items-center">
                    <svg class="w-5 h-5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
                    </svg>
                    Print Job Sent Successfully
                </h4>
                <p class="text-green-300">Job ID: ${data.jobId}</p>
                <p class="text-gray-300 mt-2">${data.message}</p>
            </div>

            ${data.estimatedPrintTime ? `
            <div class="bg-gray-800 rounded-lg p-4">
                <h4 class="font-semibold mb-2 text-yellow-400">Estimated Print Time</h4>
                <p class="text-gray-300">${this.escapeHtml(data.estimatedPrintTime)}</p>
            </div>` : ''}

            <div class="bg-gray-800 rounded-lg p-4">
                <h4 class="font-semibold mb-2 text-blue-400">Generated Files</h4>
                <ul class="space-y-1 text-gray-300">
                    <li>• OpenSCAD Code: Generated</li>
                    <li>• STL File: ${data.stlPath}</li>
                    <li>• G-code File: ${data.gcodePath}</li>
                </ul>
            </div>

            <div class="bg-gray-800 rounded-lg p-4">
                <h4 class="font-semibold mb-2 text-green-400">OpenSCAD Code</h4>
                <pre class="text-sm text-gray-300 overflow-x-auto bg-gray-900 p-3 rounded"><code>${this.escapeHtml(data.openscadCode)}</code></pre>
            </div>
        `;

        resultsSection.classList.remove('hidden');
    }

    async compileModel(openscadCode) {
        this.showNotification('Compiling to STL...', 'info');

        try {
            const response = await fetch(`${this.apiUrl}/compile`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    openscadCode: openscadCode,
                    filename: 'web_model'
                })
            });

            const data = await response.json();

            if (response.ok && data.success) {
                this.showNotification(`STL compiled successfully: ${data.stlPath}`, 'success');
            } else {
                throw new Error(data.errorMessage || 'Compilation failed');
            }
        } catch (error) {
            this.showNotification(`Compilation failed: ${error.message}`, 'error');
        }
    }

    copyToClipboard(text) {
        navigator.clipboard.writeText(text).then(() => {
            this.showNotification('Code copied to clipboard!', 'success');
        }).catch(() => {
            this.showNotification('Failed to copy to clipboard', 'error');
        });
    }

    showNotification(message, type = 'info') {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg max-w-sm transform transition-transform duration-300 translate-x-full`;

        const colors = {
            success: 'bg-green-600 text-white',
            error: 'bg-red-600 text-white',
            info: 'bg-blue-600 text-white',
            warning: 'bg-yellow-600 text-white'
        };

        notification.className += ` ${colors[type] || colors.info}`;
        notification.innerHTML = `
            <div class="flex items-center">
                <span class="flex-1">${this.escapeHtml(message)}</span>
                <button onclick="this.parentElement.parentElement.remove()" class="ml-4 text-white hover:text-gray-200">
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                </button>
            </div>
        `;

        document.body.appendChild(notification);

        // Animate in
        setTimeout(() => {
            notification.classList.remove('translate-x-full');
        }, 100);

        // Auto remove after 5 seconds
        setTimeout(() => {
            notification.classList.add('translate-x-full');
            setTimeout(() => {
                if (notification.parentElement) {
                    notification.remove();
                }
            }, 300);
        }, 5000);
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Initialize the app
const bambuAgent = new BambuAgent();