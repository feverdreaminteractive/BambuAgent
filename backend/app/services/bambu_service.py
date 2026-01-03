import os
import json
import ssl
import asyncio
import ftplib
import uuid
from typing import Dict, Any, Optional, List
from datetime import datetime
import logging
import paho.mqtt.client as mqtt

logger = logging.getLogger(__name__)

class BambuService:
    def __init__(self):
        self.printer_ip = os.getenv("BAMBU_PRINTER_IP")
        self.access_code = os.getenv("BAMBU_ACCESS_CODE")
        self.device_serial = os.getenv("BAMBU_DEVICE_SERIAL", "default_serial")

        if not self.printer_ip or not self.access_code:
            logger.warning("Bambu printer IP or access code not configured")

        self.mqtt_client = None
        self.printer_status = {"status": "unknown"}

    async def connect_mqtt(self) -> bool:
        """
        Connect to Bambu printer MQTT broker
        """
        if not self.printer_ip or not self.access_code:
            logger.error("Printer IP or access code not configured")
            return False

        try:
            self.mqtt_client = mqtt.Client()
            self.mqtt_client.username_pw_set("bblp", self.access_code)

            # Set up TLS
            context = ssl.create_default_context()
            context.check_hostname = False
            context.verify_mode = ssl.CERT_NONE
            self.mqtt_client.tls_set_context(context)

            # Set up callbacks
            self.mqtt_client.on_connect = self._on_mqtt_connect
            self.mqtt_client.on_message = self._on_mqtt_message
            self.mqtt_client.on_disconnect = self._on_mqtt_disconnect

            # Connect to printer
            logger.info(f"Connecting to Bambu printer at {self.printer_ip}:8883")
            self.mqtt_client.connect(self.printer_ip, 8883, 60)
            self.mqtt_client.loop_start()

            # Wait a bit for connection
            await asyncio.sleep(2)
            return True

        except Exception as e:
            logger.error(f"Failed to connect to MQTT: {str(e)}")
            return False

    def _on_mqtt_connect(self, client, userdata, flags, rc):
        """MQTT connection callback"""
        if rc == 0:
            logger.info("Connected to Bambu MQTT broker")
            # Subscribe to printer status updates
            client.subscribe(f"device/{self.device_serial}/report")
        else:
            logger.error(f"Failed to connect to MQTT, return code {rc}")

    def _on_mqtt_message(self, client, userdata, msg):
        """MQTT message callback"""
        try:
            topic = msg.topic
            payload = json.loads(msg.payload.decode())

            if "report" in topic:
                # Update printer status
                self._update_printer_status(payload)

        except Exception as e:
            logger.error(f"Error processing MQTT message: {str(e)}")

    def _on_mqtt_disconnect(self, client, userdata, rc):
        """MQTT disconnect callback"""
        logger.info("Disconnected from Bambu MQTT broker")

    def _update_printer_status(self, payload: Dict[str, Any]):
        """
        Update internal printer status from MQTT payload
        """
        try:
            print_data = payload.get("print", {})
            system_data = payload.get("system", {})

            self.printer_status = {
                "status": self._get_printer_state(print_data),
                "progress": print_data.get("mc_percent", 0),
                "bed_temp": print_data.get("bed_temper", 0),
                "nozzle_temp": print_data.get("nozzle_temper", 0),
                "current_job": {
                    "name": print_data.get("subtask_name", ""),
                    "layer": print_data.get("layer_num", 0),
                    "total_layers": print_data.get("total_layer_num", 0)
                } if print_data.get("subtask_name") else None,
                "last_updated": datetime.now().isoformat()
            }

        except Exception as e:
            logger.error(f"Error updating printer status: {str(e)}")

    def _get_printer_state(self, print_data: Dict[str, Any]) -> str:
        """
        Determine printer state from print data
        """
        gcode_state = print_data.get("gcode_state", "")

        if gcode_state == "RUNNING":
            return "printing"
        elif gcode_state == "PAUSE":
            return "paused"
        elif gcode_state == "FINISH":
            return "finished"
        elif gcode_state == "FAILED":
            return "failed"
        else:
            return "idle"

    async def send_print_job(self, file_path: str, print_name: str) -> str:
        """
        Send print job to Bambu printer via FTP and MQTT
        """
        if not os.path.exists(file_path):
            raise Exception(f"File not found: {file_path}")

        if not self.printer_ip or not self.access_code:
            raise Exception("Printer IP or access code not configured")

        try:
            # Generate unique job ID
            job_id = str(uuid.uuid4())

            # Upload file via FTP
            await self._upload_file_ftp(file_path, print_name)

            # Send print command via MQTT
            await self._send_print_command(print_name, job_id)

            logger.info(f"Print job {job_id} sent successfully")
            return job_id

        except Exception as e:
            logger.error(f"Error sending print job: {str(e)}")
            raise

    async def _upload_file_ftp(self, file_path: str, remote_name: str):
        """
        Upload file to printer via FTP
        """
        try:
            with ftplib.FTP() as ftp:
                ftp.connect(self.printer_ip, 990)
                ftp.login("bblp", self.access_code)

                # Upload file
                with open(file_path, 'rb') as f:
                    ftp.storbinary(f'STOR {remote_name}.3mf', f)

                logger.info(f"File uploaded via FTP: {remote_name}.3mf")

        except Exception as e:
            logger.error(f"FTP upload failed: {str(e)}")
            raise Exception(f"Failed to upload file: {str(e)}")

    async def _send_print_command(self, filename: str, job_id: str):
        """
        Send print command via MQTT
        """
        if not self.mqtt_client:
            await self.connect_mqtt()

        if not self.mqtt_client:
            raise Exception("Could not connect to MQTT")

        try:
            # Prepare print command
            command = {
                "print": {
                    "command": "project_file",
                    "param": f"{filename}.3mf",
                    "sequence_id": job_id,
                    "user_id": "BambuAgent"
                }
            }

            topic = f"device/{self.device_serial}/request"
            payload = json.dumps(command)

            # Send command
            self.mqtt_client.publish(topic, payload)
            logger.info(f"Print command sent for: {filename}")

        except Exception as e:
            logger.error(f"Failed to send print command: {str(e)}")
            raise

    async def get_printer_status(self) -> Dict[str, Any]:
        """
        Get current printer status
        """
        if not self.mqtt_client:
            connected = await self.connect_mqtt()
            if not connected:
                return {
                    "status": "disconnected",
                    "error": "Could not connect to printer"
                }

        # Return cached status (updated via MQTT)
        return self.printer_status

    async def list_recent_jobs(self) -> List[Dict[str, Any]]:
        """
        List recent print jobs (placeholder implementation)
        """
        # This would require maintaining a job history database
        # For now, return empty list
        return []

    def disconnect(self):
        """
        Disconnect from MQTT broker
        """
        if self.mqtt_client:
            self.mqtt_client.loop_stop()
            self.mqtt_client.disconnect()
            self.mqtt_client = None

    def get_connection_info(self) -> Dict[str, Any]:
        """
        Get connection configuration info
        """
        return {
            "printer_ip": self.printer_ip,
            "access_code_configured": bool(self.access_code),
            "device_serial": self.device_serial,
            "mqtt_connected": bool(self.mqtt_client and self.mqtt_client.is_connected())
        }