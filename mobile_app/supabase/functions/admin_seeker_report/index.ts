// Supabase Edge Function: Admin seeker report
// Env vars required:
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
// - SUPABASE_ANON_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

if (!supabaseUrl || !supabaseServiceRoleKey || !supabaseAnonKey) {
  console.error("Missing required env vars.");
}

const propertyTypeOrder = ["Apartment", "House", "Land"] as const;
const PAGE_SIZE = 1000;

function formatPropertyType(value: string | null | undefined): string {
  const normalized = value?.trim().toLowerCase() ?? "";
  if (normalized === "apartment") return "Apartment";
  if (normalized === "house") return "House";
  if (normalized === "land") return "Land";
  return value?.trim() || "Other";
}

async function fetchAllRows<T extends Record<string, unknown>>(
  queryFactory: () => { range: (from: number, to: number) => Promise<{ data: T[] | null; error: { message: string } | null }> },
) {
  const rows: T[] = [];
  let from = 0;

  while (true) {
    const { data, error } = await queryFactory().range(from, from + PAGE_SIZE - 1);
    if (error) {
      return { data: null, error };
    }

    const page = (data ?? []) as T[];
    rows.push(...page);

    if (page.length < PAGE_SIZE) {
      return { data: rows, error: null };
    }

    from += PAGE_SIZE;
  }
}

function adminClientFactory() {
  return createClient(supabaseUrl, supabaseServiceRoleKey);
}

async function fetchUsersByIds(admin: ReturnType<typeof createClient>, seekerIds: string[]) {
  const CHUNK_SIZE = 500;
  const rows: Array<{ user_id: string; full_name: string | null }> = [];

  for (let index = 0; index < seekerIds.length; index += CHUNK_SIZE) {
    const chunk = seekerIds.slice(index, index + CHUNK_SIZE);
    const { data, error } = await admin
      .from("user")
      .select("user_id, full_name")
      .in("user_id", chunk);

    if (error) {
      return { data: null, error };
    }

    rows.push(...(data ?? []));
  }

  return { data: rows, error: null };
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

  const filteredTypeRaw =
    typeof body.propertyType === "string" ? body.propertyType.trim() : "";
  const filteredType =
    filteredTypeRaw && filteredTypeRaw !== "All Preferences"
      ? filteredTypeRaw
      : null;

  const authHeader =
    req.headers.get("Authorization") ??
    req.headers.get("authorization") ??
    "";
  const bodyToken =
    (typeof body.access_token === "string" ? body.access_token : "") ||
    (typeof body.accessToken === "string" ? body.accessToken : "");
  const headerToken = authHeader.toLowerCase().startsWith("bearer ")
    ? authHeader.substring("Bearer ".length).trim()
    : authHeader.trim();
  const token = bodyToken || headerToken;

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
  } catch (error) {
    userError = error as Error;
  }

  if (userError || !user) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }

  const admin = createClient(supabaseUrl, supabaseServiceRoleKey);

  const { data: profile, error: profileError } = await admin
    .from("user")
    .select("role")
    .eq("user_id", user.id)
    .maybeSingle();

  if (profileError || !profile || (profile.role ?? "").toLowerCase() !== "admin") {
    return new Response(JSON.stringify({ error: "Forbidden" }), {
      status: 403,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }

  const [{ data: deals, error: dealsError }, { data: properties, error: propertiesError }] =
    await Promise.all([
      fetchAllRows(() =>
        admin.from("deals").select("seeker_id, property_id, done_at")
      ),
      fetchAllRows(() =>
        admin.from("properties").select("property_id, property_type, property_city")
      ),
    ]);

  if (dealsError || propertiesError) {
    return new Response(
      JSON.stringify({
        error: dealsError?.message || propertiesError?.message || "Failed to load seeker report.",
      }),
      {
        status: 400,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      },
    );
  }

  const propertyById = Object.fromEntries(
    (properties ?? []).map((property) => [property.property_id, property]),
  );

  const allRelevantDeals = (deals ?? []).filter((deal) => {
    const property = propertyById[deal.property_id];
    return Boolean(property);
  });

  const seekerIds = [
    ...new Set(allRelevantDeals.map((deal) => deal.seeker_id).filter(Boolean)),
  ];
  const { data: seekers, error: seekersError } =
    seekerIds.length === 0
      ? { data: [], error: null }
      : await fetchUsersByIds(admin, seekerIds);

  if (seekersError) {
    return new Response(JSON.stringify({ error: seekersError.message }), {
      status: 400,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }

  const seekerNameById = Object.fromEntries(
    (seekers ?? []).map((row) => [row.user_id, row.full_name ?? "Unknown Seeker"]),
  );

  const rows = seekerIds
    .map((seekerId) => {
      const seekerDeals = allRelevantDeals.filter((deal) => deal.seeker_id === seekerId);
      const counts = {
        Apartment: 0,
        House: 0,
        Land: 0,
      };
      const cities = new Set<string>();
      let completedDeals = 0;

      seekerDeals.forEach((deal) => {
        const property = propertyById[deal.property_id];
        if (!property) return;
        const type = formatPropertyType(property.property_type);
        if (type in counts) {
          counts[type as keyof typeof counts] += 1;
        }
        if (property.property_city) {
          cities.add(property.property_city);
        }
        if (deal.done_at) {
          completedDeals += 1;
        }
      });

      const mainPropertyType = propertyTypeOrder.reduce((best, type) =>
        counts[type] > counts[best] ? type : best,
      "Apartment");

      return {
        Seeker: seekerNameById[seekerId] ?? "Unknown Seeker",
        "Total Deals": seekerDeals.length,
        Completed: completedDeals,
        Pending: seekerDeals.length - completedDeals,
        Apartment: counts.Apartment,
        House: counts.House,
        Land: counts.Land,
        "Main Property Type": seekerDeals.length === 0 ? "-" : mainPropertyType,
        Cities: cities.size === 0 ? "-" : [...cities].join(", "),
      };
    })
    .filter((row) => {
      if (row["Total Deals"] <= 0) return false;
      return filteredType ? row[filteredType] > 0 : true;
    })
    .sort((a, b) => b["Total Deals"] - a["Total Deals"]);

  const resultRows = filteredType
    ? rows.map((row) => {
        const matchedDeals = row[filteredType];
        const totalDeals = row["Total Deals"];
        const share =
          totalDeals > 0
            ? `${Math.round((matchedDeals / totalDeals) * 100)}%`
            : "0%";

        return {
          Seeker: row.Seeker,
          [`${filteredType} Deals`]: matchedDeals,
          "Total Deals": totalDeals,
          "Preference Share": share,
          Completed: row.Completed,
          Pending: row.Pending,
        };
      })
    : rows;

  return new Response(
    JSON.stringify({
      rows: resultRows,
      columns: filteredType
        ? [
            "Seeker",
            `${filteredType} Deals`,
            "Total Deals",
            "Preference Share",
            "Completed",
            "Pending",
          ]
        : [
            "Seeker",
            "Total Deals",
            "Completed",
            "Pending",
            "Apartment",
            "House",
            "Land",
            "Main Property Type",
            "Cities",
          ],
      summary: `${rows.length} seeker${rows.length === 1 ? "" : "s"} included${
        filteredType ? ` with at least one ${filteredType.toLowerCase()} deal` : ""
      }.`,
    }),
    {
      status: 200,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    },
  );
});
