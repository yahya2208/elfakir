// run_sql.mjs — يشغّل SQL على ef-test عبر واجهة إدارة Supabase، ويطبع الخطأ الحقيقي.
// الاستخدام: node run_sql.mjs <file.sql>   |   node run_sql.mjs --inline "select 1"
// لا يطبع أي مفتاح. يقرأ ~/.supabase/access-token فقط.
import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const REF = 'ycgfqwigogokjydnfzwf'; // ef-test
const token = readFileSync(join(homedir(), '.supabase', 'access-token'), 'utf8').trim();

const sql = process.argv[2] === '--inline' ? process.argv[3] : readFileSync(process.argv[2], 'utf8');

const res = await fetch(`https://api.supabase.com/v1/projects/${REF}/database/query`, {
  method: 'POST',
  headers: {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  },
  body: JSON.stringify({ query: sql }),
});

const text = await res.text();
console.log(`HTTP ${res.status}`);
console.log(text.length > 4000 ? text.slice(0, 4000) + '\n…[مقتطع]' : text);
