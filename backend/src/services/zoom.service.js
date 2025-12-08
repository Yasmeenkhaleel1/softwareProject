// src/services/zoom.service.js
import fetch from "node-fetch";

let cachedToken = null;
let cachedTokenExpiresAt = 0;

/**
 * 🔐 جلب Access Token من Zoom باستخدام Server-to-Server OAuth
 */
async function getZoomAccessToken() {
  const accountId = process.env.ZOOM_ACCOUNT_ID;
  const clientId = process.env.ZOOM_CLIENT_ID;
  const clientSecret = process.env.ZOOM_CLIENT_SECRET;

  if (!accountId || !clientId || !clientSecret) {
    throw new Error(
      "Missing Zoom env vars (ZOOM_ACCOUNT_ID / ZOOM_CLIENT_ID / ZOOM_CLIENT_SECRET)"
    );
  }

  const now = Date.now();

  // ✅ استخدم الكاش إذا التوكن لسه شغال
  if (cachedToken && now < cachedTokenExpiresAt - 60_000) {
    return cachedToken;
  }

  const url = new URL("https://zoom.us/oauth/token");
  url.searchParams.set("grant_type", "account_credentials");
  url.searchParams.set("account_id", accountId);

  const basicAuth = Buffer.from(`${clientId}:${clientSecret}`).toString(
    "base64"
  );

  const res = await fetch(url.toString(), {
    method: "POST",
    headers: {
      Authorization: `Basic ${basicAuth}`,
    },
  });

  if (!res.ok) {
    const txt = await res.text();
    console.error("❌ Zoom token error:", res.status, txt);
    throw new Error(`Failed to get Zoom access token (${res.status})`);
  }

  const body = await res.json();
  cachedToken = body.access_token;
  cachedTokenExpiresAt = now + (body.expires_in || 3600) * 1000;

  return cachedToken;
}

/**
 * 🎥 إنشاء اجتماع Zoom لجلسة واحدة
 * startTime: كائن Date (UTC)
 */
export async function createZoomMeeting({
  topic,
  startTime,
  durationMinutes = 60,
  timezone = "Asia/Hebron",
}) {
  const accessToken = await getZoomAccessToken();

  // Zoom يفضّل فورمات بدون milliseconds
  const isoNoMs = startTime.toISOString().split(".")[0] + "Z";

  const payload = {
    topic,
    type: 2, // Scheduled meeting
    start_time: isoNoMs,
    duration: durationMinutes,
    timezone,
    settings: {
      join_before_host: false,
      approval_type: 0, // Automatically approve
      mute_upon_entry: true,
      waiting_room: true,
    },
  };

  const res = await fetch("https://api.zoom.us/v2/users/me/meetings", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const txt = await res.text();
    console.error("❌ Zoom create meeting error:", res.status, txt);
    throw new Error(`Failed to create Zoom meeting (${res.status})`);
  }

  const data = await res.json();

  return {
    meetingId: data.id?.toString?.() ?? String(data.id),
    joinUrl: data.join_url,
    startUrl: data.start_url,
  };
}
