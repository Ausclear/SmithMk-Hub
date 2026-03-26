#!/usr/bin/env python3
"""SmithMk Tapo Proxy v4 — python-kasa backend. NO HA.
Handles KLAP/AES/TPAP auth natively. Controls P100 plugs + L920 lightstrips.
Run on VM (192.168.1.47):
  pip install python-kasa flask --break-system-packages
  python3 kasa_proxy.py
"""
import asyncio
import json
import time
import threading
import traceback
from flask import Flask, request, jsonify

app = Flask(__name__)

# TP-Link cloud creds — used to seed KLAP handshake (comms stay local)
EMAIL = "smithmk@aussiebb.com.au"
PASSWORD = "MkS.9272103"

# Skip these IPs during scan
SKIP_IPS = {1, 47, 101, 203}  # router, VM, QNAP, Hue bridge

devices = {}  # ip -> dict
_loop = None  # shared asyncio loop for background thread
_device_cache = {}  # ip -> kasa Device object (reuse connections)


async def _get_device(ip: str):
    """Get or create a python-kasa device connection."""
    from kasa import Device, Credentials, DeviceConfig

    if ip in _device_cache:
        dev = _device_cache[ip]
        try:
            await dev.update()
            return dev
        except Exception:
            try:
                await dev.disconnect()
            except Exception:
                pass
            del _device_cache[ip]

    creds = Credentials(username=EMAIL, password=PASSWORD)
    dev = await Device.connect(config=DeviceConfig(host=ip, credentials=creds))
    _device_cache[ip] = dev
    return dev


def _device_to_dict(ip: str, dev) -> dict:
    """Convert a python-kasa device to our standard dict format."""
    from kasa import DeviceType

    is_plug = dev.device_type in (DeviceType.Plug, DeviceType.StripSocket)

    info = {
        'ip': ip,
        'nickname': dev.alias or ip,
        'model': dev.model or '',
        'type': 'SMART.TAPOPLUG' if is_plug else 'SMART.TAPOBULB',
        'isPlug': is_plug,
        'deviceOn': dev.is_on,
        'brightness': 0,
        'hue': 0,
        'saturation': 0,
        'colorTemp': 0,
        'reachable': True,
    }

    if not is_plug:
        if hasattr(dev, 'brightness') and dev.brightness is not None:
            info['brightness'] = dev.brightness
        if hasattr(dev, 'hsv') and dev.hsv:
            h, s, v = dev.hsv
            info['hue'] = h or 0
            info['saturation'] = s or 0
        if hasattr(dev, 'color_temp') and dev.color_temp:
            info['colorTemp'] = dev.color_temp

    return info


async def discover_devices():
    """Discover Tapo devices on the network using python-kasa."""
    from kasa import Discover, Credentials
    global devices

    print("[Tapo-Kasa] Discovering devices on network...")
    creds = Credentials(username=EMAIL, password=PASSWORD)

    try:
        found = await Discover.discover(credentials=creds, timeout=15)
        new_devices = {}
        for ip, dev in found.items():
            try:
                await dev.update()
                d = _device_to_dict(ip, dev)
                new_devices[ip] = d
                _device_cache[ip] = dev
                print(f"[Tapo-Kasa] Found: {d['nickname']} at {ip} ({d['model']}) on={d['deviceOn']}")
            except Exception as e:
                print(f"[Tapo-Kasa] Skip {ip}: {e}")

        if new_devices:
            devices = new_devices
        print(f"[Tapo-Kasa] Discovery complete: {len(devices)} devices")
    except Exception as e:
        print(f"[Tapo-Kasa] Discovery error: {e}")
        traceback.print_exc()

    # If discovery found nothing, try manual subnet scan
    if not devices:
        print("[Tapo-Kasa] Discovery empty — trying manual IP scan...")
        await _manual_scan()


async def _manual_scan():
    """Fallback: try connecting to each IP on the subnet."""
    global devices
    subnet = "192.168.1."

    async def try_ip(i):
        ip = f"{subnet}{i}"
        try:
            dev = await _get_device(ip)
            d = _device_to_dict(ip, dev)
            devices[ip] = d
            print(f"[Tapo-Kasa] Manual found: {d['nickname']} at {ip} ({d['model']})")
        except Exception:
            pass

    for batch_start in range(2, 255, 30):
        tasks = []
        for i in range(batch_start, min(batch_start + 30, 255)):
            if i in SKIP_IPS:
                continue
            tasks.append(try_ip(i))
        await asyncio.gather(*tasks, return_exceptions=True)


async def poll_devices():
    """Poll known devices for state updates."""
    global devices
    for ip in list(devices.keys()):
        try:
            dev = await _get_device(ip)
            devices[ip] = _device_to_dict(ip, dev)
        except Exception:
            if ip in devices:
                devices[ip]['reachable'] = False
            if ip in _device_cache:
                try:
                    await _device_cache[ip].disconnect()
                except Exception:
                    pass
                del _device_cache[ip]


def bg_loop():
    """Background thread running asyncio event loop for discovery/polling."""
    global _loop
    _loop = asyncio.new_event_loop()
    asyncio.set_event_loop(_loop)
    _loop.run_until_complete(discover_devices())
    while True:
        time.sleep(10)
        _loop.run_until_complete(poll_devices())


threading.Thread(target=bg_loop, daemon=True).start()


def _run_async(coro):
    """Run an async function on the background loop."""
    if _loop is None:
        raise Exception("Background loop not ready")
    future = asyncio.run_coroutine_threadsafe(coro, _loop)
    return future.result(timeout=15)


# ─── REST endpoints (same contract as old proxy) ───

@app.route('/api/tapo/devices')
def get_devices():
    return jsonify(devices)


@app.route('/api/tapo/discover', methods=['POST'])
def do_discover():
    try:
        _run_async(discover_devices())
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    return jsonify(devices)


@app.route('/api/tapo/on', methods=['POST'])
def turn_on():
    ip = request.json.get('ip')
    try:
        async def _on():
            dev = await _get_device(ip)
            await dev.turn_on()
            await dev.update()
            devices[ip] = _device_to_dict(ip, dev)
        _run_async(_on())
        return jsonify({'ok': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/tapo/off', methods=['POST'])
def turn_off():
    ip = request.json.get('ip')
    try:
        async def _off():
            dev = await _get_device(ip)
            await dev.turn_off()
            await dev.update()
            devices[ip] = _device_to_dict(ip, dev)
        _run_async(_off())
        return jsonify({'ok': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/tapo/brightness', methods=['POST'])
def set_brightness():
    ip = request.json.get('ip')
    bri = request.json.get('brightness', 50)
    try:
        async def _bri():
            dev = await _get_device(ip)
            await dev.set_brightness(int(bri))
            await dev.update()
            devices[ip] = _device_to_dict(ip, dev)
        _run_async(_bri())
        return jsonify({'ok': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.route('/api/tapo/colour', methods=['POST'])
def set_colour():
    ip = request.json.get('ip')
    hue = request.json.get('hue', 0)
    sat = request.json.get('saturation', 100)
    bri = request.json.get('brightness', 100)
    try:
        async def _col():
            dev = await _get_device(ip)
            await dev.set_hsv(int(hue), int(sat), int(bri))
            await dev.update()
            devices[ip] = _device_to_dict(ip, dev)
        _run_async(_col())
        return jsonify({'ok': True})
    except Exception as e:
        return jsonify({'error': str(e)}), 500


@app.after_request
def cors(response):
    response.headers['Access-Control-Allow-Origin'] = '*'
    response.headers['Access-Control-Allow-Headers'] = 'Content-Type'
    response.headers['Access-Control-Allow-Methods'] = 'GET,POST,OPTIONS'
    return response


if __name__ == '__main__':
    print("[Tapo-Kasa] Proxy v4 on :4500 — python-kasa, NO HA, direct local KLAP")
    app.run(host='0.0.0.0', port=4500)
