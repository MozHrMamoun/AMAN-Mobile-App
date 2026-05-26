// Supabase Edge Function: Admin owner portfolio report
// Env vars required:
// - SUPABASE_URL
// - SUPABASE_SERVICE_ROLE_KEY
// - SUPABASE_ANON_KEY

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const PAGE_SIZE = 1000;

const propertyCountColumn: Record<string, string> = {
  Apartment: "Apartments",
  House: "Houses",
  Land: "Lands",
};

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
    const rawFocus =
      typeof body.portfolioType === "string" ? body.portfolioType.trim() : "";
    const focusType =
      rawFocus && rawFocus !== "All Portfolios"
        ? rawFocus.replace(" Owners", "")
        : null;

    const [{ data: owners, error: ownersError }, { data: properties, error: propertiesError }] =
      await Promise.all([
        fetchAllRows(() =>
          admin
            .from("user")
            .select("user_id, full_name")
            .eq("role", "owner")
            .order("full_name", { ascending: true })
        ),
        fetchAllRows(() =>
          admin.from("properties").select("owner_id, property_type")
        ),
      ]);

    if (ownersError || propertiesError) {
      throw new Error(
        ownersError?.message ||
          propertiesError?.message ||
          "Failed to load owner report.",
      );
    }

    const propertiesByOwner = new Map<string, Array<{ property_type: string | null }>>();
    (properties ?? []).forEach((property) => {
      const ownerId = `${property.owner_id ?? ""}`;
      if (!ownerId) return;
      const list = propertiesByOwner.get(ownerId) ?? [];
      list.push({ property_type: (property.property_type as string | null) ?? null });
      propertiesByOwner.set(ownerId, list);
    });

    const rows = (owners ?? [])
      .map((owner) => {
        const ownerProperties = propertiesByOwner.get(`${owner.user_id}`) ?? [];
        const counts = { Apartment: 0, House: 0, Land: 0 };

        ownerProperties.forEach((property) => {
          const type = formatPropertyType(property.property_type);
          if (type in counts) {
            counts[type as keyof typeof counts] += 1;
          }
        });

        return {
          Owner: (owner.full_name as string | null) ?? "Unknown Owner",
          "Total Properties": ownerProperties.length,
          Apartments: counts.Apartment,
          Houses: counts.House,
          Lands: counts.Land,
        };
      })
      .filter((row) => (focusType ? row[propertyCountColumn[focusType]] > 0 : true))
      .sort((a, b) => b["Total Properties"] - a["Total Properties"]);

    const resultRows = focusType
      ? rows.map((row) => {
          const matchedCount = row[propertyCountColumn[focusType]];
          const totalCount = row["Total Properties"];
          const share =
            totalCount > 0
              ? `${Math.round((matchedCount / totalCount) * 100)}%`
              : "0%";

          return {
            Owner: row.Owner,
            [`${focusType} Properties`]: matchedCount,
            "Total Properties": totalCount,
            "Portfolio Share": share,
          };
        })
      : rows;

    return new Response(
      JSON.stringify({
        rows: resultRows,
        columns: focusType
          ? ["Owner", `${focusType} Properties`, "Total Properties", "Portfolio Share"]
          : ["Owner", "Total Properties", "Apartments", "Houses", "Lands"],
        summary: `${rows.length} owner${rows.length === 1 ? "" : "s"} matched${
          focusType ? ` with at least one ${focusType.toLowerCase()} property` : ""
        }.`,
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
