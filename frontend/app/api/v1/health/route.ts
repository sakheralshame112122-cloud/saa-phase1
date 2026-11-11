import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET() {
  const apiBase = process.env.API_BASE_URL;

  if (!apiBase) {
    return NextResponse.json(
      { error: "API_BASE_URL_NOT_CONFIGURED" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  let healthUrl: URL;
  try {
    healthUrl = new URL("/health", apiBase);
    if (healthUrl.protocol !== "http:" && healthUrl.protocol !== "https:") {
      throw new Error("Unsupported API URL protocol");
    }
  } catch {
    return NextResponse.json(
      { error: "API_URL_INVALID" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }

  try {
    const upstream = await fetch(healthUrl, {
      method: "GET",
      headers: { accept: "application/json" },
      cache: "no-store",
      signal: AbortSignal.timeout(5000),
    });
    const body = await upstream.text();
    return new Response(body, {
      status: upstream.status,
      headers: {
        "Content-Type": upstream.headers.get("content-type") ?? "application/json",
        "Cache-Control": "no-store",
      },
    });
  } catch {
    return NextResponse.json(
      { error: "API_UNREACHABLE" },
      { status: 503, headers: { "Cache-Control": "no-store" } },
    );
  }
}
