#!/usr/bin/env python3
import json
import subprocess

def get_connected_devices():
    # List paired devices
    out = subprocess.check_output(["bluetoothctl", "devices"], text=True)
    lines = out.strip().split("\n")
    
    devices = []
    for line in lines:
        if not line: continue
        parts = line.split(" ", 2)
        if len(parts) >= 3:
            devices.append({"mac": parts[1], "name": parts[2]})
    return devices

def get_device_info(mac):
    try:
        out = subprocess.check_output(["bluetoothctl", "info", mac], text=True)
        return out
    except:
        return ""

def main():
    connected_devices = get_connected_devices()
    display_items = []
    tooltip_items = []
    
    for dev in connected_devices:
        info = get_device_info(dev["mac"])
        
        # Check if actually connected
        if "Connected: yes" in info:
            battery = None
            # Extract battery percentage if available
            for line in info.split("\n"):
                if "Battery Percentage" in line:
                    try:
                        battery = int(line.split("(")[1].split(")")[0])
                    except:
                        pass
            
            # Create the block output string
            if battery is not None:
                display_items.append(f"{dev['name']} ({battery}%)")
            else:
                display_items.append(f"{dev['name']}")
                
            tooltip_items.append(f"{dev['name']} [{dev['mac']}]")

    # If no devices are connected, show nothing or an idle icon
    if not display_items:
        output = {"text": "", "alt": "disconnected", "tooltip": "No devices connected"}
    else:
        # Join devices side-by-side separated by a divider
        output = {
            "text": " | ".join(display_items),
            "alt": "connected",
            "tooltip": "\n".join(tooltip_items)
        }
        
    print(json.dumps(output))

if __name__ == "__main__":
    main()

