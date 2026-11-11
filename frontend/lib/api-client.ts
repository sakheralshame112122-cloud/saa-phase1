export type HealthPayload = {
  status?: unknown;
  service?: unknown;
  version?: unknown;
  uptime_seconds?: unknown;
  checks?: unknown;
  mysql?: unknown;
  database?: unknown;
  redis?: unknown;
};

export async function getHealth(): Promise<HealthPayload> {
  const response = await fetch("/api/v1/health", {
    method: "GET",
    headers: { accept: "application/json" },
    cache: "no-store",
  });

  if (!response.ok) {
    throw new Error("API_UNAVAILABLE");
  }

  const payload: unknown = await response.json();
  if (typeof payload !== "object" || payload === null || Array.isArray(payload)) {
    throw new Error("INVALID_HEALTH_RESPONSE");
  }

  return payload as HealthPayload;
}
