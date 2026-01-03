"""
Bambu Printer Discovery Service
Scans local network for Bambu printers using mDNS/Bonjour
"""

import asyncio
import logging
from typing import List, Dict, Optional
from zeroconf import ServiceBrowser, ServiceListener, Zeroconf
from zeroconf.asyncio import AsyncZeroconf
import socket
import json

logger = logging.getLogger(__name__)

class BambuPrinter:
    def __init__(self, name: str, ip: str, port: int, model: str = "Unknown"):
        self.name = name
        self.ip = ip
        self.port = port
        self.model = model
        self.id = f"{ip}:{port}"

    def to_dict(self) -> Dict:
        return {
            "id": self.id,
            "name": self.name,
            "ip": self.ip,
            "port": self.port,
            "model": self.model
        }

class BambuServiceListener(ServiceListener):
    def __init__(self):
        self.printers: List[BambuPrinter] = []
        self.discovered_event = asyncio.Event()

    def add_service(self, zc: Zeroconf, type_: str, name: str) -> None:
        info = zc.get_service_info(type_, name)
        if info:
            try:
                # Extract IP address
                ip = socket.inet_ntoa(info.addresses[0]) if info.addresses else None
                if ip:
                    # Extract printer name and model from service info
                    printer_name = name.split('.')[0]
                    model = "Bambu A1 mini"  # Default, can be enhanced

                    # Check for additional properties
                    if info.properties:
                        model_prop = info.properties.get(b'model', b'').decode('utf-8')
                        if model_prop:
                            model = model_prop

                    printer = BambuPrinter(
                        name=printer_name,
                        ip=ip,
                        port=info.port,
                        model=model
                    )

                    # Avoid duplicates
                    if not any(p.ip == printer.ip for p in self.printers):
                        self.printers.append(printer)
                        logger.info(f"Discovered Bambu printer: {printer.name} at {printer.ip}:{printer.port}")
                        self.discovered_event.set()

            except Exception as e:
                logger.error(f"Error processing discovered service: {e}")

    def remove_service(self, zc: Zeroconf, type_: str, name: str) -> None:
        pass

    def update_service(self, zc: Zeroconf, type_: str, name: str) -> None:
        pass

class PrinterDiscoveryService:
    def __init__(self):
        self.listener = BambuServiceListener()
        self.zeroconf = None
        self.browser = None

    async def discover_printers(self, timeout: int = 5) -> List[BambuPrinter]:
        """
        Discover Bambu printers on the network

        Args:
            timeout: Discovery timeout in seconds

        Returns:
            List of discovered BambuPrinter objects
        """
        logger.info("Starting Bambu printer discovery...")

        try:
            # Reset previous discoveries
            self.listener.printers.clear()
            self.listener.discovered_event.clear()

            # Start mDNS discovery
            self.zeroconf = AsyncZeroconf()

            # Bambu printers typically advertise these service types
            service_types = [
                "_bambu._tcp.local.",
                "_printer._tcp.local.",
                "_ipp._tcp.local.",
                "_http._tcp.local."
            ]

            browsers = []
            for service_type in service_types:
                browser = ServiceBrowser(self.zeroconf.zeroconf, service_type, self.listener)
                browsers.append(browser)

            # Also try network scanning for common Bambu ports
            await self._scan_network_range()

            # Wait for discoveries or timeout
            try:
                await asyncio.wait_for(self.listener.discovered_event.wait(), timeout=timeout)
            except asyncio.TimeoutError:
                logger.info(f"Discovery timeout after {timeout} seconds")

            # Give a bit more time for any pending discoveries
            await asyncio.sleep(1)

        except Exception as e:
            logger.error(f"Error during printer discovery: {e}")
        finally:
            if self.zeroconf:
                await self.zeroconf.async_close()

        logger.info(f"Discovery completed. Found {len(self.listener.printers)} printers.")
        return self.listener.printers.copy()

    async def _scan_network_range(self):
        """
        Scan local network range for Bambu printers on common ports
        """
        try:
            # Get local IP to determine network range
            local_ip = self._get_local_ip()
            if not local_ip:
                return

            # Extract network base (assumes /24 subnet)
            ip_parts = local_ip.split('.')
            network_base = f"{ip_parts[0]}.{ip_parts[1]}.{ip_parts[2]}"

            # Common Bambu printer ports
            bambu_ports = [8883, 1883, 80, 443]

            # Scan a reasonable range (last 50 IPs)
            scan_tasks = []
            start_range = max(1, int(ip_parts[3]) - 25)
            end_range = min(255, int(ip_parts[3]) + 25)

            for i in range(start_range, end_range):
                ip = f"{network_base}.{i}"
                for port in bambu_ports:
                    scan_tasks.append(self._check_bambu_printer(ip, port))

            # Run scans concurrently but limit concurrent connections
            semaphore = asyncio.Semaphore(20)
            async def limited_scan(task):
                async with semaphore:
                    return await task

            await asyncio.gather(*[limited_scan(task) for task in scan_tasks], return_exceptions=True)

        except Exception as e:
            logger.error(f"Error during network range scan: {e}")

    async def _check_bambu_printer(self, ip: str, port: int):
        """
        Check if a specific IP:port hosts a Bambu printer
        """
        try:
            # Quick connection test
            future = asyncio.open_connection(ip, port)
            reader, writer = await asyncio.wait_for(future, timeout=1.0)
            writer.close()
            await writer.wait_closed()

            # If connection successful, try to identify as Bambu printer
            # This is a simplified check - could be enhanced with actual Bambu protocol detection
            printer = BambuPrinter(
                name=f"Bambu-{ip.split('.')[-1]}",
                ip=ip,
                port=port,
                model="Bambu A1 mini"
            )

            # Avoid duplicates
            if not any(p.ip == printer.ip for p in self.listener.printers):
                self.listener.printers.append(printer)
                logger.info(f"Found potential Bambu printer at {ip}:{port}")
                self.listener.discovered_event.set()

        except Exception:
            # Connection failed or timeout - not a printer or not reachable
            pass

    def _get_local_ip(self) -> Optional[str]:
        """Get the local IP address of this machine"""
        try:
            # Connect to a remote address to determine local IP
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.connect(("8.8.8.8", 80))
                return s.getsockname()[0]
        except Exception:
            return None

# Global discovery service instance
discovery_service = PrinterDiscoveryService()

async def discover_bambu_printers(timeout: int = 5) -> List[Dict]:
    """
    Convenience function to discover Bambu printers

    Returns:
        List of printer dictionaries
    """
    printers = await discovery_service.discover_printers(timeout)
    return [printer.to_dict() for printer in printers]