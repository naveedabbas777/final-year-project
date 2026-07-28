import process from 'node:process';

async function run() {
  const targets = [
    ['public-config', 'http://localhost:5000/api/config/public'],
    ['admin-overview', 'http://localhost:5000/api/admin/overview'],
  ];

  for (const [label, url] of targets) {
    const res = await fetch(url);
    const body = await res.text();
    console.log(`--- ${label} ${res.status}`);
    console.log(body);
    console.log('');
  }
}

run().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
