// gates.mjs — يشغّل أدلة مرحلة على ef-test ويطبع الناتج الحرفي للمحرك.
// الاستخدام: node tools/gates.mjs tools/phase0_gates.json
// المفتاح يُقرأ من token.ps1 (Credential Manager) ولا يُطبع ولا يُكتب في أي ملف.
import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

const REF = 'ycgfqwigogokjydnfzwf'; // ef-test — مشروع اختباري مستقل، لا إنتاج ولا FOCUS
const PS = 'C:/Windows/System32/WindowsPowerShell/v1.0/powershell.exe';
const token = execSync(`"${PS}" -NoProfile -ExecutionPolicy Bypass -File tools/token.ps1`, { encoding: 'utf8' }).trim();
if (!token) throw new Error('لم يُعثر على access-token — نفّذ supabase login أولًا');

export async function sql(query) {
  const res = await fetch(`https://api.supabase.com/v1/projects/${REF}/database/query`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ query }),
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`HTTP ${res.status}: ${text.slice(0, 800)}`);
  return JSON.parse(text);
}

const file = process.argv[2];
if (!file) throw new Error('حدّد ملف الأدلة: node tools/gates.mjs tools/phase0_gates.json');
let fails = 0;
for (const g of JSON.parse(readFileSync(file, 'utf8'))) {
  try {
    const rows = await sql(g.sql);
    const out = JSON.stringify(rows);
    const pass = rows.length > 0 && rows.every((r) => r.pass === true);
    if (!pass) fails++;
    console.log(`${pass ? 'PASS' : 'FAIL'}  ${g.id}  ${g.title}`);
    console.log(`      ${out.length > 900 ? out.slice(0, 900) + ' …[مقتطع]' : out}`);
  } catch (e) {
    fails++;
    console.log(`ERROR ${g.id}  ${g.title}`);
    console.log(`      ${e.message}`);
  }
}
console.log(`\nالحصيلة: ${fails === 0 ? 'كل الأدلة مغلقة' : fails + ' دليلًا لم يُغلق'}`);
process.exit(fails === 0 ? 0 : 1);
