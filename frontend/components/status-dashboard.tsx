"use client";

import { useEffect, useRef, useState } from "react";
import { getHealth, type HealthPayload } from "@/lib/api-client";

type Tone = "healthy" | "degraded" | "failed" | "unknown";
type ServiceState = { label: string; tone: Tone };
type ViewState =
  | { phase: "loading" }
  | { phase: "error"; checkedAt: string }
  | { phase: "success"; payload: HealthPayload; checkedAt: string };

type HealthValue = string | { status?: unknown } | null | undefined;

function isoRiyadhNow(): string {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Asia/Riyadh",
    numberingSystem: "latn",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(new Date());
  const part = (type: Intl.DateTimeFormatPartTypes) => parts.find((item) => item.type === type)?.value ?? "00";
  return `${part("year")}-${part("month")}-${part("day")}T${part("hour")}:${part("minute")}:${part("second")}+03:00`;
}

function statusFromValue(value: HealthValue): ServiceState {
  let raw: string | undefined;
  if (typeof value === "string") raw = value;
  if (typeof value === "object" && value !== null && "status" in value && typeof value.status === "string") {
    raw = value.status;
  }

  if (!raw) return { label: "غير متاح في استجابة /health", tone: "unknown" };
  const normalized = raw.trim().toLowerCase();
  if (["ok", "healthy", "ready", "up", "connected"].includes(normalized)) {
    return { label: "سليم", tone: "healthy" };
  }
  if (["degraded", "partial", "warning"].includes(normalized)) {
    return { label: "متدهور", tone: "degraded" };
  }
  if (["error", "down", "unhealthy", "failed", "disconnected", "unavailable"].includes(normalized)) {
    return { label: "غير سليم", tone: "failed" };
  }
  return { label: raw, tone: "unknown" };
}

function checkValue(payload: HealthPayload, name: "mysql" | "redis"): HealthValue {
  const checks = payload.checks;
  if (typeof checks === "object" && checks !== null && name in checks) {
    return (checks as Record<string, HealthValue>)[name];
  }
  if (name === "mysql" && "database" in payload) return payload.database as HealthValue;
  return payload[name] as HealthValue;
}

function uptimeMeasurement(value: unknown): string {
  if (typeof value !== "number" || !Number.isSafeInteger(value) || value < 0) {
    return "زمن التشغيل: غير متاح";
  }
  return `زمن التشغيل: ${new Intl.NumberFormat("en-US").format(value)} ثانية`;
}

function serviceRows(payload: HealthPayload) {
  return [
    { name: "واجهة API", detail: "مصدر الحالة: /health", measurement: uptimeMeasurement(payload.uptime_seconds), state: statusFromValue(payload.status as HealthValue) },
    { name: "قاعدة البيانات", detail: "تُعرض فقط إذا وردت في /health", measurement: null, state: statusFromValue(checkValue(payload, "mysql")) },
    { name: "Redis", detail: "تُعرض فقط إذا وردت في /health", measurement: null, state: statusFromValue(checkValue(payload, "redis")) },
  ];
}

function ServiceIcon({ tone }: { tone?: Tone }) {
  return (
    <span className={`service-icon ${tone ? `service-icon--${tone}` : "service-icon--loading"}`} aria-hidden="true">
      {tone === "healthy" ? (
        <svg viewBox="0 0 24 24" focusable="false"><path d="m6 12.5 4 4L18.5 8" /></svg>
      ) : tone === "failed" ? (
        <svg viewBox="0 0 24 24" focusable="false"><path d="M12 7v5m0 4h.01M4.9 19h14.2a1.3 1.3 0 0 0 1.12-1.95L13.12 4.9a1.3 1.3 0 0 0-2.24 0L3.78 17.05A1.3 1.3 0 0 0 4.9 19Z" /></svg>
      ) : (
        <span className="service-icon__dot" />
      )}
    </span>
  );
}

function StatusBadge({ state }: { state: ServiceState }) {
  return (
    <span className={`status-badge status-badge--${state.tone}`}>
      <span className="status-badge__dot" aria-hidden="true" />
      {state.label}
    </span>
  );
}

function StatusRows({ state }: { state: ViewState }) {
  const rows = state.phase === "success" ? serviceRows(state.payload) : [
    { name: "واجهة API", detail: "مصدر الحالة: /health", measurement: state.phase === "error" ? "زمن التشغيل: غير متاح" : null, state: state.phase === "error" ? { label: "تعذّر الوصول", tone: "failed" as const } : null },
    { name: "قاعدة البيانات", detail: "من استجابة /health فقط", measurement: null, state: state.phase === "error" ? { label: "لم تُقرأ الحالة", tone: "unknown" as const } : null },
    { name: "Redis", detail: "من استجابة /health فقط", measurement: null, state: state.phase === "error" ? { label: "لم تُقرأ الحالة", tone: "unknown" as const } : null },
  ];

  return (
    <div className={`service-list ${state.phase === "loading" ? "service-list--loading" : ""}`} aria-label="حالات الخدمات">
      {rows.map((row) => (
        <div className="service-row" key={row.name}>
          <ServiceIcon tone={row.state?.tone} />
          <div className="service-row__copy">
            <span className="service-row__name">{row.name}</span>
            <span className="service-row__detail">{row.detail}</span>
            {row.measurement && <span className="service-row__measurement numeric-measure">{row.measurement}</span>}
          </div>
          {row.state ? <StatusBadge state={row.state} /> : <span className="loading-skeleton" aria-hidden="true" />}
        </div>
      ))}
    </div>
  );
}

export default function StatusDashboard() {
  const [view, setView] = useState<ViewState>({ phase: "loading" });
  const started = useRef(false);

  useEffect(() => {
    if (started.current) return;
    started.current = true;
    getHealth().then(
      (payload) => setView({ phase: "success", payload, checkedAt: isoRiyadhNow() }),
      () => setView({ phase: "error", checkedAt: isoRiyadhNow() }),
    );
  }, []);

  return (
    <div className="app-shell" dir="rtl">
      <aside className="sidebar" aria-label="التنقل الرئيسي">
        <div className="brand-lockup">
          <span className="brand-mark" aria-hidden="true"><span /></span>
          <span className="brand-name">مركز النظام</span>
        </div>
        <nav className="sidebar-nav" aria-label="القائمة">
          <a className="sidebar-link sidebar-link--active" href="/status" aria-current="page">
            <svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M4 13h6V4H4v9Zm10 7h6V11h-6v9ZM4 20h6v-3H4v3Zm10-13h6V4h-6v3Z" /></svg>
            <span>حالة الخدمات</span>
          </a>
        </nav>
        <div className="sidebar-footnote">واجهة الأساس</div>
      </aside>

      <div className="workspace">
        <header className="topbar">
          <span className="topbar__section">مراقبة الخدمة</span>
          <span className="source-pill"><span className="source-pill__dot" />مصدر مباشر</span>
        </header>

        <main className="main-content">
          <div className="page-heading">
            <div>
              <p className="eyebrow">الأساس · صحة الخدمة</p>
              <h1>حالة الخدمات</h1>
              <p className="page-description">قراءة الحالة من واجهة الصحة؛ لا تُعرض بيانات غير موجودة في الاستجابة.</p>
            </div>
            <div className="health-mark" aria-hidden="true">
              <svg viewBox="0 0 24 24" focusable="false"><path d="M3 12h4l2.2-6 4.1 12 2.2-6H21" /></svg>
            </div>
          </div>

          <section className="health-panel" aria-labelledby="health-title" aria-busy={view.phase === "loading"}>
            <div className="panel-heading">
              <div>
                <h2 id="health-title">مؤشرات الاتصال</h2>
                <p>تُقرأ الخدمات الثلاث من استجابة <code>/health</code> وحدها.</p>
              </div>
              <span className="panel-accent" aria-hidden="true" />
            </div>

            {view.phase === "loading" && (
              <p className="live-message" role="status" aria-live="polite">جارٍ تحميل الحالة من واجهة API…</p>
            )}
            {view.phase === "error" && (
              <div className="error-message" role="alert">
                <span className="error-message__mark" aria-hidden="true">!</span>
                <div><strong>تعذّر الوصول إلى الـAPI</strong><span>لم تصل استجابة من /health؛ لم تُجرَ فحوص مباشرة للخدمات التابعة.</span></div>
              </div>
            )}
            {view.phase === "success" && (
              <p className="live-message live-message--success" role="status" aria-live="polite">وصلت استجابة /health.</p>
            )}

            <StatusRows state={view} />

            {view.phase !== "loading" && (
              <div className="checked-at">
                <span>آخر فحص</span>
                <time className="numeric-time" dateTime={view.checkedAt}>{view.checkedAt}</time>
              </div>
            )}
          </section>

          <p className="page-footnote">المصدر الوحيد: <code>GET /health</code> عبر طبقة استدعاء الواجهة.</p>
        </main>
      </div>
    </div>
  );
}
