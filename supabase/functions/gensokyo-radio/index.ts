import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const API_URL = "https://gensokyoradio.net/api/station/playing/";
const PLAYER_URL = "https://gensokyoradio.net/playing/";
const STREAM_URL = "https://stream.gensokyoradio.net/1/";
const ALBUM_ART_BASE = "https://gensokyoradio.net/images/albums/500/";
const PLACEHOLDER_ART = "https://gensokyoradio.net/images/assets/gr-logo-placeholder.png";
const CACHE_SECONDS = 20;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

let cachedStatus: unknown = null;
let cachedAt = 0;

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "private, max-age=15",
    },
  });
}

function asString(value: unknown): string | null {
  if (value === null || value === undefined) return null;
  const text = String(value).trim();
  return text.length === 0 ? null : text;
}

function asNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function child(record: unknown, key: string): unknown {
  if (record && typeof record === "object" && key in record) {
    return (record as Record<string, unknown>)[key];
  }
  return null;
}

async function imageAsBase64(url: string) {
  try {
    const response = await fetch(url, {
      headers: {
        "User-Agent": "FoodTaxi-GensokyoRadioRoom/1.0",
        "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
      },
    });

    if (!response.ok) return null;

    const contentType = response.headers.get("content-type") ?? "image/jpeg";
    const bytes = new Uint8Array(await response.arrayBuffer());

    let binary = "";
    for (const byte of bytes) {
      binary += String.fromCharCode(byte);
    }

    return {
      contentType,
      base64: btoa(binary),
    };
  } catch {
    return null;
  }
}

async function fetchStatus() {
  const now = Date.now();

  if (cachedStatus && now - cachedAt < CACHE_SECONDS * 1000) {
    return cachedStatus;
  }

  const response = await fetch(API_URL, {
    headers: {
      "User-Agent": "FoodTaxi-GensokyoRadioRoom/1.0",
      "Accept": "application/json",
    },
  });

  if (!response.ok) {
    throw new Error(`Gensokyo API returned ${response.status}`);
  }

  const data = await response.json();

  const songInfo = child(data, "SONGINFO");
  const songTimes = child(data, "SONGTIMES");
  const songData = child(data, "SONGDATA");
  const misc = child(data, "MISC");

  const albumArt = asString(child(misc, "ALBUMART"));
  const artUrl = albumArt ? `${ALBUM_ART_BASE}${albumArt}` : PLACEHOLDER_ART;
  const artImage = await imageAsBase64(artUrl);

  const status = {
    title: asString(child(songInfo, "TITLE")),
    artist: asString(child(songInfo, "ARTIST")),
    album: asString(child(songInfo, "ALBUM")),
    year: asString(child(songInfo, "YEAR")),
    circle: asString(child(songInfo, "CIRCLE")),
    duration: asNumber(child(songTimes, "DURATION")),
    played: asNumber(child(songTimes, "PLAYED")),
    remaining: asNumber(child(songTimes, "REMAINING")),
    songId: asString(child(songData, "SONGID")),
    albumArt,
    artUrl,
    artImage,
    playerUrl: PLAYER_URL,
    streamUrl: STREAM_URL,
    fetchedAt: new Date().toISOString(),
    source: API_URL,
  };

  cachedStatus = status;
  cachedAt = now;

  return status;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");

  if (!authHeader?.startsWith("Bearer ")) {
    return json({ error: "Missing authorization header" }, 401);
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: {
        headers: {
          Authorization: authHeader,
        },
      },
    },
  );

  const token = authHeader.replace("Bearer ", "");

  const {
    data: { user },
    error,
  } = await supabase.auth.getUser(token);

  if (error || !user) {
    return json({ error: "Unauthorized" }, 401);
  }

  try {
    return json(await fetchStatus());
  } catch (error) {
    return json({
      error: error instanceof Error ? error.message : String(error),
      title: null,
      artist: null,
      album: null,
      year: null,
      circle: null,
      duration: null,
      played: null,
      remaining: null,
      songId: null,
      albumArt: null,
      artUrl: PLACEHOLDER_ART,
      artImage: null,
      playerUrl: PLAYER_URL,
      streamUrl: STREAM_URL,
      fetchedAt: new Date().toISOString(),
      source: API_URL,
    }, 200);
  }
});