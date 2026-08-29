// carao-server.js — สะพานระหว่างหน้า CARAO กับเครื่อง: GET /morning -> รัน morning.ps1 แล้วปิดหน้า kiosk
const http = require('http');
const { exec } = require('child_process');

const PS = 'powershell -NoProfile -ExecutionPolicy Bypass -File';

http.createServer((req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  if (req.url === '/morning') {
    exec(`pwsh -NoProfile -ExecutionPolicy Bypass -File C:\\Users\\watch\\morning\\morning.ps1 -Quiet`);
    setTimeout(() => exec(`${PS} C:\\Users\\watch\\morning\\close-carao.ps1`), 4000);
    res.end('ok');
  } else {
    res.end('carao');
  }
}).on('error', () => process.exit(0)) // มีตัวเก่ารันอยู่แล้ว (พอร์ตชน) ก็จบเงียบ ๆ
  .listen(8930, '127.0.0.1');
