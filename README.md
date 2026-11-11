# SAA Core — PHASE 1 (Foundation)

الهدف من هذه المرحلة: **النظام يعمل بأمر واحد.** لا مصادقة، لا CRUD، لا Facebook، لا استدعاءات AI، لا واجهة.
الـ DDL هو نص D2b §3.2 حرفيًا: **31 جدولًا · 368 عمودًا · 40 مفتاحًا أجنبيًا · 5 قيود CHECK** — لم يُعدَّل ولا «يُحسَّن».

| المسار | المحتوى |
|---|---|
| `infra/docker-compose.yml` | الخدمات العشر من D7a §12 بصور مثبّتة الإصدار وفحص صحة لكل خدمة |
| `infra/nginx/nginx.conf` | المدخل العام الوحيد: 80 → 443، `location = /health` و `/health/ready` إلى `api:8000` |
| `backend/app/` | FastAPI: `/health` و `/health/ready` فقط، مع `worker.py` و `beat.py` (عناصر نائبة بلا مهام) |
| `backend/alembic/` | `env.py` + الترحيل الأساس `0001_baseline_phase0_ddl` الذي ينفّذ `alembic/sql/0001_baseline.sql` كما هو |
| `backend/alembic/sql/0001_baseline.sql` | نسخة بايت-ببايت من D2b §3.2 (33,876 بايت) |
| `scripts/verify.sh` | إعادة تنفيذ الاختبارات العشرة (13 فحصًا مُسمّى) على MySQL حقيقي |
| `scripts/gen-dev-certs.sh` | يولّد شهادة تطوير ذاتية (`CN=localhost` · 825 يومًا) في `infra/nginx/certs/` — **الشهادة لا تُشحن، السكربت يُشحن** |
| `.env.example` | **أسماء المتغيّرات فقط، بلا أي قيمة** |
| `.gitignore` | يتضمّن `.env` وشهادات TLS والمفاتيح |

## 1) التشغيل بأمر واحد

```bash
cp .env.example .env
bash scripts/gen-dev-certs.sh
docker compose --env-file .env -f infra/docker-compose.yml up -d --build
```

`bash scripts/gen-dev-certs.sh` لازم قبل أول إقلاع: `nginx` لا يقلع بلا `infra/nginx/certs/{fullchain,privkey}.pem`، ولا شهادة تُشحن في الحزمة. السكربت آمن التكرار (لا يولّد ثانية إلا بـ`--force`).

هذا الأمر يبني `api` ويشغّل: `nginx` · `api` · `worker-publish` · `worker-sync` · `worker-ai` · `beat` · `mysql` (8.4.6) · `redis` · `minio`.

ملاحظتان صريحتان:

- `web` معرّفة في الملف نفسه وتعمل بالأمر `docker compose --env-file .env -f infra/docker-compose.yml --profile web up -d` بعد أن يضع AGENT 2 مجلد `frontend/` (ORDER-05). حتى ذلك الحين تبقى خلف `profile` كي لا يفشل «الأمر الواحد». `frontend/` ليس ملكي ولم أُنشئه.
- `nginx` يقرأ `infra/nginx/certs/fullchain.pem` و`privkey.pem`. عند غيابهما لا يقلع nginx — الشهادات ليست ضمن التسليم (`.gitignore` يستثنيهم) و`gen-dev-certs.sh` يملأ الفراغ.
- `minio`: الصورة الرسمية `minio/minio` لم تعد قابلة للسحب مجهولًا (قياس موثَّق في السجل). الافتراضي المُشحَن `${MINIO_IMAGE:-coollabsio/minio:RELEASE.2025-10-15T17-29-55Z}` — نفس برنامج MinIO بنفس المنافذ 9000/9001، وقد تُحقّق من محتواه (وجود `/usr/bin/minio` و`/usr/bin/mc`). للعودة إلى الاسم الرسمي بعد `docker login quay.io`: `MINIO_IMAGE=quay.io/minio/minio:<tag>` في `.env`.

التحقق من الحالة:

```bash
docker compose --env-file .env -f infra/docker-compose.yml ps
```

## 2) التحقق بأمر واحد

```bash
# على TCP
MYSQL_HOST=127.0.0.1 MYSQL_PORT=3306 MYSQL_USER=root MYSQL_PASSWORD='***' bash scripts/verify.sh

# عبر Unix socket (كما جُرِّب فعليًا هنا)
MYSQL_BIN=/path/to/mysql MYSQL_SOCKET=/tmp/mysql.sock MYSQL_USER=root bash scripts/verify.sh
```

يطبع `PASS`/`FAIL` لكل فحص، ويخرج بـ `0` فقط إذا نجحت كلها. قاعدة الفحص `saa_verify` تُسقط وتُنشأ من جديد في كل تشغيل، ثم يُطبَّق عليها الترحيل عبر `alembic upgrade head` — أي أن الـ DDL يُختبر عبر Alembic لا عبر تحميل ملف منفصل.

الفحوص: 31 جدولًا · 368 عمودًا · 40 FK · CASCADE=37/RESTRICT=3 · 5 CHECK · `item_type` عشرة أنواع بالترتيب · `business_fact` ⇒ صف · `vocabulary` ⇒ 1265 · `confidence=1.5` ⇒ 3819 · موافقة ثانية مفتوحة ⇒ 1062 · workspace وهمي ⇒ 1452 · `DELETE workspaces` ⇒ كل الجداول صفرًا.

## 3) الفحص الصحي

```bash
curl -s http://127.0.0.1:8000/health
curl -s http://127.0.0.1:8000/health/ready
curl -sk https://127.0.0.1/health/ready   # عبر nginx بعد توفير الشهادة
```

`/healthz` على المنفذ 80 ترجع 200 نصًّا («nginx ok») قبل أي تحويل، وهي ما يفحصه `healthcheck` الخاص بـnginx.

`/health` ترجع دائمًا 200 مع لقطة للاعتماديات (`status`: `ok` أو `degraded`).
`/health/ready` ترجع 200 فقط عندما يجيب MySQL باستعلام `SELECT 1` ويجيب Redis بـ `PING` في تلك اللحظة، وإلا 503. لا تُقرأ أي قيمة من متغيّر بيئة للحكم على الجهوزية.

## 4) الإيقاف والتنظيف

```bash
docker compose --env-file .env -f infra/docker-compose.yml down        # إيقاف مع بقاء البيانات
docker compose --env-file .env -f infra/docker-compose.yml down -v     # حذف الحجوم (mysql/redis/minio) — لا رجعة
```

## 5) ما لا تفعله هذه المرحلة

لا مصادقة، لا نقاط CRUD، لا اتصال بـ Facebook، لا استدعاء AI، لا واجهة مستخدم، ولا تعديل على الـ DDL. المنافذ العامة: 80/443 فقط؛ `mysql` و`redis` و`minio` و`api` بلا نشر على المضيف (`expose` داخلي).
