-- phase0_gates.sql — أدلة المرحلة 0، تُقرأ من المحرك لا من الوصف.
-- تُنفَّذ على ef-test فقط. لا كتابة إطلاقًا: selects فقط.
-- تصحيح إلزامي بعد أول تشغيل: الربط الصحيح هو c.relnamespace (كان c.oid ⇒ نتائج فارغة «ناجحة» زورًا).

-- G0-1 ملكية الـ schema
select 'G0-1_schema_owner' as gate, nspowner::regrole::text as value,
       (nspowner::regrole::text = 'ef_owner') as pass
  from pg_namespace where nspname = 'ef';

-- G0-2 لا كائن في ef يملكه غير ef_owner
select 'G0-2_foreign_owned' as gate, count(*)::text as value, (count(*) = 0) as pass
  from (
    select c.oid
      from pg_class c join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'ef' and c.relkind in ('r','v','m','i','S','p')
       and c.relowner <> (select oid from pg_roles where rolname = 'ef_owner')
    union all
    select p.oid
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'ef'
       and p.proowner <> (select oid from pg_roles where rolname = 'ef_owner')
  ) foreign_owned;

-- G0-3 صفر صلاحية كتابة مباشرة لأي دور متّصل
select 'G0-3_direct_dml' as gate, count(*)::text as value, (count(*) = 0) as pass
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  cross join lateral aclexplode(c.relacl) a
 where n.nspname = 'ef' and c.relkind = 'r'
   and a.privilege_type in ('INSERT','UPDATE','DELETE')
   and (a.grantee = 0
        or a.grantee in (select oid from pg_roles where rolname in ('anon','authenticated','service_role')));

-- G0-4 USAGE للأدوار الستة فقط
select 'G0-4_usage' as gate,
       string_agg(distinct r.rolname, ',' order by r.rolname) as value,
       (count(distinct r.rolname) = 6 and bool_and(a.privilege_type = 'USAGE')
        and bool_and(r.rolname in ('anon','authenticated','ef_staff','ef_admin','ef_courier','ef_worker'))) as pass
  from pg_namespace n
  cross join lateral aclexplode(n.nspacl) a
  join pg_roles r on r.oid = a.grantee
 where n.nspname = 'ef' and r.rolname <> 'ef_owner';

-- G0-5 لا كائن EF في public
select 'G0-5_public_leak' as gate, count(*)::text as value, (count(*) = 0) as pass
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname ~ '^(order_|orders|inventory|products|categories|prices|payments|cash_|guest_|delivery_|saved_|rate_|outbox|device_|staff_|customers|addresses|telemetry|notifications)';

-- G0-6 لا حالة مختَرَعة ولا ميتة
select 'G0-6_status_drift' as gate,
       coalesce(string_agg(status, ','), 'none') as value, (count(*) = 0) as pass
  from ef.v_order_status_drift_bad;

-- G0-7 الأعداد المرجعية من المحرك
select 'G0-7_counts' as gate,
       ((select count(*) from ef.order_status_domain)::text || ' statuses / ' ||
        (select count(*) from ef.order_transition_matrix)::text || ' transitions / ' ||
        (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'ef' and c.relkind = 'r')::text || ' tables') as value,
       ((select count(*) from ef.order_status_domain) = 10
        and (select count(*) from ef.order_transition_matrix) = 14) as pass;

-- G0-8 لا خروج من حالة طرفية
select 'G0-8_terminal_exit' as gate,
       coalesce(string_agg(m.id::text, ','), 'none') as value, (count(*) = 0) as pass
  from ef.order_transition_matrix m
  join ef.order_status_domain f on f.status = m.from_status
 where f.is_terminal;

-- G0-9 لا زوج مكرر في المصفوفة
select 'G0-9_dup_pair' as gate,
       coalesce(string_agg(from_status || '->' || to_status, ','), 'none') as value,
       (count(*) = 0) as pass
  from (select from_status, to_status from ef.order_transition_matrix
         group by 1,2 having count(*) > 1) dup;
