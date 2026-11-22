// db-push.mjs — البوابة الوحيدة لتطبيق migrations على قاعدة بيانات EF.
// لا تطبَّق أي migration إلا عبر هذا الملف. أي مشروع غير ef-test مرفوض رفضًا تامًا.
// الاستخدام: EF_ALLOW_REMOTE_DDL=ef-test node tools/db-push.mjs [--dry-run]
import { readFileSync, existsSync } from 'node:fs';
import { execSync } from 'node:child_process';

const EF_TEST_REF = 'ycgfqwigogokjydnfzwf'; // ef-test فقط
const SECRET_FILE = 'C:/Users/lenovo/.ef-secrets/ef-test.env';
const REF_FILE = 'supabase/.temp/project-ref';

function die(msg) {
  console.error(`REFUSED: ${msg}`);
  process.exit(1);
}

const linked = existsSync(REF_FILE) ? readFileSync(REF_FILE, 'utf8').trim() : '';
if (linked !== EF_TEST_REF) die(`المشروع المرتبط هو "${linked || 'غير مرتبط'}" وليس ${EF_TEST_REF}. لا يُسمح بأي تنفيذ SQL خارج ef-test.`);
if (process.env.EF_ALLOW_REMOTE_DDL !== 'ef-test') die('موافقة صريحة مطلوبة: أعد التشغيل بـ EF_ALLOW_REMOTE_DDL=ef-test');

const dry = process.argv.includes('--dry-run');
if (!existsSync(SECRET_FILE)) die(`ملف السر المحلي غير موجود: ${SECRET_FILE}`);
const pw = readFileSync(SECRET_FILE, 'utf8').match(/^EF_TEST_DB_PASSWORD=(.*)$/m)?.[1]?.trim();
if (!pw) die('لم تُعثر على EF_TEST_DB_PASSWORD في ملف السر المحلي');

try {
  const out = execSync(`supabase db push ${dry ? '--dry-run' : `-p "${pw}"`} -o pretty`, { encoding: 'utf8', stdio: 'pipe' });
  console.log(out.split('\n').filter((l) => /Applying|would be applied|Finished|no changes|DRY|error|ERROR/i.test(l)).join('\n') || out);
} catch (e) {
  const msg = `${e.stdout || ''}${e.stderr || ''}`.split('\n').filter((l) => /error|ERROR|denied|failed/i.test(l)).join('\n');
  console.error(`PUSH FAILED:\n${msg || e.message}`);
  process.exit(1);
}
