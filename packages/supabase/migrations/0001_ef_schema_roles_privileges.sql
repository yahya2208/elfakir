-- 0001_ef_schema_roles_privileges.sql
-- EF (الفقير) — الشريحة الرأسية، المرحلة 0
-- مصدر واحد للحماية: لا DML لأي دور متّصل على جداول ef. الكتابة فقط عبر RPC (تُضاف لاحقًا).
-- تحذير: لا ENUM هنا. مجالات الحالات جداول، مصدرها مصفوفة الانتقالات (0002).

begin;

-- 1) الأدوار: NOLOGIN، بلا صلاحية تسجيل دخول
do $$
declare r text;
begin
  foreach r in array array['ef_owner','ef_staff','ef_admin','ef_courier','ef_worker']
  loop
    if not exists (select 1 from pg_roles where rolname = r) then
      execute format('create role %I nologin nopassword', r);
    end if;
  end loop;
end $$;

-- يلزم ليتمكن postgres من إنشاء كائنات مملوكة لـ ef_owner داخل migrations
grant ef_owner to postgres;

-- 2) الـ schema المستقل: EF لا يسكن public ولا يلامس أي مشروع آخر
create schema if not exists ef authorization ef_owner;

revoke all on schema ef from public;

-- USAGE فقط: لا إنشاء جداول من الواجهة، ولا write مباشر
grant usage on schema ef to anon, authenticated, ef_staff, ef_admin, ef_courier, ef_worker;

-- 3) الصلاحيات الافتراضية للكائنات القادمة — تُثبَّت قبل وجود أي جدول
alter default privileges for role ef_owner in schema ef
  revoke all on tables    from public, anon, authenticated;
alter default privileges for role ef_owner in schema ef
  revoke all on sequences from public, anon, authenticated;
alter default privileges for role ef_owner in schema ef
  revoke all on functions from public;

-- لا GRANT EXECUTE عام: كل callable تُمنح صراحةً حسب الدور في migration الخاص بها.

-- 4) بوابة المرحلة 0 (تُطبَّق من pg_catalog في نهاية المرحلة، لا من هذا التعليق):
--    a) صفر صلاحية INSERT/UPDATE/DELETE لـ anon/authenticated على أي جدول في ef
--    b) لا كائن في ef مملوك لغير ef_owner
--    c) public لا يحتوي أي كائن يخص EF

commit;
