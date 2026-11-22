// secret-scan.mjs — يفحص سطح الرفع فقط: كل ملف متتبَّع في HEAD.
// الملفات المستبعَدة بـ .gitignore لا تُرفع أصلًا، لذا لا تُفحص هنا؛
// المطلوب بدل ذلك أن يكون عددها المتتبَّع صفرًا. node tools/secret-scan.mjs [ref]
import { execSync } from 'node:child_process';

const ROOT = execSync('git rev-parse --show-toplevel', { encoding: 'utf8' }).trim();
const git = (cmd) => execSync(cmd, { encoding: 'utf8', cwd: ROOT, maxBuffer: 64 * 1024 * 1024 });

const ref = process.argv[2] ?? 'HEAD';
const files = git(`git ls-tree -r --name-only ${ref}`).split('\n').filter(Boolean);

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
let unreadable = [];
if (files.length === 0) {
  console.log('FAIL: صفر ملفات متتبَّعة — الفحص بلا محتوى لا يثبت شيئًا');
  process.exit(1);
}
for (const f of files) {
  for (const isForbidden of forbiddenTracked) {
    if (isForbidden(f)) {
      hits++;
      console.log(`FAIL ${f} — مسار ممنوع متتبَّع؛ لا يُرفع مهما كان محتواه نظيفًا`);
    }
  }
  let text;
  try {
    text = git(`git show ${ref}:${f}`);
  } catch {
    // الاستثناء قد يكون ثنائيًا أو خطأ مسار — يجب ألا يمر بصمت
    unreadable.push(f);
    continue;
  }
  for (const [label, re] of patterns) {
    const m = text.match(re);
    if (m) {
      hits++;
      console.log(`FAIL ${f} → ${label}: ${m[0].slice(0, 12)}…[مخفي — لا يُطبع]`);
    }
  }
}
const textual = unreadable.filter((f) => /\.(mjs|sql|json|ps1|yml|yaml|md|toml|gitignore|gitattributes|example|txt|ts|tsx|js)$/.test(f) || !/\./.test(f));
if (textual.length > 0) {
  hits++;
  console.log(`FAIL: ملفات نصية لم يُقرأ محتواها — الفحص غير مكتمل: ${textual.join(', ')}`);
}
console.log(hits === 0
  ? `PASS: ${files.length}/${files.length} ملفًا متتبَّعًا فُحص نصّها — صفر أثر للأسرار، وصفر مسارات ممنوعة`
  : `${hits} أثرًا — الرفع ممنوع حتى يُزال`);
process.exit(hits === 0 ? 0 : 1);
