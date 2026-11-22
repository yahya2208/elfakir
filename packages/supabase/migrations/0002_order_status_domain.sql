-- 0002_order_status_domain.sql
-- المرجع الوحيد لحالات الطلب وانتقالاته: جدول المجال + جدول مصفوفة الانتقالات.
-- لا ENUM، ولا قائمة قيم داخل CHECK، ولا نسخة ثانية من الحالات في أي مكان آخر.
-- حالات الأجهزة (du_state_domain) ليست هنا: مصدرها مواصفات الأجهزة، وتُنشأ في المرحلة 3.

begin;

create table ef.order_status_domain (
  status       text    not null primary key,
  is_terminal  boolean not null,
  ord          smallint not null,
  constraint ef.ords_name_fmt     check (ef.status ~ '^[a-z][a-z0-9_]{1,30}$'),
  constraint ef.ords_ord_positive check (ef.ord >= 1),
  constraint ef.ords_ord_unique   unique (ef.ord)
);

-- مصفوفة الانتقالات المعتمدة (الشريحة 1). كل سطر = انتقال واحد مسموح.
create table ef.order_transition_matrix (
  id           smallint not null primary key,
  from_status  text     not null references ef.order_status_domain (status) on delete restrict,
  to_status    text     not null references ef.order_status_domain (status) on delete restrict,
  actor_kind   text     not null,
  guard_code   text     null,
  constraint ef.otm_id_positive    check (ef.id >= 1),
  constraint ef.otm_no_self        check (ef.from_status <> ef.to_status),
  constraint ef.otm_actor_domain   check (ef.actor_kind in ('customer','staff','courier','admin','system')),
  constraint ef.otm_guard_fmt      check (ef.guard_code is null or ef.guard_code ~ '^[A-Z][A-Z0-9_]{2,50}$'),
  constraint ef.otm_unique_pair    unique (ef.from_status, ef.to_status)
);

insert into ef.order_status_domain (status, is_terminal, ord) values
  ('pending',           false, 1),
  ('confirmed',         false, 2),
  ('preparing',         false, 3),
  ('ready',             false, 4),
  ('assigned',          false, 5),
  ('out_for_delivery',  false, 6),
  ('delivered',         false, 7),
  ('failed_delivery',   false, 8),
  ('cancelled',         true,  9),
  ('refunded',          true, 10);

insert into ef.order_transition_matrix (id, from_status, to_status, actor_kind, guard_code) values
  (1,  'pending',          'confirmed',        'staff',    null),
  (2,  'pending',          'cancelled',        'customer', null),
  (3,  'confirmed',        'preparing',        'staff',    null),
  (4,  'confirmed',        'cancelled',        'staff',    null),
  (5,  'preparing',        'ready',            'staff',    null),
  (6,  'preparing',        'cancelled',        'staff',    null),
  (7,  'ready',            'assigned',         'staff',    null),
  (8,  'ready',            'cancelled',        'staff',    null),
  (9,  'assigned',         'out_for_delivery', 'courier',  'ATTEMPT_LIMIT_REACHED'),
  (10, 'out_for_delivery', 'delivered',        'courier',  'DELIVERY_BLOCKED_UNSETTLED'),
  (11, 'out_for_delivery', 'failed_delivery',  'courier',  'FAILURE_REASON_REQUIRED'),
  (12, 'failed_delivery',  'assigned',         'staff',    'ATTEMPT_LIMIT_REACHED'),
  (13, 'failed_delivery',  'cancelled',        'staff',    null),
  (14, 'delivered',        'refunded',         'admin',    'REFUND_CAP_EXCEEDED');

-- لا حالة يتيمة: كل حالة في المجال تظهر في الانتقالات (أو مُعلَّمة طرفية صراحة)
create view ef.v_order_status_drift as
select d.status,
       d.is_terminal,
       (count(m.id) filter (where m.from_status = d.status)) as outgoing,
       (count(m.id) filter (where m.to_status   = d.status)) as incoming
  from ef.order_status_domain d
  left join ef.order_transition_matrix m on m.from_status = d.status or m.to_status = d.status
 group by d.status, d.is_terminal, d.ord
 order by d.ord;

-- بوابة الاعتماد: أي سطر أدناه = كائن غير قابل للوصول أو حالة مُختَرَعة ⇒ يفشل الفحص
create view ef.v_order_status_drift_bad as
select * from ef.v_order_status_drift
 where outgoing = 0 and incoming = 0
    or (is_terminal and incoming = 0)
    or (not is_terminal and outgoing = 0);

commit;
