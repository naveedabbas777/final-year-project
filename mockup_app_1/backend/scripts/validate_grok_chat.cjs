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

const messages = [
  { role: 'system', content: 'You are a test assistant.' },
  { role: 'user', content: 'Hello, please respond with a short greeting.' }
];

const payload = JSON.stringify({ model: env.GROK_MODEL || 'grok-4.3', messages, temperature: 0.7, max_tokens: Number(env.GROK_MAX_TOKENS) || 1024 });

const options = {
  method: 'POST',
  hostname: 'api.x.ai',
  path: '/v1/chat/completions',
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
    console.log('body:', body.slice(0, 4000));
  });
});
req.on('error', (e) => {
  console.error('request error', e.message);
});
req.write(payload);
req.end();
