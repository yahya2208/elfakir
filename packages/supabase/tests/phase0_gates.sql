-- phase0_gates.sql — أدلة المرحلة 0، تُقرأ من المحرك لا من الوصف
-- تُنفَّذ على ef-test فقط (pg/psql كـ postgres). لا كتابة إطلاقًا: selects فقط.

-- G0-1 ملكية الـ schema + لا كائن في ef يملكه غير ef_owner
select 'G0-1_schema_owner' as gate,
       (select nspowner::regrole::text from pg_namespace where nspname = 'ef') as value,
       case when (select nspowner::regrole::text from pg_namespace where nspname = 'ef') = 'ef_owner'
            then 'PASS' else 'FAIL' end as result;

select 'G0-2_foreign_owned_objects' as gate,
       count(*)::text as value,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result
  from pg_class c join pg_namespace n on n.oid = c.oid
 where n.nspname = 'ef' and c.relowner <> (select oid from pg_roles where rolname = 'ef_owner');

-- G0-3 صفر صلاحية كتابة لأي دور متّصل على أي جدول في ef (المرحلة 0: لا جداول ⇒ 0 ضمناً)
select 'G0-3_direct_dml_grants' as gate,
       count(*)::text as value,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result
  from information_schema.table_privileges tp
  join information_schema.tables t on t.table_schema = tp.table_schema and t.table_name = tp.table_name
 where tp.table_schema = 'ef'
   and tp.privilege_type in ('INSERT','UPDATE','DELETE')
   and tp.grantee in ('anon','authenticated','public','service_role');

-- G0-4 USAGE مُمنوحة للأدوار الستة فقط، ولا CREATE على الـ schema
select 'G0-4_schema_usage' as gate,
       string_agg(distinct a.grantee, ',' order by a.grantee) as value,
       case when bool_and(a.privilege_type = 'USAGE')
                 and count(distinct a.grantee) = 6
                 and bool_and(a.grantee in ('anon','authenticated','ef_staff','ef_admin','ef_courier','ef_worker'))
            then 'PASS' else 'FAIL' end as result
  from information_schema.usage_privileges a
 where a.object_schema = 'ef';

-- G0-5 لا كائن EF في public (عزل تام عن أي مشروع آخر)
select 'G0-5_ef_objects_in_public' as gate,
       count(*)::text as value,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result
  from pg_class c join pg_namespace n on n.oid = c.oid
 where n.nspname = 'public'
   and c.relname ~ '^(order_status_domain|order_transition_matrix|orders|order_items|inventory|products|categories|prices|payments|cash_)';

-- G0-6 لا حالة مختَرَعة ولا حالة يتيمة (منظور الانحراف نفسه)
select 'G0-6_status_drift' as gate,
       coalesce(string_agg(status, ','), 'none') as value,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result
  from ef.v_order_status_drift_bad;

-- G0-7 الأرقام المرجعية من المحرك (بديل كل عدّ يدوي سابق)
select 'G0-7_counts' as gate,
       (select count(*) from ef.order_status_domain)::text
       || ' statuses / ' ||
       (select count(*) from ef.order_transition_matrix)::text
       || ' transitions / ' ||
       (select count(*) from pg_class c join pg_namespace n on n.oid = c.oid
         where n.nspname = 'ef' and c.relkind = 'r')::text
       || ' tables' as value,
       'INFO' as result;

-- G0-8 لا انتقال من حالة طرفية (الموت ليس بوابة خروج)
select 'G0-8_no_exit_from_terminal' as gate,
       coalesce(string_agg(m.id::text, ','), 'none') as value,
       case when count(*) = 0 then 'PASS' else 'FAIL' end as result
  from ef.order_transition_matrix m
  join ef.order_status_domain f on f.status = m.from_status
 where f.is_terminal;
