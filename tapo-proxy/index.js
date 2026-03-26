// SmithMk Tapo Proxy v3 — LOCAL ONLY, NO HA, NO CLOUD
// Scans local network for Tapo devices, controls directly by IP.
const express = require('express');
const { loginDeviceByIp } = require('tp-link-tapo-connect');

const app = express();
app.use(express.json());
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type');
  res.header('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

const EMAIL = 'smithmk@aussiebb.com.au';
const PASSWORD = 'MkS.9272103';

let devices = {};

// Scan local network for Tapo devices
async function scanNetwork() {
  console.log('[Tapo] Scanning network for devices...');
  const subnet = '192.168.1.';
  
  for (let batch = 2; batch <= 254; batch += 30) {
    const promises = [];
    for (let i = batch; i < Math.min(batch + 30, 255); i++) {
      if (i === 47 || i === 101 || i === 203 || i === 1) continue;
      const ip = subnet + i;
      promises.push((async () => {
        try {
          const dev = await loginDeviceByIp(EMAIL, PASSWORD, ip);
          const info = await dev.getDeviceInfo();
          if (info && info.type) {
            const nickname = info.nickname ? Buffer.from(info.nickname, 'base64').toString('utf8') : ip;
            const isPlug = (info.type || '').includes('PLUG');
            devices[ip] = {
              ip, nickname, 
              type: info.type, model: info.model || '',
              isPlug,
              deviceOn: info.device_on || false,
              brightness: info.brightness || 0,
              hue: info.hue || 0,
              saturation: info.saturation || 0,
              colorTemp: info.color_temp || 0,
              reachable: true
            };
            console.log(`[Tapo] Found: ${nickname} at ${ip} (${info.model}) on=${info.device_on}`);
          }
        } catch (_) {}
      })());
    }
    await Promise.allSettled(promises);
  }
  console.log(`[Tapo] Scan complete: ${Object.keys(devices).length} devices`);
}

// Poll known devices
async function pollAll() {
  for (const [ip, dev] of Object.entries(devices)) {
    try {
      const local = await loginDeviceByIp(EMAIL, PASSWORD, ip);
      const info = await local.getDeviceInfo();
      dev.deviceOn = info.device_on || false;
      dev.brightness = info.brightness || 0;
      dev.hue = info.hue || 0;
      dev.saturation = info.saturation || 0;
      dev.colorTemp = info.color_temp || 0;
      dev.reachable = true;
    } catch { dev.reachable = false; }
  }
}

setInterval(pollAll, 10000);
setInterval(scanNetwork, 300000);

app.get('/api/tapo/devices', (req, res) => res.json(devices));
app.post('/api/tapo/discover', async (req, res) => { await scanNetwork(); res.json(devices); });

app.post('/api/tapo/on', async (req, res) => {
  try {
    const local = await loginDeviceByIp(EMAIL, PASSWORD, req.body.ip);
    await local.turnOn();
    const d = devices[req.body.ip]; if (d) d.deviceOn = true;
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/tapo/off', async (req, res) => {
  try {
    const local = await loginDeviceByIp(EMAIL, PASSWORD, req.body.ip);
    await local.turnOff();
    const d = devices[req.body.ip]; if (d) d.deviceOn = false;
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/tapo/brightness', async (req, res) => {
  try {
    const local = await loginDeviceByIp(EMAIL, PASSWORD, req.body.ip);
    await local.setBrightness(req.body.brightness);
    const d = devices[req.body.ip]; if (d) { d.brightness = req.body.brightness; d.deviceOn = true; }
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.post('/api/tapo/colour', async (req, res) => {
  try {
    const { ip, hue, saturation, brightness } = req.body;
    const local = await loginDeviceByIp(EMAIL, PASSWORD, ip);
    await local.setColour(hue, saturation, brightness);
    const d = devices[ip]; if (d) { d.hue = hue; d.saturation = saturation; d.brightness = brightness; d.deviceOn = true; }
    res.json({ ok: true });
  } catch (e) { res.status(500).json({ error: e.message }); }
});

app.listen(4500, '0.0.0.0', async () => {
  console.log('[Tapo] Proxy v3 on :4500 — NO HA, direct local only');
  await scanNetwork();
});
