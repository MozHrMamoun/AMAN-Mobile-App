// Supabase Edge Function: AI recommendation matching
// Invoked from the app to generate notifications for seeker wishes.
// Env vars required:
// - OPENAI_API_KEY
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type Wish = {
  wished_id: number;
  seeker_id: string;
  transaction_type: string | null;
  property_type: string | null;
  city: string | null;
  bedrooms: number | null;
  bathrooms: number | null;
  price: number | null;
};

type Property = {
  property_id: number;
  transaction_type: string | null;
  property_type: string | null;
  property_city: string | null;
  bedrooms: number | null;
  bathrooms: number | null;
  price: number | null;
  description: string | null;
};

type Match = {
  property_id: number;
  score: number;
  reason: string;
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const geminiKey = Deno.env.get("GEMINI_API_KEY") ?? "";

if (!geminiKey || !supabaseUrl || !supabaseServiceRoleKey || !supabaseAnonKey) {
  console.error("Missing required env vars.");
}

Deno.serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405, headers: corsHeaders });
  }

  let body: Record<string, unknown> = {};
  try {
    body = await req.json();
  } catch (_) {
    body = {};
  }

  const bodyToken =
    (typeof body.access_token === "string" ? body.access_token : "") ||
    (typeof body.accessToken === "string" ? body.accessToken : "");

  const authHeader =
    req.headers.get("Authorization") ??
    req.headers.get("authorization") ??
    "";
  const headerToken = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.substring("Bearer ".length).trim()
    : authHeader.trim();

  const token = bodyToken || headerToken;
  console.log("Token parts:", token ? token.split(".").length : 0);
  console.log("Header present:", authHeader.length > 0);
  console.log("Body token length:", bodyToken.length);

  const userClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: authHeader
        ? { Authorization: authHeader }
        : token
        ? { Authorization: `Bearer ${token}` }
        : {},
    },
  });

  let user = null;
  let userError: Error | null = null;
  try {
    const res = authHeader
      ? await userClient.auth.getUser()
      : await userClient.auth.getUser(token);
    user = res.data.user ?? null;
    userError = res.error ?? null;
  } catch (e) {
    userError = e as Error;
  }

  if (userError || !user) {
    console.error("Auth error:", userError?.message);
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
  console.log("User:", user.id);

  const admin = createClient(supabaseUrl, supabaseServiceRoleKey);

  const { data: wishes, error: wishError } = await admin
    .from("wished_property")
    .select(
      "wished_id, seeker_id, transaction_type, property_type, city, bedrooms, bathrooms, price",
    )
    .eq("seeker_id", user.id)
    .order("wished_id", { ascending: false })
    .limit(5);

  if (wishError) {
    return new Response(JSON.stringify({ error: wishError.message }), {
      status: 400,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }

  if (!wishes || wishes.length === 0) {
    console.log("No wishes found.");
    return new Response(JSON.stringify({ matched: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
  console.log("Wishes:", wishes.length);

  let totalMatched = 0;

  for (const wish of wishes as Wish[]) {
    let query = admin
      .from("properties")
      .select(
        "property_id, transaction_type, property_type, property_city, bedrooms, bathrooms, price, description",
      )
      .eq("status", "active");

    if (wish.transaction_type) {
      query = query.eq("transaction_type", wish.transaction_type);
    }
    if (wish.property_type) {
      query = query.eq("property_type", wish.property_type);
    }
    if (wish.city) {
      query = query.eq("property_city", wish.city);
    }

    const { data: candidates, error: candError } = await query.limit(50);
    if (candError || !candidates || candidates.length === 0) {
      console.log("No candidates for wish:", wish.wished_id);
      continue;
    }
    console.log("Candidates for wish:", wish.wished_id, candidates.length);

    const matches = await scoreWithAI(wish, candidates as Property[]);
    if (!matches || matches.length === 0) continue;

    for (const m of matches) {
      if (m.score < 0.7) continue;
      const { data: exists } = await admin
        .from("notifications")
        .select("notification_id")
        .eq("seeker_id", user.id)
        .eq("wish_id", wish.wished_id)
        .eq("property_id", m.property_id)
        .limit(1);

      if (exists && exists.length > 0) continue;

      const body =
        m.reason && m.reason.length > 0
          ? m.reason
          : "A property matches your recommendation.";

      const { error: insertError } = await admin.from("notifications").insert({
        seeker_id: user.id,
        wish_id: wish.wished_id,
        property_id: m.property_id,
        title: "Match found",
        body,
      });

      if (!insertError) totalMatched += 1;
    }
  }

  return new Response(JSON.stringify({ matched: totalMatched }), {
    status: 200,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
});

async function scoreWithAI(wish: Wish, properties: Property[]): Promise<Match[]> {
  const prompt = {
    role: "user",
    content: [
      {
        type: "input_text",
        text:
          "You are matching property recommendations. " +
          "Given a wish and a list of properties, return the top matches. " +
          "Prefer exact matches on transaction_type, property_type, city, bedrooms, bathrooms. " +
          "Price should be close (within ~15% if possible). " +
          "Return JSON only.",
      },
      {
        type: "input_text",
        text: JSON.stringify({ wish, properties }),
      },
    ],
  };

  const response = await fetch(
    "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent",
    {
    method: "POST",
    headers: {
      "x-goog-api-key": geminiKey,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      contents: [
        {
          role: "user",
          parts: [
            { text: prompt.content[0].text },
            { text: prompt.content[1].text },
          ],
        },
      ],
      generationConfig: {
        response_mime_type: "application/json",
        response_json_schema: {
          type: "object",
          additionalProperties: false,
          properties: {
            matches: {
              type: "array",
              items: {
                type: "object",
                additionalProperties: false,
                properties: {
                  property_id: { type: "integer" },
                  score: { type: "number" },
                  reason: { type: "string" },
                },
                required: ["property_id", "score", "reason"],
              },
            },
          },
          required: ["matches"],
        },
      },
    }),
  },
  );

  if (!response.ok) {
    console.error("Gemini error:", await response.text());
    return [];
  }

  const data = await response.json();
  const content =
    data?.candidates?.[0]?.content?.parts?.[0]?.text ??
    data?.candidates?.[0]?.content?.parts?.map((p: { text?: string }) => p.text).join("");
  if (!content) return [];

  try {
    const parsed = JSON.parse(content);
    const matches = Array.isArray(parsed.matches) ? parsed.matches : [];
    return matches
      .filter((m) => typeof m.property_id === "number")
      .map((m) => ({
        property_id: m.property_id,
        score: Number(m.score ?? 0),
        reason: String(m.reason ?? ""),
      }));
  } catch (_) {
    return [];
  }
}
