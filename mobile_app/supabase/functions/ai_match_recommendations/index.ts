// Supabase Edge Function: AI recommendation matching
// Invoked from the app to generate notifications for seeker wishes.
// Env vars required:
// - GEMINI_API_KEY
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
// - SUPABASE_ANON_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

type Wish = {
  wished_id: number;
  seeker_id: string;
  is_active: boolean | null;
  matched_at: string | null;
  transaction_type: string | null;
  rent_type: string | null;
  property_type: string | null;
  city: string | null;
  bedrooms: number | null;
  bathrooms: number | null;
  price: number | null;
};

type Property = {
  property_id: number;
  transaction_type: string | null;
  rent_type: string | null;
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

const AI_SCORE_THRESHOLD = 0.7;
const CANDIDATE_FETCH_LIMIT = 120;
const AI_CANDIDATE_LIMIT = 40;

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
      "wished_id, seeker_id, is_active, matched_at, transaction_type, rent_type, property_type, city, bedrooms, bathrooms, price",
    )
    .eq("seeker_id", user.id)
    .eq("is_active", true)
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
    const normalizedWish = normalizeWish(wish);
    let wishMatched = false;

    let query = admin
      .from("properties")
      .select(
        "property_id, transaction_type, rent_type, property_type, property_city, bedrooms, bathrooms, price, description",
      )
      .eq("status", "active");

    if (normalizedWish.transaction_type) {
      query = query.eq("transaction_type", normalizedWish.transaction_type);
    }
    if (normalizedWish.transaction_type === "rent" && normalizedWish.rent_type) {
      query = query.eq("rent_type", normalizedWish.rent_type);
    }
    if (normalizedWish.property_type) {
      query = query.eq("property_type", normalizedWish.property_type);
    }
    if (normalizedWish.city) {
      query = query.ilike("property_city", normalizedWish.city);
    }
    if (normalizedWish.bedrooms != null) {
      query = query
        .gte("bedrooms", Math.max(0, normalizedWish.bedrooms - 1))
        .lte("bedrooms", normalizedWish.bedrooms + 1);
    }
    if (normalizedWish.bathrooms != null) {
      query = query
        .gte("bathrooms", Math.max(0, normalizedWish.bathrooms - 1))
        .lte("bathrooms", normalizedWish.bathrooms + 1);
    }
    if (normalizedWish.price != null && normalizedWish.price > 0) {
      query = query
        .gte("price", normalizedWish.price * 0.6)
        .lte("price", normalizedWish.price * 1.4);
    }

    let { data: candidates, error: candError } = await query.limit(CANDIDATE_FETCH_LIMIT);
    if (candError) {
      console.error("Candidate query failed for wish:", wish.wished_id, candError.message);
      continue;
    }

    if (!candidates || candidates.length === 0) {
      const relaxedQuery = buildRelaxedCandidateQuery(admin, normalizedWish);
      const relaxedResult = await relaxedQuery.limit(CANDIDATE_FETCH_LIMIT);
      candidates = relaxedResult.data;
      candError = relaxedResult.error;
    }

    if (candError || !candidates || candidates.length === 0) {
      console.log("No candidates for wish:", wish.wished_id);
      continue;
    }

    const rankedCandidates = rankCandidates(normalizedWish, candidates as Property[])
      .slice(0, AI_CANDIDATE_LIMIT);
    console.log("Candidates for wish:", wish.wished_id, rankedCandidates.length);

    let matches = await scoreWithGemini(normalizedWish, rankedCandidates);
    if (!matches || matches.length === 0) {
      matches = buildFallbackMatches(normalizedWish, rankedCandidates);
    }

    if (!matches || matches.length === 0) continue;

    const seenPropertyIds = new Set<number>();
    for (const m of matches) {
      if (m.score < AI_SCORE_THRESHOLD || seenPropertyIds.has(m.property_id)) {
        continue;
      }
      seenPropertyIds.add(m.property_id);

      const { data: exists } = await admin
        .from("notifications")
        .select("notification_id")
        .eq("seeker_id", user.id)
        .eq("wish_id", normalizedWish.wished_id)
        .eq("property_id", m.property_id)
        .limit(1);

      if (exists && exists.length > 0) continue;

      const body =
        m.reason && m.reason.length > 0
          ? m.reason
          : "A property matches your recommendation.";

      const { error: insertError } = await admin.from("notifications").insert({
        seeker_id: user.id,
        wish_id: normalizedWish.wished_id,
        property_id: m.property_id,
        title: "Match found",
        body,
      });

      if (!insertError) {
        totalMatched += 1;
        wishMatched = true;
      }
    }

    if (wishMatched) {
      await admin
        .from("wished_property")
        .update({ matched_at: new Date().toISOString() })
        .eq("wished_id", normalizedWish.wished_id);
    }
  }

  return new Response(JSON.stringify({ matched: totalMatched }), {
    status: 200,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
});

function normalizeText(value: string | null | undefined): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed.toLowerCase() : null;
}

function normalizeWish(wish: Wish): Wish {
  return {
    ...wish,
    transaction_type: normalizeText(wish.transaction_type),
    rent_type: normalizeText(wish.rent_type),
    property_type: normalizeText(wish.property_type),
    city: wish.city?.trim() ?? null,
  };
}

function buildRelaxedCandidateQuery(admin: ReturnType<typeof createClient>, wish: Wish) {
  let query = admin
    .from("properties")
    .select(
      "property_id, transaction_type, rent_type, property_type, property_city, bedrooms, bathrooms, price, description",
    )
    .eq("status", "active");

  if (wish.transaction_type) {
    query = query.eq("transaction_type", wish.transaction_type);
  }
  if (wish.transaction_type === "rent" && wish.rent_type) {
    query = query.eq("rent_type", wish.rent_type);
  }
  if (wish.property_type) {
    query = query.eq("property_type", wish.property_type);
  }
  if (wish.city) {
    query = query.ilike("property_city", wish.city);
  }

  return query;
}

function rankCandidates(wish: Wish, properties: Property[]): Property[] {
  return [...properties].sort((a, b) => heuristicScore(wish, b) - heuristicScore(wish, a));
}

function heuristicScore(wish: Wish, property: Property): number {
  let score = 0;

  if (wish.transaction_type && normalizeText(property.transaction_type) === wish.transaction_type) {
    score += 3;
  }
  if (
    wish.transaction_type === "rent" &&
    wish.rent_type &&
    normalizeText(property.rent_type) === wish.rent_type
  ) {
    score += 2;
  }
  if (wish.property_type && normalizeText(property.property_type) === wish.property_type) {
    score += 3;
  }
  if (wish.city && normalizeText(property.property_city) === normalizeText(wish.city)) {
    score += 3;
  }

  if (wish.bedrooms != null && property.bedrooms != null) {
    const diff = Math.abs(wish.bedrooms - property.bedrooms);
    score += Math.max(0, 2 - diff);
  }
  if (wish.bathrooms != null && property.bathrooms != null) {
    const diff = Math.abs(wish.bathrooms - property.bathrooms);
    score += Math.max(0, 2 - diff);
  }
  if (wish.price != null && wish.price > 0 && property.price != null && property.price > 0) {
    const diffRatio = Math.abs(property.price - wish.price) / wish.price;
    if (diffRatio <= 0.15) {
      score += 3;
    } else if (diffRatio <= 0.3) {
      score += 2;
    } else if (diffRatio <= 0.5) {
      score += 1;
    }
  }

  return score;
}

function buildFallbackMatches(wish: Wish, properties: Property[]): Match[] {
  return properties
    .map((property) => {
      const normalizedScore = Math.min(0.95, 0.45 + heuristicScore(wish, property) / 15);
      return {
        property_id: property.property_id,
        score: Number(normalizedScore.toFixed(2)),
        reason: buildFallbackReason(wish, property),
      };
    })
    .filter((match) => match.score >= AI_SCORE_THRESHOLD)
    .sort((a, b) => b.score - a.score)
    .slice(0, 5);
}

function buildFallbackReason(wish: Wish, property: Property): string {
  const reasons: string[] = [];

  if (wish.property_type && normalizeText(property.property_type) === wish.property_type) {
    reasons.push("same property type");
  }
  if (
    wish.transaction_type === "rent" &&
    wish.rent_type &&
    normalizeText(property.rent_type) === wish.rent_type
  ) {
    reasons.push("same rent type");
  }
  if (wish.city && normalizeText(property.property_city) === normalizeText(wish.city)) {
    reasons.push("same city");
  }
  if (wish.bedrooms != null && property.bedrooms != null && Math.abs(wish.bedrooms - property.bedrooms) <= 1) {
    reasons.push("similar bedroom count");
  }
  if (wish.bathrooms != null && property.bathrooms != null && Math.abs(wish.bathrooms - property.bathrooms) <= 1) {
    reasons.push("similar bathroom count");
  }
  if (wish.price != null && wish.price > 0 && property.price != null && property.price > 0) {
    const diffRatio = Math.abs(property.price - wish.price) / wish.price;
    if (diffRatio <= 0.2) {
      reasons.push("close to the wished price");
    }
  }

  return reasons.length > 0
    ? `Recommended because it has ${reasons.join(", ")}.`
    : "A property matches your recommendation.";
}

async function scoreWithGemini(wish: Wish, properties: Property[]): Promise<Match[]> {
  if (!geminiKey) {
    return [];
  }

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
              {
                text:
                  "You are matching property recommendations. " +
                  "Given one wish and a list of candidate properties, return the best matches only. " +
                  "Prefer exact matches on transaction_type, property_type, city, bedrooms, and bathrooms. " +
                  "Price should be close to the wish, ideally within 15%. " +
                  "Return JSON only and avoid duplicate property_id values.",
              },
              { text: JSON.stringify({ wish, properties }) },
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
      }))
      .sort((a, b) => b.score - a.score);
  } catch (_) {
    return [];
  }
}
