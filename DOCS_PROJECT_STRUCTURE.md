# هيكل المشروع — El Fakir (مخطط للمرحلة الثانية)

هذا المستند يصف هيكل المجلدات المخطط للتطبيق. لم يتم تنفيذه بعد.

## جذر المشروع

```
el-fakir/
├── README.md                          # وصف المشروع وتعليمات البداية
├── DOCS_ENGINEERING_ANALYSIS.md       # الوثيقة الهندسية الموحدة (المرحلة 1)
├── DOCS_DECISIONS_REPORT.md           # تقرير القرارات غير المحسومة (المرحلة 1)
├── DOCS_PROJECT_STRUCTURE.md          # هذا الملف
├── .env.example                       # مثال على المتغيرات البيئية (بدون أسرار)
├── .gitignore                         # ملفات ومجلدات مستثناة من Git
├── package.json                       # سكريبتات الجذر (إذا كان مونوريبو)
├── pnpm-workspace.yaml                # إعداد workspace (اختياري)
├── turbo.json                         # إذا تم استخدام Turborepo (اختياري)
├── apps/
│   ├── web/                           # واجهة الزبون (React + TypeScript + Vite)
│   │   ├── src/
│   │   │   ├── components/            # مكونات مشتركة (زر، بطاقة منتج، سلة، إلخ)
│   │   │   ├── pages/                 # صفحات الزبون (الرئيسية، السلة، تأكيد الطلب، إلخ)
│   │   │   ├── services/              # طبقة الخدمات (استدعاءات Supabase)
│   │   │   ├── store/                 # Zustand stores (السلة، المصادقة، إلخ)
│   │   │   ├── hooks/                 # هوكات مخصصة
│   │   │   ├── lib/                   # إعداد Supabase، utilitaires
│   │   │   ├── types/                 # أنواع TypeScript مشتركة
│   │   │   └── utils/                 # دوال مساعدة (تنسيق أسعار، إلخ)
│   │   ├── index.html
│   │   ├── vite.config.ts
│   │   ├── tsconfig.json
│   │   └── package.json
│   └── admin/                         # لوحة الإدارة (React + TypeScript + Vite)
│       ├── src/
│       │   ├── components/
│       │   ├── pages/
│       │   ├── services/
│       │   ├── store/
│       │   ├── hooks/
│       │   ├── lib/
│       │   ├── types/
│       │   └── utils/
│       ├── index.html
│       ├── vite.config.ts
│       ├── tsconfig.json
│       └── package.json
├── packages/
│   ├── shared/                        # أنواع مشتركة، ثوابت، دو مساعدة تُستخدم في web و admin
│   │   ├── types.ts
│   │   ├── constants.ts
│   │   └── utils.ts
│   └── supabase/                      #igrations، دوال قاعدة البيانات، سياسات RLS
│       ├── migrations/
│       │   ├── 001_initial_schema.sql
│       │   ├── 002_rls_policies.sql
│       │   └── 003_seed_settings.sql
│       ├── functions/                 # Supabase Edge Functions (عمليات ذرية، تسوية مالية)
│       │   ├── create-order/
│       │   ├── settle-payment/
│       │   └── release-inventory/
│       ├── policies/                  # تعريفات سياسات RLS لكل جدول
│       └── seed/                      # بيانات أولية (تصنيفات، وحدات، مناطق توصيل)
├── docs/
│   └── api/                           # توثيق واجهات API (يُضاف لاحقًا)
└── tests/
    └── e2e/                         # سيناريوهات الرحلة الكاملة (Playwright)
        ├── customer-flow.spec.ts
        ├── admin-flow.spec.ts
        └── courier-flow.spec.ts
```

## مبادئ命名

- المجلدات: kebab-case (`product-images`, `order-status-history`)
- الملفات: kebab-case (`product-card.tsx`, `use-cart.ts`)
- المكونات React: PascalCase (`ProductCard.tsx`, `OrderStatusBadge.tsx`)
- الأنواع TypeScript: PascalCase (`Product`, `Order`, `CustomerAddress`)
- دوال base في Supabase: snake_case (`create_order`, `settle_payment`)
- جداول قاعدة البيانات: snake_case جمع (`orders`, `order_items`, `inventory_movements`)

## ملاحظات أمنية

- لا تُضاف أي مفاتيح سرية (Service Role Keys) إلى ملفات أمام العميل.
- ملف `.env` الفعلي يُضاف إلى `.gitignore` ولا يُرفق إلى مستودع الكود.
- جميع المتغيرات التي تبدأ بـ `VITE_` تُعرض لمستعرض الويب، لذا يجب ألا تحتوي على أسرار.

## الخطوة التالية

بعد اعتماد المرحلة 1 من صاحب المشروع، يتم:
1. إنشاء المجلدات والملفات أعلاه.
2. تهيئة проект React + TypeScript + Vite في `apps/web`.
3. إعداد مشروع Supabase جديد في لوحة التحكم.
4. كتابة migration初始ية وجداول قاعدة البيانات وسياسات RLS.
