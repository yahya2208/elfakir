-- 0003_ef_ownership.sql
-- يضمن أن كل كائن في ef مملوك لـ ef_owner، حتى للكائنات التي أُنشئت قبل إصلاح 0001.
-- idempotent: يعيد الترخيص عند الحاجة فقط.
-- ملاحظة: أسماء القيود لا تُؤهَّل بالمخطط (constraint x لا constraint ef.x)، وتعبيرات CHECK تستخدم الأعمدة عارية.

begin;

do $own$
declare
  r record;
begin
  for r in
    select c.oid::regclass as obj, c.relkind
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'ef'
       and c.relkind in ('r','p','v','m','S','f')
       and c.relowner <> (select oid from pg_roles where rolname = 'ef_owner')
  loop
    execute format('alter table %s owner to ef_owner', r.obj);
  end loop;

  for r in
    select p.oid::regprocedure as obj
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'ef'
       and p.proowner <> (select oid from pg_roles where rolname = 'ef_owner')
  loop
    execute format('alter function %s owner to ef_owner', r.obj);
  end loop;

  -- لا أنواع هنا: المجالات جداول، ولا enum في المرحلة 0 (قرار ممثل واحد)
end $own$;

-- الصلاحيات الافتراضية تُثبَّت للمالك الفعلي حتى لا تنفكّ الملكية عن الصلاحيات
alter default privileges for role ef_owner in schema ef
  revoke all on tables    from public, anon, authenticated;
alter default privileges for role ef_owner in schema ef
  revoke all on sequences from public, anon, authenticated;
alter default privileges for role ef_owner in schema ef
  revoke all on functions from public;

commit;
