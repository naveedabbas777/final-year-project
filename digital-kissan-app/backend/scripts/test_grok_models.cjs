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

const modelsToTest = ['grok-2', 'grok-3', 'grok-l', env.GROK_MODEL || 'grok-4.3'];

async function testModel(model) {
  return new Promise((resolve) => {
    const messages = [
      { role: 'system', content: 'You are a concise test assistant.' },
      { role: 'user', content: 'Say hi in one short sentence.' }
    ];

    const payload = JSON.stringify({ model, messages, temperature: 0.2, max_tokens: 60 });

    const options = {
      method: 'POST',
      hostname: 'api.x.ai',
      path: '/v1/chat/completions',
      headers: {
        'Authorization': `Bearer ${key}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
      timeout: 20000,
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        resolve({ model, status: res.statusCode, body });
      });
    });
    req.on('error', (e) => resolve({ model, error: e.message }));
    req.on('timeout', () => {
      req.destroy();
      resolve({ model, error: 'timeout' });
    });
    req.write(payload);
    req.end();
  });
}

(async () => {
  for (const m of modelsToTest) {
    console.log('--- Testing', m, '---');
    // eslint-disable-next-line no-await-in-loop
    const r = await testModel(m);
    if (r.error) {
      console.log('error:', r.error);
    } else {
      console.log('status:', r.status);
      console.log('body:', r.body.slice(0, 2000));
    }
    console.log('');
  }
})();
