import React, { useEffect, useMemo, useState } from "react";
import { isSupabaseConfigured, supabase } from "./lib/supabase";

const demoStats = {
  totalUsers: 1284,
  activeProperties: 452,
  ownerCount: 312,
  seekerCount: 972,
};

const demoActivity = [
  {
    id: "A-100",
    title: "Skyline Penthouse",
    subtitle: "New York City",
    type: "Property Listing",
    date: "Oct 24, 2023",
    status: "Active",
  },
  {
    id: "A-101",
    title: "Johnathan Doe",
    subtitle: "john.doe@email.com",
    type: "Seeker Registration",
    date: "Oct 23, 2023",
    status: "Pending Audit",
  },
  {
    id: "A-102",
    title: "Modern Garden Villa",
    subtitle: "Austin, Texas",
    type: "Property Listing",
    date: "Oct 23, 2023",
    status: "New Listing",
  },
];

const statusTone = {
  Active: "success",
  "New Listing": "warning",
};

const statusLabel = {
  Active: "Active",
  "New Listing": "New Listing",
};

const activityRecommendations = {
  Active: "Monitor listing freshness and verify the listing still reflects current inventory.",
  "New Listing":
    "Check the latest listing details and track whether it becomes active in the next reporting cycle.",
};

const iconPaths = {
  dashboard:
    "M4 10.75 12 4l8 6.75V20a1 1 0 0 1-1 1h-4.5v-6h-5v6H5a1 1 0 0 1-1-1v-9.25Z",
  settings:
    "M10.5 3h3l.55 2.01c.42.14.82.3 1.21.5l1.95-.85 2.12 2.12-.85 1.95c.2.39.36.79.5 1.21L21 10.5v3l-2.01.55c-.14.42-.3.82-.5 1.21l.85 1.95-2.12 2.12-1.95-.85c-.39.2-.79.36-1.21.5L13.5 21h-3l-.55-2.01a8.42 8.42 0 0 1-1.21-.5l-1.95.85-2.12-2.12.85-1.95a8.42 8.42 0 0 1-.5-1.21L3 13.5v-3l2.01-.55c.14-.42.3-.82.5-1.21l-.85-1.95 2.12-2.12 1.95.85c.39-.2.79-.36 1.21-.5L10.5 3Zm1.5 5.5a3.5 3.5 0 1 0 0 7 3.5 3.5 0 0 0 0-7Z",
  bell:
    "M12 3.75a4.25 4.25 0 0 0-4.25 4.25v1.27c0 .72-.2 1.42-.56 2.04l-1.1 1.88A1.5 1.5 0 0 0 7.39 15h9.22a1.5 1.5 0 0 0 1.3-2.23l-1.1-1.88a4.03 4.03 0 0 1-.56-2.04V8A4.25 4.25 0 0 0 12 3.75ZM10.25 17a1.75 1.75 0 0 0 3.5 0h-3.5Z",
  users:
    "M16 18.5v-.75A3.75 3.75 0 0 0 12.25 14H8.75A3.75 3.75 0 0 0 5 17.75v.75m14-2.5v-.25A3.25 3.25 0 0 0 15.75 12.5h-.5M9.5 7.5a2.5 2.5 0 1 1-5 0 2.5 2.5 0 0 1 5 0Zm8 1a2.5 2.5 0 1 0 0-5 2.5 2.5 0 0 0 0 5Zm-5.5 1a3 3 0 1 0 0-6 3 3 0 0 0 0 6Z",
  properties:
    "M4 10.5 12 4l8 6.5v8.75A1.75 1.75 0 0 1 18.25 21H5.75A1.75 1.75 0 0 1 4 19.25V10.5Zm5.25 9h5.5v-6h-5.5v6Z",
  owners:
    "M12 12.25a3.25 3.25 0 1 0 0-6.5 3.25 3.25 0 0 0 0 6.5ZM5 19.25A4.75 4.75 0 0 1 9.75 14.5h4.5A4.75 4.75 0 0 1 19 19.25V20H5v-.75Zm9.75-7.37a3.35 3.35 0 0 1 3.15 3.37V16H21v-.75a4.25 4.25 0 0 0-4.14-4.25h-2.11Z",
  seekers:
    "M6 19.5v-.25A4.25 4.25 0 0 1 10.25 15h3.5A4.25 4.25 0 0 1 18 19.25v.25M12 11.5a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7Zm7.25 7.5h1.25m-4.5-8.25.88.88m0 6.74-.88-.88m-9.5.88-.88.88m0-6.74.88-.88",
  reportOwners:
    "M7 6.75h10M7 10.75h10M7 14.75h6m5 4.25 2.5-2.5m0 0L18 14m2.5 2.5H15m-8.25-12A1.75 1.75 0 0 0 5 6.25v11.5c0 .97.78 1.75 1.75 1.75h4.5",
  reportSeekers:
    "M6.5 7.5h11m-11 4h7m3.75 8-2.9-2.9A4.75 4.75 0 1 0 15 15l2.9 2.9ZM12 17.5a2.5 2.5 0 1 1 0-5 2.5 2.5 0 0 1 0 5Z",
  reportInventory:
    "M5.75 6.5h12.5A1.75 1.75 0 0 1 20 8.25v8.5a1.75 1.75 0 0 1-1.75 1.75H5.75A1.75 1.75 0 0 1 4 16.75v-8.5C4 7.28 4.78 6.5 5.75 6.5Zm2.5 3h7.5m-7.5 3.5h4.5",
  export:
    "M12 4v9m0 0 3.25-3.25M12 13 8.75 9.75M5 15.75v1.5A1.75 1.75 0 0 0 6.75 19h10.5A1.75 1.75 0 0 0 19 17.25v-1.5",
  more:
    "M6.75 12a.75.75 0 1 1 0 .01V12Zm5.25 0a.75.75 0 1 1 0 .01V12Zm5.25 0a.75.75 0 1 1 0 .01V12Z",
};

function AppIcon({ name, className = "" }) {
  return (
    <svg
      className={className}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.8"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
    >
      <path d={iconPaths[name]} />
    </svg>
  );
}

const downloadCsv = (filename, columns, rows) => {
  const escapeCell = (value) => {
    const text = `${value ?? ""}`.replaceAll('"', '""');
    return `"${text}"`;
  };

  const csv = [
    columns.map(escapeCell).join(","),
    ...rows.map((row) =>
      columns.map((column) => escapeCell(row[column])).join(",")
    ),
  ].join("\n");

  const blob = new Blob([csv], { type: "text/csv;charset=utf-8;" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.setAttribute("download", filename);
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  URL.revokeObjectURL(url);
};

const chartPalette = ["#2f5ae8", "#4d8ef7", "#21a67a", "#f39c37", "#d94f70"];

const SETTINGS_STORAGE_KEY = "aman-admin-settings";

const defaultDashboardSettings = {
  reportPageSize: 50,
  activityPreviewCount: 6,
  newListingWindowDays: 7,
};

const loadDashboardSettings = () => {
  if (typeof window === "undefined") return defaultDashboardSettings;

  try {
    const raw = window.localStorage.getItem(SETTINGS_STORAGE_KEY);
    if (!raw) return defaultDashboardSettings;

    const parsed = JSON.parse(raw);
    return {
      reportPageSize:
        Number(parsed?.reportPageSize) || defaultDashboardSettings.reportPageSize,
      activityPreviewCount:
        Number(parsed?.activityPreviewCount) ||
        defaultDashboardSettings.activityPreviewCount,
      newListingWindowDays:
        Number(parsed?.newListingWindowDays) ||
        defaultDashboardSettings.newListingWindowDays,
    };
  } catch {
    return defaultDashboardSettings;
  }
};

const formatChartNumber = (value) =>
  typeof value === "number" ? value.toLocaleString() : `${value ?? ""}`;

const toNumber = (value) => {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  const normalized = `${value ?? ""}`.replace(/,/g, "").trim();
  const parsed = Number(normalized);
  return Number.isFinite(parsed) ? parsed : 0;
};

const sumMatchingColumns = (rows, columns, candidates) => {
  const matchedColumns = columns.filter((column) =>
    candidates.some((candidate) => candidate.toLowerCase() === column.toLowerCase())
  );

  return rows.reduce(
    (sum, row) =>
      sum +
      matchedColumns.reduce(
        (columnSum, column) => columnSum + toNumber(row[column]),
        0
      ),
    0
  );
};

function DonutChart({ data, total }) {
  const radius = 44;
  const circumference = 2 * Math.PI * radius;
  let offset = 0;

  return (
    <svg
      className="chart-svg"
      viewBox="0 0 120 120"
      role="img"
      aria-label="Report distribution chart"
    >
      <circle
        className="chart-ring-bg"
        cx="60"
        cy="60"
        r={radius}
        fill="none"
        strokeWidth="14"
      />
      {data.map((item) => {
        const segmentLength = (item.value / total) * circumference;
        const dashOffset = -offset;
        offset += segmentLength;

        return (
          <circle
            key={item.label}
            cx="60"
            cy="60"
            r={radius}
            fill="none"
            stroke={item.color}
            strokeWidth="14"
            strokeLinecap="round"
            strokeDasharray={`${segmentLength} ${circumference - segmentLength}`}
            strokeDashoffset={dashOffset}
            transform="rotate(-90 60 60)"
          />
        );
      })}
      <text x="60" y="54" textAnchor="middle" className="chart-center-label">
        Total
      </text>
      <text x="60" y="72" textAnchor="middle" className="chart-center-value">
        {formatChartNumber(total)}
      </text>
    </svg>
  );
}

function BarChart({ data, maxValue }) {
  return (
    <div className="bar-chart" role="img" aria-label="Report comparison chart">
      {data.map((item) => {
        const width = maxValue > 0 ? Math.max(10, (item.value / maxValue) * 100) : 0;
        return (
          <div key={item.label} className="bar-chart-row">
            <div className="bar-chart-meta">
              <span className="bar-chart-label">{item.label}</span>
              <span className="bar-chart-value">{formatChartNumber(item.value)}</span>
            </div>
            <div className="bar-chart-track">
              <span
                className="bar-chart-fill"
                style={{ width: `${width}%`, background: item.color }}
              />
            </div>
          </div>
        );
      })}
    </div>
  );
}

export default function App() {
  const [activeView, setActiveView] = useState("dashboard");
  const [dashboardSettings, setDashboardSettings] = useState(
    loadDashboardSettings
  );
  const [stats, setStats] = useState(demoStats);
  const [activity, setActivity] = useState(demoActivity);
  const [showAllActivity, setShowAllActivity] = useState(false);
  const [activityFilter, setActivityFilter] = useState("All");
  const [expandedActivityId, setExpandedActivityId] = useState(null);
  const [loading, setLoading] = useState(false);
  const [ownerPortfolioType, setOwnerPortfolioType] = useState("All Portfolios");
  const [seekerPreferenceType, setSeekerPreferenceType] =
    useState("All Preferences");
  const [inventoryCity, setInventoryCity] = useState("Any City");
  const [inventoryType, setInventoryType] = useState("Any Type");
  const [cityOptions, setCityOptions] = useState(["Any City"]);
  const [session, setSession] = useState(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [authError, setAuthError] = useState("");
  const [adminOk, setAdminOk] = useState(true);
  const [adminName, setAdminName] = useState("Super Admin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [reportLoading, setReportLoading] = useState(false);
  const [reportError, setReportError] = useState("");
  const [reportResult, setReportResult] = useState(null);
  const [reportPageSize, setReportPageSize] = useState(
    loadDashboardSettings().reportPageSize
  );
  const [reportPage, setReportPage] = useState(1);

  useEffect(() => {
    if (typeof window === "undefined") return;
    window.localStorage.setItem(
      SETTINGS_STORAGE_KEY,
      JSON.stringify(dashboardSettings)
    );
  }, [dashboardSettings]);

  useEffect(() => {
    setReportPageSize(dashboardSettings.reportPageSize);
  }, [dashboardSettings.reportPageSize]);

  useEffect(() => {
    let active = true;
    if (!isSupabaseConfigured) return undefined;

    const load = async () => {
      setLoading(true);
      try {
        const { count: totalUsers } = await supabase
          .from("user")
          .select("user_id", { count: "exact", head: true });

        const { count: activeProperties } = await supabase
          .from("properties")
          .select("property_id", { count: "exact", head: true })
          .eq("status", "active");

        const { count: ownerCount } = await supabase
          .from("user")
          .select("user_id", { count: "exact", head: true })
          .eq("role", "owner");

        const { count: seekerCount } = await supabase
          .from("user")
          .select("user_id", { count: "exact", head: true })
          .eq("role", "seeker");

        const { data: recent } = await supabase
          .from("properties")
          .select(
            "property_id, property_type, property_city, created_at, status, owner_id"
          )
          .order("created_at", { ascending: false })
          .limit(50);

        const { data: propertyCities } = await supabase
          .from("properties")
          .select("property_city");

        if (!active) return;

        setStats((prev) => ({
          ...prev,
          totalUsers: totalUsers ?? prev.totalUsers,
          activeProperties: activeProperties ?? prev.activeProperties,
          ownerCount: ownerCount ?? prev.ownerCount,
          seekerCount: seekerCount ?? prev.seekerCount,
        }));

        if (recent && recent.length > 0) {
          setActivity(
            recent.map((item) => ({
              id: `P-${item.property_id}`,
              title: item.property_type ?? "Property",
              subtitle: item.property_city ?? "Unknown",
              type: "Property Listing",
              date: new Date(item.created_at).toLocaleDateString(),
              status: item.status === "active" ? "Active" : "New Listing",
              createdAt: item.created_at,
            }))
          );
        }

        if (propertyCities && propertyCities.length > 0) {
          const distinctCities = [
            "Any City",
            ...new Set(
              propertyCities
                .map((item) => item.property_city)
                .filter(Boolean)
                .sort((a, b) => a.localeCompare(b))
            ),
          ];
          setCityOptions(distinctCities);
        }
      } catch (_) {
        // Keep demo data if load fails.
      } finally {
        if (active) setLoading(false);
      }
    };

    load();
    return () => {
      active = false;
    };
  }, []);

  useEffect(() => {
    if (!isSupabaseConfigured) {
      setAuthLoading(false);
      return;
    }

    let active = true;

    supabase.auth.getSession().then(({ data }) => {
      if (!active) return;
      setSession(data.session ?? null);
      setAuthLoading(false);
    });

    const { data: listener } = supabase.auth.onAuthStateChange(
      (_event, newSession) => {
        if (!active) return;
        setSession(newSession);
      }
    );

    return () => {
      active = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  useEffect(() => {
    if (!session || !isSupabaseConfigured) {
      setAdminOk(true);
      return;
    }

    let active = true;

    const loadRole = async () => {
      const { data } = await supabase
        .from("user")
        .select("role, full_name")
        .eq("user_id", session.user.id)
        .maybeSingle();

      if (!active) return;
      const role = (data?.role ?? "").toLowerCase();
      setAdminOk(role === "admin");
      if (data?.full_name) setAdminName(data.full_name);
    };

    loadRole();
    return () => {
      active = false;
    };
  }, [session]);

  const handleLogin = async (event) => {
    event.preventDefault();
    setAuthError("");
    const { error } = await supabase.auth.signInWithPassword({
      email,
      password,
    });
    if (error) {
      setAuthError(error.message);
    }
  };

  const handleLogout = async () => {
    await supabase.auth.signOut();
  };

  const updateDashboardSetting = (key, value) => {
    setDashboardSettings((current) => ({
      ...current,
      [key]: value,
    }));
  };

  const resetDashboardSettings = () => {
    setDashboardSettings(defaultDashboardSettings);
    setReportPage(1);
  };

  const runOwnerPortfolioReport = async () => {
    setReportLoading(true);
    setReportError("");

    try {
      const { data, error } = await supabase.functions.invoke(
        "admin_owner_report",
        {
          body: {
            portfolioType: ownerPortfolioType,
          },
        }
      );

      if (error) throw error;
      if (data?.error) throw new Error(data.error);

      setReportResult({
        title: "Owner Portfolio Report",
        summary: data?.summary || "Owner portfolio report generated.",
        filename: "owner-portfolio-report.csv",
        columns: Array.isArray(data?.columns) ? data.columns : [],
        rows: Array.isArray(data?.rows) ? data.rows : [],
        appliedFilter: ownerPortfolioType,
      });
      setReportPage(1);
    } catch (error) {
      setReportError(error.message || "Failed to generate owner report.");
      setReportResult(null);
      setReportPage(1);
    } finally {
      setReportLoading(false);
    }
  };

  const runSeekerPreferenceReport = async () => {
    setReportLoading(true);
    setReportError("");

    try {
      const { data, error } = await supabase.functions.invoke(
        "admin_seeker_report",
        {
          body: {
            propertyType: seekerPreferenceType,
          },
        }
      );

      if (error) throw error;
      if (data?.error) throw new Error(data.error);

      const rows = Array.isArray(data?.rows) ? data.rows : [];

      setReportResult({
        title: "Seeker Preference Report",
        summary:
          data?.summary ||
          `${rows.length} seeker${rows.length === 1 ? "" : "s"} included.`,
        filename: "seeker-preference-report.csv",
        columns: Array.isArray(data?.columns)
          ? data.columns
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
        rows,
        appliedFilter: seekerPreferenceType,
      });
      setReportPage(1);
    } catch (error) {
      setReportError(error.message || "Failed to generate seeker report.");
      setReportResult(null);
      setReportPage(1);
    } finally {
      setReportLoading(false);
    }
  };

  const runInventoryReport = async () => {
    setReportLoading(true);
    setReportError("");

    try {
      const { data, error } = await supabase.functions.invoke(
        "admin_inventory_report",
        {
          body: {
            city: inventoryCity,
            propertyType: inventoryType,
          },
        }
      );

      if (error) throw error;
      if (data?.error) throw new Error(data.error);

      setReportResult({
        title: "Property Inventory Report",
        summary: data?.summary || "Property inventory report generated.",
        filename: "property-inventory-report.csv",
        columns: Array.isArray(data?.columns) ? data.columns : [],
        rows: Array.isArray(data?.rows) ? data.rows : [],
        appliedFilter: {
          city: inventoryCity,
          propertyType: inventoryType,
        },
      });
      setReportPage(1);
    } catch (error) {
      setReportError(error.message || "Failed to generate inventory report.");
      setReportResult(null);
      setReportPage(1);
    } finally {
      setReportLoading(false);
    }
  };

  const cardStats = useMemo(
    () => [
      {
        title: "Active Properties",
        value: stats.activeProperties,
        subtitle: "Updated today",
        accent: "properties",
        iconName: "properties",
      },
      {
        title: "Total Users",
        value: stats.totalUsers,
        subtitle: "Active this week",
        accent: "users",
        iconName: "users",
      },
      {
        title: "Owners",
        value: stats.ownerCount,
        subtitle: "Pending review",
        accent: "owners",
        iconName: "owners",
      },
      {
        title: "Seekers",
        value: stats.seekerCount,
        subtitle: "Recently matched",
        accent: "seekers",
        iconName: "seekers",
      },
    ],
    [stats]
  );

  const reportCards = [
    {
      key: "owners",
      title: "Owner Portfolio Report",
      description:
        "Review owner concentration, portfolio mix, and who is driving the largest inventory pools.",
      label: "Portfolio Focus",
      icon: "reportOwners",
      footer: "Best for account health checks",
      action: runOwnerPortfolioReport,
      controls: (
        <div className="report-field">
          <span className="report-field-label">Portfolio Focus</span>
          <select
            value={ownerPortfolioType}
            onChange={(e) => setOwnerPortfolioType(e.target.value)}
          >
            <option>All Portfolios</option>
            <option>Apartment Owners</option>
            <option>House Owners</option>
            <option>Land Owners</option>
          </select>
        </div>
      ),
    },
    {
      key: "seekers",
      title: "Seeker Preference Report",
      description:
        "See where demand is clustering by property type, deal completion, and favored cities.",
      label: "Taken Property Type",
      icon: "reportSeekers",
      footer: "Useful for demand-side trends",
      action: runSeekerPreferenceReport,
      controls: (
        <div className="report-field">
          <span className="report-field-label">Taken Property Type</span>
          <select
            value={seekerPreferenceType}
            onChange={(e) => setSeekerPreferenceType(e.target.value)}
          >
            <option>All Preferences</option>
            <option>Apartment</option>
            <option>House</option>
            <option>Land</option>
          </select>
        </div>
      ),
    },
    {
      key: "inventory",
      title: "Property Inventory Report",
      description:
        "Inspect live supply by city and property category to spot gaps, surges, and stale inventory.",
      label: "Supply Filters",
      icon: "reportInventory",
      footer: "Fastest way to audit listing supply",
      action: runInventoryReport,
      controls: (
        <div className="report-filters">
          <div className="report-field">
            <span className="report-field-label">City</span>
            <select
              value={inventoryCity}
              onChange={(e) => setInventoryCity(e.target.value)}
            >
              {cityOptions.map((city) => (
                <option key={city}>{city}</option>
              ))}
            </select>
          </div>
          <div className="report-field">
            <span className="report-field-label">Property Type</span>
            <select
              value={inventoryType}
              onChange={(e) => setInventoryType(e.target.value)}
            >
              <option>Any Type</option>
              <option>Apartment</option>
              <option>House</option>
              <option>Land</option>
            </select>
          </div>
        </div>
      ),
    },
  ];

  const reportFilterSummary = useMemo(() => {
    if (!reportResult) return "All";
    if (reportResult.title === "Owner Portfolio Report") {
      return reportResult.appliedFilter ?? "All";
    }
    if (reportResult.title === "Seeker Preference Report") {
      return reportResult.appliedFilter ?? "All";
    }

    const filters = [];
    const appliedInventoryFilter =
      typeof reportResult.appliedFilter === "object" && reportResult.appliedFilter
        ? reportResult.appliedFilter
        : null;

    if (appliedInventoryFilter?.city && appliedInventoryFilter.city !== "Any City") {
      filters.push(appliedInventoryFilter.city);
    }
    if (
      appliedInventoryFilter?.propertyType &&
      appliedInventoryFilter.propertyType !== "Any Type"
    ) {
      filters.push(appliedInventoryFilter.propertyType);
    }
    return filters.length > 0 ? filters.join(" / ") : "All";
  }, [reportResult]);

  const pagedReportRows = useMemo(() => {
    if (!reportResult?.rows) return [];
    const start = (reportPage - 1) * reportPageSize;
    return reportResult.rows.slice(start, start + reportPageSize);
  }, [reportPage, reportPageSize, reportResult]);

  const totalReportPages = useMemo(() => {
    const totalRows = reportResult?.rows?.length ?? 0;
    return Math.max(1, Math.ceil(totalRows / reportPageSize));
  }, [reportPageSize, reportResult]);

  const visibleActivity = useMemo(
    () => {
      const filteredActivity = activity.filter((item) =>
        activityFilter === "All" ? true : item.status === activityFilter
      );
      return showAllActivity
        ? filteredActivity
        : filteredActivity.slice(0, dashboardSettings.activityPreviewCount);
    },
    [activity, activityFilter, dashboardSettings.activityPreviewCount, showAllActivity]
  );

  const activitySummary = useMemo(() => {
    const active = activity.filter((item) => item.status === "Active").length;
    const newListings = activity.filter((item) => item.status === "New Listing").length;
    return [
      { label: "All", value: activity.length, filter: "All" },
      { label: "Active", value: active, filter: "Active" },
      { label: "New Listings", value: newListings, filter: "New Listing" },
    ];
  }, [activity]);

  const settingsCards = [
    {
      title: "Report Pagination",
      description:
        "Choose how many rows each generated report shows per page before paging forward.",
      control: (
        <div className="settings-control-group">
          {[50, 100, 200].map((value) => (
            <button
              key={value}
              className={`settings-choice ${
                dashboardSettings.reportPageSize === value ? "active" : ""
              }`}
              onClick={() => {
                updateDashboardSetting("reportPageSize", value);
                setReportPage(1);
              }}
            >
              {value} rows
            </button>
          ))}
        </div>
      ),
    },
    {
      title: "Recent Activity Preview",
      description:
        "Control how many rows stay visible before the user needs to open the full recent activity list.",
      control: (
        <div className="settings-control-group">
          {[6, 8, 10].map((value) => (
            <button
              key={value}
              className={`settings-choice ${
                dashboardSettings.activityPreviewCount === value ? "active" : ""
              }`}
              onClick={() => updateDashboardSetting("activityPreviewCount", value)}
            >
              {value} items
            </button>
          ))}
        </div>
      ),
    },
    {
      title: "New Listing Window",
      description:
        "Define how many days a listing should still count as recent when you review activity trends.",
      control: (
        <div className="settings-control-group">
          {[3, 7, 14].map((value) => (
            <button
              key={value}
              className={`settings-choice ${
                dashboardSettings.newListingWindowDays === value ? "active" : ""
              }`}
              onClick={() => updateDashboardSetting("newListingWindowDays", value)}
            >
              {value} days
            </button>
          ))}
        </div>
      ),
    },
  ];

  const reportChart = useMemo(() => {
    if (!reportResult?.rows?.length) return null;

    const rows = reportResult.rows;
    const columns = reportResult.columns ?? [];

    if (reportResult.title === "Owner Portfolio Report") {
      const appliedOwnerFilter =
        typeof reportResult.appliedFilter === "string"
          ? reportResult.appliedFilter
          : "All Portfolios";
      const focusedColumn = columns.find((column) =>
        column.endsWith(" Properties")
      );

      if (
        appliedOwnerFilter !== "All Portfolios" &&
        focusedColumn &&
        columns.includes("Total Properties")
      ) {
        const focusedLabel = focusedColumn.replace(" Properties", "");
        const focusedTotal = rows.reduce(
          (sum, row) => sum + toNumber(row[focusedColumn]),
          0
        );
        const totalProperties = rows.reduce(
          (sum, row) => sum + toNumber(row["Total Properties"]),
          0
        );
        const remainingTotal = Math.max(totalProperties - focusedTotal, 0);
        const totals = [
          {
            label: focusedLabel,
            value: focusedTotal,
            color: chartPalette[0],
          },
          {
            label: "Other Properties",
            value: remainingTotal,
            color: chartPalette[3],
          },
        ].filter((item) => item.value > 0);

        const total = totals.reduce((sum, item) => sum + item.value, 0);
        if (!total) return null;

        return {
          title: `${focusedLabel} Portfolio Mix`,
          subtitle: `Share of ${focusedLabel.toLowerCase()} properties versus the remaining owner inventory`,
          type: "donut",
          total,
          data: totals,
        };
      }

      const totals = [
        {
          label: "Apartments",
          candidates: ["Apartment", "Apartments"],
        },
        {
          label: "Houses",
          candidates: ["House", "Houses"],
        },
        {
          label: "Land",
          candidates: ["Land", "Lands"],
        },
      ]
        .map((item, index) => ({
          label: item.label,
          value: sumMatchingColumns(rows, columns, item.candidates),
          color: chartPalette[index],
        }))
        .filter((item) => item.value > 0);

      const total = totals.reduce((sum, item) => sum + item.value, 0);
      if (!total) return null;

      return {
        title: "Portfolio Mix",
        subtitle: "Distribution of properties across owner portfolios",
        type: "donut",
        total,
        data: totals,
      };
    }

    if (reportResult.title === "Seeker Preference Report") {
      const appliedSeekerFilter =
        typeof reportResult.appliedFilter === "string"
          ? reportResult.appliedFilter
          : "All Preferences";
      const focusedType = ["Apartment", "House", "Land"].find((label) => {
        const focusedDealsColumn = `${label} Deals`;
        return (
          label === appliedSeekerFilter &&
          columns.includes(focusedDealsColumn) &&
          columns.includes("Total Deals")
        );
      });

      if (focusedType) {
        const focusedDealsColumn = `${focusedType} Deals`;
        const focusedTotal = rows.reduce(
          (sum, row) => sum + toNumber(row[focusedDealsColumn]),
          0
        );
        const totalDeals = rows.reduce(
          (sum, row) => sum + toNumber(row["Total Deals"]),
          0
        );
        const remainingTotal = Math.max(totalDeals - focusedTotal, 0);
        const totals = [
          {
            label: focusedType,
            value: focusedTotal,
            color: chartPalette[0],
          },
          {
            label: "Other Deals",
            value: remainingTotal,
            color: chartPalette[3],
          },
        ].filter((item) => item.value > 0);

        const total = totals.reduce((sum, item) => sum + item.value, 0);
        if (!total) return null;

        return {
          title: `${focusedType} Preference Mix`,
          subtitle: `Share of ${focusedType.toLowerCase()} deals versus the remaining seeker activity`,
          type: "donut",
          total,
          data: totals,
        };
      }

      const totals = [
        {
          label: "Apartment",
          candidates: ["Apartment", "Apartments"],
        },
        {
          label: "House",
          candidates: ["House", "Houses"],
        },
        {
          label: "Land",
          candidates: ["Land", "Lands"],
        },
      ]
        .map((item, index) => ({
          label: item.label,
          value: sumMatchingColumns(rows, columns, item.candidates),
          color: chartPalette[index],
        }))
        .filter((item) => item.value > 0);

      const total = totals.reduce((sum, item) => sum + item.value, 0);
      if (!total) return null;

      return {
        title: "Preference Mix",
        subtitle: "How seeker activity is split by property type",
        type: "donut",
        total,
        data: totals,
      };
    }

    if (reportResult.title === "Property Inventory Report") {
      const cityColumn =
        reportResult.columns.find((column) => column.toLowerCase().includes("city")) ??
        reportResult.columns[0];
      const countColumn =
        reportResult.columns.find((column) => {
          const normalized = column.toLowerCase();
          return (
            normalized.includes("count") ||
            normalized.includes("total") ||
            normalized.includes("properties") ||
            normalized.includes("listings")
          );
        }) ?? reportResult.columns[reportResult.columns.length - 1];

      const data = rows
        .map((row, index) => ({
          label: `${row[cityColumn] ?? "Unknown"}`,
          value: toNumber(row[countColumn]),
          color: chartPalette[index % chartPalette.length],
        }))
        .filter((item) => item.value > 0)
        .sort((a, b) => b.value - a.value)
        .slice(0, 5);

      if (!data.length) return null;

      return {
        title: "Top Inventory Locations",
        subtitle: "Highest listing volume by city in the current result set",
        type: "bars",
        maxValue: Math.max(...data.map((item) => item.value), 0),
        data,
      };
    }

    return null;
  }, [reportResult]);

  if (!isSupabaseConfigured) {
    return (
      <div className="config-alert">
        <h2>Supabase is not configured</h2>
        <p>
          Add your credentials in <code>.env</code> and restart the dev server.
        </p>
      </div>
    );
  }

  if (authLoading) {
    return (
      <div className="config-alert">
        <p>Loading admin portal...</p>
      </div>
    );
  }

  if (!session) {
    return (
      <div className="login-shell">
        <div className="login-card">
          <h2>AMAN Admin Login</h2>
          <p className="muted">Sign in with your admin account.</p>
          <form onSubmit={handleLogin} className="login-form">
            <label>
              Email
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </label>
            <label>
              Password
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
            </label>
            {authError && <div className="form-error">{authError}</div>}
            <button type="submit" className="primary full">
              Login
            </button>
          </form>
        </div>
      </div>
    );
  }

  if (!adminOk) {
    return (
      <div className="login-shell">
        <div className="login-card">
          <h2>Access Restricted</h2>
          <p className="muted">
            Your account is not marked as admin. Update your role to
            <code>admin</code> in the <code>user</code> table.
          </p>
          <button className="primary full" onClick={handleLogout}>
            Logout
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="admin-shell">
      <aside className="sidebar">
        <div className="brand">
          <div>
            <p className="brand-title">AdminPortal</p>
            <p className="brand-subtitle">AMAN Dashboard</p>
          </div>
        </div>
        <div className="menu-label">Main</div>
        <nav className="menu">
          <button
            className={`menu-item ${activeView === "dashboard" ? "active" : ""}`}
            onClick={() => setActiveView("dashboard")}
          >
            <AppIcon name="dashboard" className="nav-icon" />
            Dashboard
          </button>
          <button
            className={`menu-item ${activeView === "settings" ? "active" : ""}`}
            onClick={() => setActiveView("settings")}
          >
            <AppIcon name="settings" className="nav-icon" />
            Settings
          </button>
        </nav>
        <div className="sidebar-footer">
          <button className="logout" onClick={handleLogout}>
            Log Out
          </button>
        </div>
      </aside>

      <main className="content">
        <header className="topbar">
          <div>
            <h1>
              {activeView === "dashboard" ? "Dashboard Overview" : "Settings"}
            </h1>
            <p className="muted">
              {activeView === "dashboard"
                ? "System activity and reporting overview"
                : "Control how this admin workspace behaves on this device."}
            </p>
          </div>
          <div className="profile-card">
            <div>
              <p className="profile-name">{adminName}</p>
              <span className="profile-role">Administrator</span>
            </div>
          </div>
        </header>
        {activeView === "dashboard" ? (
          <>
            <section className="stats">
              {cardStats.map((card) => (
                <div
                  key={card.title}
                  className={`stat-card stat-card-${card.accent}`}
                >
                  <div className="stat-copy">
                    <p className="stat-title">{card.title}</p>
                    <h2>{card.value}</h2>
                    <div className="stat-meta">
                      <span className="stat-subtitle">{card.subtitle}</span>
                    </div>
                  </div>
                  <div className="stat-icon">
                    <AppIcon name={card.iconName} className="stat-icon-svg" />
                  </div>
                </div>
              ))}
            </section>

            <section className="reports">
              <div className="section-header">
                <div>
                  <h2>Reports</h2>
                  <p className="muted">
                    Generate focused admin reports with cleaner filters and faster
                    scanability.
                  </p>
                </div>
                {loading && <span className="loading-pill">Syncing...</span>}
              </div>

              <div className="report-grid">
                {reportCards.map((report) => (
                  <div key={report.key} className="report-card">
                    <div className="report-card-top">
                      <div className="report-card-icon">
                        <AppIcon
                          name={report.icon}
                          className="report-card-icon-svg"
                        />
                      </div>
                      <span className="report-kicker">{report.label}</span>
                    </div>
                    <div className="report-card-copy">
                      <h3>{report.title}</h3>
                      <p className="muted">{report.description}</p>
                    </div>
                    <div className="report-card-controls">{report.controls}</div>
                    <div className="report-card-footer">
                      <span className="report-footer-note">{report.footer}</span>
                      <button className="primary" onClick={report.action}>
                        Generate Report
                      </button>
                    </div>
                  </div>
                ))}
              </div>

              {(reportLoading || reportError || reportResult) && (
                <div className="report-results">
                  <div className="section-header">
                    <div>
                      <h3>{reportResult?.title ?? "Generating report..."}</h3>
                      <p className="muted">
                        {reportError ||
                          reportResult?.summary ||
                          "Preparing the latest report data."}
                      </p>
                    </div>
                    {reportResult && reportResult.rows.length > 0 && (
                      <button
                        className="secondary"
                        onClick={() =>
                          downloadCsv(
                            reportResult.filename,
                            reportResult.columns,
                            reportResult.rows
                          )
                        }
                      >
                        <AppIcon name="export" className="button-icon" />
                        Export CSV
                      </button>
                    )}
                  </div>

                  {reportLoading ? (
                    <div className="report-empty">Generating report...</div>
                  ) : reportError ? (
                    <div className="report-empty">{reportError}</div>
                  ) : reportResult.rows.length === 0 ? (
                    <div className="report-empty">No data matched this report.</div>
                  ) : (
                    <div className="report-table-section">
                      {reportChart && (
                        <div className="report-chart-panel">
                          <div className="report-chart-copy">
                            <h4>{reportChart.title}</h4>
                            <p className="muted">{reportChart.subtitle}</p>
                            <div className="report-chart-legend">
                              {reportChart.data.map((item) => (
                                <div key={item.label} className="report-chart-legend-item">
                                  <span
                                    className="report-chart-swatch"
                                    style={{ background: item.color }}
                                  />
                                  <span className="report-chart-legend-label">
                                    {item.label}
                                  </span>
                                  <strong className="report-chart-legend-value">
                                    {formatChartNumber(item.value)}
                                  </strong>
                                </div>
                              ))}
                            </div>
                          </div>
                          <div
                            className={`report-chart-visual ${
                              reportChart.type === "bars"
                                ? "report-chart-visual-bars"
                                : ""
                            }`}
                          >
                            {reportChart.type === "donut" ? (
                              <DonutChart
                                data={reportChart.data}
                                total={reportChart.total}
                              />
                            ) : (
                              <BarChart
                                data={reportChart.data}
                                maxValue={reportChart.maxValue}
                              />
                            )}
                          </div>
                        </div>
                      )}
                      <div className="report-summary-chips">
                        <span className="summary-chip">
                          {reportResult.rows.length}{" "}
                          {reportResult.rows.length === 1 ? "result" : "results"}{" "}
                          found
                        </span>
                        <span className="summary-chip">
                          Filter: {reportFilterSummary}
                        </span>
                        <span className="summary-chip">
                          Page {reportPage} of {totalReportPages}
                        </span>
                      </div>
                      <div className="report-pagination">
                        <p className="muted">
                          Showing {(reportPage - 1) * reportPageSize + 1}-
                          {Math.min(
                            reportPage * reportPageSize,
                            reportResult.rows.length
                          )}{" "}
                          of {reportResult.rows.length}
                        </p>
                        <div className="report-pagination-controls">
                          <select
                            value={reportPageSize}
                            onChange={(e) => {
                              updateDashboardSetting(
                                "reportPageSize",
                                Number(e.target.value)
                              );
                              setReportPage(1);
                            }}
                          >
                            <option value={50}>50 per page</option>
                            <option value={100}>100 per page</option>
                            <option value={200}>200 per page</option>
                          </select>
                          <button
                            className="secondary"
                            onClick={() =>
                              setReportPage((page) => Math.max(1, page - 1))
                            }
                            disabled={reportPage === 1}
                          >
                            Previous
                          </button>
                          <span className="report-page-indicator">
                            Page {reportPage} of {totalReportPages}
                          </span>
                          <button
                            className="secondary"
                            onClick={() =>
                              setReportPage((page) =>
                                Math.min(totalReportPages, page + 1)
                              )
                            }
                            disabled={reportPage === totalReportPages}
                          >
                            Next
                          </button>
                        </div>
                      </div>
                      <div className="report-table-wrap">
                        <table className="report-table">
                          <thead>
                            <tr>
                              {reportResult.columns.map((column) => (
                                <th key={column}>{column}</th>
                              ))}
                            </tr>
                          </thead>
                          <tbody>
                            {pagedReportRows.map((row, index) => (
                              <tr
                                key={`${
                                  reportResult.title
                                }-${(reportPage - 1) * reportPageSize + index}`}
                              >
                                {reportResult.columns.map((column) => (
                                  <td key={`${column}-${index}`}>{row[column]}</td>
                                ))}
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  )}
                </div>
              )}
            </section>

            <section className="activity">
              <div className="section-header">
                <div>
                  <h2>Recent Activity</h2>
                  <p className="muted">
                    Track the latest admin-facing listing changes and open each row
                    for quick review details.
                  </p>
                </div>
                <button
                  className="link activity-link"
                  onClick={() => setShowAllActivity((value) => !value)}
                >
                  {showAllActivity ? "Show Less" : "View All"}
                </button>
              </div>
              <div className="activity-toolbar">
                <div className="activity-summary">
                  {activitySummary.map((item) => (
                    <button
                      key={item.label}
                      className={`activity-summary-chip ${
                        activityFilter === item.filter ? "active" : ""
                      }`}
                      onClick={() => {
                        setActivityFilter(item.filter);
                        setExpandedActivityId(null);
                      }}
                    >
                      <span>{item.label}</span>
                      <strong>{item.value}</strong>
                    </button>
                  ))}
                </div>
                <p className="activity-helper">
                  Showing {visibleActivity.length} of{" "}
                  {activityFilter === "All"
                    ? activity.length
                    : activity.filter((item) => item.status === activityFilter).length}{" "}
                  {activityFilter === "All"
                    ? "recent activities"
                    : `${activityFilter.toLowerCase()} items`}
                </p>
              </div>
              <div className="activity-table">
                <div className="activity-header">
                  <span>User / Property</span>
                  <span>Type</span>
                  <span>Date Added</span>
                  <span>Status</span>
                  <span>Action</span>
                </div>
                {visibleActivity.map((item) => (
                  <div
                    key={item.id}
                    className={`activity-item ${
                      expandedActivityId === item.id ? "expanded" : ""
                    }`}
                  >
                    <div className="activity-row">
                      <div>
                        <p className="activity-title">{item.title}</p>
                        <span className="muted">{item.subtitle}</span>
                      </div>
                      <span className="chip">{item.type}</span>
                      <span className="activity-date">{item.date}</span>
                      <span className={`status ${statusTone[item.status] || "info"}`}>
                        {statusLabel[item.status] || item.status}
                      </span>
                      <button
                        className="icon-btn activity-action-btn"
                        aria-label="Toggle activity details"
                        onClick={() =>
                          setExpandedActivityId((current) =>
                            current === item.id ? null : item.id
                          )
                        }
                      >
                        <AppIcon name="more" className="button-icon" />
                      </button>
                    </div>
                    {expandedActivityId === item.id && (
                      <div className="activity-details">
                        <div className="activity-detail-card">
                          <span className="activity-detail-label">Record ID</span>
                          <strong>{item.id}</strong>
                        </div>
                        <div className="activity-detail-card">
                          <span className="activity-detail-label">Current Status</span>
                          <strong>{statusLabel[item.status] || item.status}</strong>
                        </div>
                        <div className="activity-detail-card">
                          <span className="activity-detail-label">Category</span>
                          <strong>{item.type}</strong>
                        </div>
                        <div className="activity-detail-card activity-detail-wide">
                          <span className="activity-detail-label">Suggested Next Step</span>
                          <strong>
                            {activityRecommendations[item.status] ??
                              "Review the record details before taking the next admin action."}
                          </strong>
                        </div>
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </section>
          </>
        ) : (
          <section className="settings-view">
            <div className="settings-intro">
              <div>
                <h2>Workspace Preferences</h2>
                <p className="muted">
                  These settings shape the admin dashboard experience on this
                  device and keep reporting a little more tailored to how you
                  work.
                </p>
              </div>
              <button className="secondary" onClick={resetDashboardSettings}>
                Reset Defaults
              </button>
            </div>

            <div className="settings-grid">
              {settingsCards.map((card) => (
                <article key={card.title} className="settings-card">
                  <div className="settings-card-copy">
                    <h3>{card.title}</h3>
                    <p className="muted">{card.description}</p>
                  </div>
                  {card.control}
                </article>
              ))}
            </div>

            <div className="settings-footnote">
              <div className="settings-note-card">
                <span className="settings-note-label">Current Setup</span>
                <strong>{dashboardSettings.reportPageSize} report rows per page</strong>
                <p className="muted">
                  Recent Activity previews {dashboardSettings.activityPreviewCount} rows
                  before expanding, and your recent listing window is set to{" "}
                  {dashboardSettings.newListingWindowDays} days.
                </p>
              </div>
              <div className="settings-note-card">
                <span className="settings-note-label">About Activity</span>
                <strong>Latest 50 listing events loaded</strong>
                <p className="muted">
                  The dashboard keeps Recent Activity focused by loading the most
                  recent 50 listings, while reports still access full report
                  datasets from the backend functions.
                </p>
              </div>
            </div>
          </section>
        )}
      </main>
    </div>
  );
}
