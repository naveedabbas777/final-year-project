const https = require('https');
const [,, key, model, ...msgParts] = process.argv;
if (!key || !model || msgParts.length === 0) {
  console.error('Usage: node run_groq_request.cjs <API_KEY> <MODEL> <MESSAGE>');
  process.exit(2);
}
const message = msgParts.join(' ');
const payload = JSON.stringify({ model, messages: [{ role: 'user', content: message }] });

const options = {
  method: 'POST',
  hostname: 'api.groq.com',
  path: '/openai/v1/chat/completions',
  headers: {
    'Authorization': `Bearer ${key}`,
    'Content-Type': 'application/json',
    'Content-Length': Buffer.byteLength(payload),
  },
  timeout: 20000,
};

const req = https.request(options, (res) => {
  console.log('statusCode:', res.statusCode);
  let body = '';
  res.on('data', (c) => body += c);
  res.on('end', () => console.log('body:', body));
});
req.on('error', (e) => console.error('request error', e.message));
req.write(payload);
req.end();
