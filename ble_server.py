import asyncio
import logging
import psutil
import subprocess
from bless import (
    BlessServer,
    BlessGATTCharacteristic,
    GATTCharacteristicProperties,
    GATTAttributePermissions
)

# --- Configuration ---
SERVICE_NAME = "Strata"
SERVICE_UUID = "56c36f56-da27-464a-952a-9e6631168f6d"

# Characteristic UUIDs
CHAR_CPU_USAGE_UUID = "56c36f57-da27-464a-952a-9e6631168f6d"
CHAR_CPU_TEMP_UUID = "56c36f58-da27-464a-952a-9e6631168f6d"
CHAR_BATTERY_UUID = "56c36f59-da27-464a-952a-9e6631168f6d"

# Setup logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

def get_cpu_temp():
    """Reads the CPU temperature using vcgencmd."""
    try:
        # Raspberry Pi specific command: vcgencmd measure_temp
        # Output format: temp=45.2'C
        output = subprocess.check_output(["vcgencmd", "measure_temp"]).decode("utf-8")
        return output.replace("temp=", "").replace("'C\n", "").strip()
    except FileNotFoundError:
        # Fallback for non-RPi systems (testing)
        return "0.0"
    except Exception as e:
        logger.error(f"Error reading CPU temp: {e}")
        return "Err"

def get_battery_percentage():
    """Placeholder for UPS battery percentage."""
    # TODO: Replace with specific hardware library logic later (e.g., PiSugar, Geekworm)
    return "85"

async def run_server():
    """Main loop for the BLE server."""
    server = BlessServer(name=SERVICE_NAME)
    
    # Define flags and permissions
    # We include 'notify' property so the mobile app can subscribe to updates efficiently.
    char_flags = (
        GATTCharacteristicProperties.read |
        GATTCharacteristicProperties.notify
    )
    permissions = (
        GATTAttributePermissions.readable
    )

    # 1. Add Service
    await server.add_new_service(SERVICE_UUID)

    # 2. Add Characteristics
    # CPU Usage (%)
    await server.add_new_characteristic(
        SERVICE_UUID, CHAR_CPU_USAGE_UUID, char_flags, bytearray("0.0".encode("utf-8")), permissions
    )
    # CPU Temperature (C)
    await server.add_new_characteristic(
        SERVICE_UUID, CHAR_CPU_TEMP_UUID, char_flags, bytearray("0.0".encode("utf-8")), permissions
    )
    # Battery Percentage (%)
    await server.add_new_characteristic(
        SERVICE_UUID, CHAR_BATTERY_UUID, char_flags, bytearray("100".encode("utf-8")), permissions
    )

    logger.info(f"Starting Bless server '{SERVICE_NAME}'...")
    await server.start()
    logger.info(f"Advertising Service: {SERVICE_UUID}")

    try:
        # Initial call to psutil to avoid 0.0 reading
        psutil.cpu_percent(interval=None)
        
        while True:
            # 1. Fetch Diagnostics
            cpu_usage = str(psutil.cpu_percent(interval=None))
            cpu_temp = get_cpu_temp()
            battery = get_battery_percentage()

            # 2. Update Characteristic values and Notify clients
            # Update CPU Usage
            char_usage = server.get_characteristic(CHAR_CPU_USAGE_UUID)
            char_usage.value = cpu_usage.encode("utf-8")
            await server.update_value(SERVICE_UUID, CHAR_CPU_USAGE_UUID)

            # Update CPU Temp
            char_temp = server.get_characteristic(CHAR_CPU_TEMP_UUID)
            char_temp.value = cpu_temp.encode("utf-8")
            await server.update_value(SERVICE_UUID, CHAR_CPU_TEMP_UUID)

            # Update Battery
            char_batt = server.get_characteristic(CHAR_BATTERY_UUID)
            char_batt.value = battery.encode("utf-8")
            await server.update_value(SERVICE_UUID, CHAR_BATTERY_UUID)

            logger.info(f"Stats -> CPU: {cpu_usage}%, Temp: {cpu_temp}C, Battery: {battery}%")
            
            # Wait for 5 seconds as requested
            await asyncio.sleep(5)
            
    except asyncio.CancelledError:
        logger.info("Server task cancelled.")
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
    finally:
        logger.info("Stopping BLE server...")
        await server.stop()

if __name__ == "__main__":
    try:
        asyncio.run(run_server())
    except KeyboardInterrupt:
        logger.info("Server stopped by user.")
