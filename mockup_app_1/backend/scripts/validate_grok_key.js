const fs = require('fs');
const https = require('https');
const path = require('path');

function readEnv(envPath) {
  const raw = fs.readFileSync(envPath, 'utf8');
  const lines = raw.split(/\r?\n/);
  const env = {};
  for (const line of lines) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m) {
      let val = m[2];
      if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'"))) {
        val = val.slice(1, -1);
      }
      env[m[1]] = val;
    }
  }
  return env;
}

const envPath = path.join(__dirname, '..', '.env');
if (!fs.existsSync(envPath)) {
  console.error('.env not found at', envPath);
  process.exit(2);
}
const env = readEnv(envPath);
const key = env.GROK_API_KEY;
if (!key) {
  console.error('GROK_API_KEY not found in .env');
  process.exit(2);
}

const payload = JSON.stringify({ model: 'grok-4.3', input: 'Hello' });

const options = {
  method: 'POST',
  hostname: 'api.x.ai',
  path: '/v1/responses',
  headers: {
    'Authorization': `Bearer ${key}`,
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
  },
};

const req = https.request(options, (res) => {
  console.log('statusCode:', res.statusCode);
  let body = '';
  res.on('data', (chunk) => (body += chunk));
  res.on('end', () => {
    console.log('body:', body.slice(0, 2000));
  });
});
req.on('error', (e) => {
  console.error('request error', e.message);
});
req.write(payload);
req.end();
