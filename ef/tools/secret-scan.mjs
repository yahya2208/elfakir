// secret-scan.mjs — يفحص سطح الرفع فقط: كل ملف متتبَّع في HEAD.
// الملفات المستبعَدة بـ .gitignore لا تُرفع أصلًا، لذا لا تُفحص هنا؛
// المطلوب بدل ذلك أن يكون عددها المتتبَّع صفرًا. node tools/secret-scan.mjs [ref]
import { execSync } from 'node:child_process';

const ref = process.argv[2] ?? 'HEAD';
const files = execSync(`git ls-tree -r --name-only ${ref}`, { encoding: 'utf8' }).split('\n').filter(Boolean);

const patterns = [
  ['service_role key', /\bsb_secret_[A-Za-z0-9_\-]{10,}|"role"\s*:\s*"service_role"/],
  ['JWT (أي مفتاح عام/خاص)', /\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}/],
  ['CLI access token', /\bsbp_[A-Za-z0-9]{20,}/],
  ['مفتاح API صريح', /(anon[_-]?key|apikey|api_key|supabase_key)\s*[:=]\s*['"][A-Za-z0-9_\-]{20,}['"]/i],
  ['كلمة مرور في نص', /(password|passwd|pwd)\s*[:=]\s*['"][^'"\s]{8,}['"]/i],
  ['connection string بمستخدم', /postgres(ql)?:\/\/[A-Za-z0-9_.\-]+:[^@'"\s]+@/i],
  ['مفتاح خاص', /-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----/],
];

// أي مسار يجب ألا يكون متتبَّعًا إطلاقًا (القوالب المستثنَدة لا تحوي أسرارًا)
const isTemplate = /\.env\.(example|template|sample)$/i;
const forbiddenTracked = [
  (f) => f.endsWith('.env') || (/\.env\./.test(f) && !isTemplate.test(f)),
  (f) => /(^|\/)service-account\.json$/i.test(f),
  (f) => /(^|\/)\.temp\//.test(f),
  (f) => /(^|\/)\.ef-secrets\//.test(f),
];

let hits = 0;
for (const f of files) {
  for (const isForbidden of forbiddenTracked) {
    if (isForbidden(f)) {
      hits++;
      console.log(`FAIL ${f} — مسار ممنوع متتبَّع؛ لا يُرفع مهما كان محتواه نظيفًا`);
    }
  }
  let text;
  try {
    text = execSync(`git show ${ref}:${f}`, { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  } catch {
    continue; // ملفات ثنائية
  }
  for (const [label, re] of patterns) {
    const m = text.match(re);
    if (m) {
      hits++;
      console.log(`FAIL ${f} → ${label}: ${m[0].slice(0, 12)}…[مخفي — لا يُطبع]`);
    }
  }
}
console.log(hits === 0
  ? `PASS: ${files.length} ملفًا متتبَّعًا — صفر أثر للأسرار، وصفر مسارات ممنوعة`
  : `${hits} أثرًا — الرفع ممنوع حتى يُزال`);
process.exit(hits === 0 ? 0 : 1);
