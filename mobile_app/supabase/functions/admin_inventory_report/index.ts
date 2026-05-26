// Supabase Edge Function: Admin inventory report
// Env vars required:
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
// - SUPABASE_ANON_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const PAGE_SIZE = 1000;

function formatPropertyType(value: string | null | undefined): string {
  const normalized = value?.trim().toLowerCase() ?? "";
  if (normalized === "apartment") return "Apartment";
  if (normalized === "house") return "House";
  if (normalized === "land") return "Land";
  return value?.trim() || "Other";
}

async function fetchAllRows<T extends Record<string, unknown>>(
  queryFactory: () => {
    range: (
      from: number,
      to: number,
    ) => Promise<{ data: T[] | null; error: { message: string } | null }>;
  },
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

async function requireAdmin(req: Request, body: Record<string, unknown>) {
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

  const authRes = authHeader
    ? await userClient.auth.getUser()
    : await userClient.auth.getUser(token);
  const user = authRes.data.user;
  if (authRes.error || !user) {
    throw new Error("Unauthorized");
  }

  const admin = createClient(supabaseUrl, supabaseServiceRoleKey);
  const { data: profile } = await admin
    .from("user")
    .select("role")
    .eq("user_id", user.id)
    .maybeSingle();

  if (!profile || (profile.role ?? "").toLowerCase() !== "admin") {
    throw new Error("Forbidden");
  }

  return admin;
}

Deno.serve(async (req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
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
  } catch {
    body = {};
  }

  try {
    const admin = await requireAdmin(req, body);
    const inventoryCity =
      typeof body.city === "string" ? body.city.trim() : "Any City";
    const inventoryType =
      typeof body.propertyType === "string" ? body.propertyType.trim() : "Any Type";

    const { data, error } = await fetchAllRows(() => {
      let query = admin
        .from("properties")
        .select(
          "property_id, property_type, property_city, property_state, transaction_type, status, price",
        )
        .order("property_id", { ascending: false });

      if (inventoryCity !== "Any City") {
        query = query.eq("property_city", inventoryCity);
      }
      if (inventoryType !== "Any Type") {
        query = query.eq("property_type", inventoryType);
      }

      return query;
    });

    if (error) {
      throw new Error(error.message);
    }

    const rows = (data ?? []).map((property) => ({
      ID: property.property_id,
      Type: formatPropertyType((property.property_type as string | null) ?? null),
      City: (property.property_city as string | null) ?? "-",
      State: (property.property_state as string | null) ?? "-",
      Transaction:
        property.transaction_type === "rent"
          ? "Rent"
          : property.transaction_type === "buy"
          ? "Buy"
          : "-",
      Status: (property.status as string | null) ?? "-",
      Price: property.price ?? "-",
    }));

    return new Response(
      JSON.stringify({
        rows,
        columns: ["ID", "Type", "City", "State", "Transaction", "Status", "Price"],
        summary: `${rows.length} propert${rows.length === 1 ? "y" : "ies"} found${
          inventoryCity !== "Any City" ? ` in ${inventoryCity}` : ""
        }${inventoryType !== "Any Type" ? ` for ${inventoryType.toLowerCase()}` : ""}.`,
      }),
      {
        status: 200,
        headers: { "Content-Type": "application/json", ...corsHeaders },
      },
    );
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unexpected error";
    const status =
      message === "Unauthorized" ? 401 : message === "Forbidden" ? 403 : 400;
    return new Response(JSON.stringify({ error: message }), {
      status,
      headers: { "Content-Type": "application/json", ...corsHeaders },
    });
  }
});
