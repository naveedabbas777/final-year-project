(async ()=>{
  const endpoints = ['/api/config/public','/api/users/me'];
  for (const p of endpoints) {
    const url = `http://localhost:5000${p}`;
    try {
      const res = await fetch(url);
      const text = await res.text();
      console.log('---', p, 'STATUS', res.status);
      console.log(text);
    } catch (e) {
      console.error('ERROR', p, e.message || e);
    }
    console.log('\n');
  }
})();
