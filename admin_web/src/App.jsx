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
    status: "Published",
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
    status: "Rejected",
  },
];

const statusTone = {
  Published: "success",
  "Pending Audit": "warning",
  Rejected: "danger",
};

const statusLabel = {
  Published: "Published",
  "Pending Audit": "Pending Audit",
  Rejected: "Rejected",
};

export default function App() {
  const [stats, setStats] = useState(demoStats);
  const [activity, setActivity] = useState(demoActivity);
  const [loading, setLoading] = useState(false);
  const [filterCity, setFilterCity] = useState("Any City");
  const [filterType, setFilterType] = useState("All Types");
  const [filterPrice, setFilterPrice] = useState("Any Price");
  const [session, setSession] = useState(null);
  const [authLoading, setAuthLoading] = useState(true);
  const [authError, setAuthError] = useState("");
  const [adminOk, setAdminOk] = useState(true);
  const [adminName, setAdminName] = useState("Super Admin");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");

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
          .limit(6);

        if (!active) return;
        setStats((prev) => ({
          ...prev,
          totalUsers: totalUsers ?? prev.totalUsers,
          activeProperties: activeProperties ?? prev.activeProperties,
          ownerCount: ownerCount ?? prev.ownerCount,
          seekerCount: seekerCount ?? prev.seekerCount,
        }));

        if (recent && recent.length > 0) {
          const formatted = recent.map((item) => ({
            id: `P-${item.property_id}`,
            title: item.property_type ?? "Property",
            subtitle: item.property_city ?? "Unknown",
            type: "Property Listing",
            date: new Date(item.created_at).toLocaleDateString(),
            status: item.status === "active" ? "Published" : "Pending Audit",
          }));
          setActivity(formatted);
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

  const cardStats = useMemo(
    () => [
      {
        title: "Total Users",
        value: stats.totalUsers,
        change: "+1.2% from last month",
        icon: "👥",
      },
      {
        title: "Active Properties",
        value: stats.activeProperties,
        change: "+5% this week",
        icon: "🏠",
      },
      {
        title: "Owners",
        value: stats.ownerCount,
        change: "Registered owners",
        icon: "🧑‍💼",
      },
      {
        title: "Seekers",
        value: stats.seekerCount,
        change: "Registered seekers",
        icon: "🧑‍💻",
      },
    ],
    [stats]
  );

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
          <span className="brand-mark">RE</span>
          <div>
            <p className="brand-title">AdminPortal</p>
            <p className="brand-subtitle">AMAN Dashboard</p>
          </div>
        </div>
        <nav className="menu">
          <button className="menu-item active">
            <span>🏠</span> Dashboard
          </button>
          <button className="menu-item">
            <span>⚙️</span> Settings
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
            <h1>Dashboard Overview</h1>
            <p className="muted">System activity and reporting overview</p>
          </div>
          <div className="profile">
            <button className="icon-btn">🔔</button>
            <div className="profile-card">
              <div className="profile-avatar">SA</div>
              <div>
                <p className="profile-name">{adminName}</p>
                <span className="profile-role">Administrator</span>
              </div>
            </div>
          </div>
        </header>

        <section className="stats">
          {cardStats.map((card) => (
            <div key={card.title} className="stat-card">
              <div>
                <p className="stat-title">{card.title}</p>
                <h2>{card.value}</h2>
                <span className="stat-change">{card.change}</span>
              </div>
              <div className="stat-icon">{card.icon}</div>
            </div>
          ))}
        </section>

        <section className="reports">
          <div className="section-header">
            <div>
              <h2>3.3 Admin Reports</h2>
              <p className="muted">
                Generate and oversee platform operations reporting.
              </p>
            </div>
            {loading && <span className="loading-pill">Syncing...</span>}
          </div>

          <div className="report-grid">
            <div className="report-card">
              <h3>Owner Reports</h3>
              <p className="muted">Property Type</p>
              <select value={filterType} onChange={(e) => setFilterType(e.target.value)}>
                <option>All Types</option>
                <option>Apartment</option>
                <option>House</option>
                <option>Land</option>
              </select>
              <button className="primary">Generate Report</button>
            </div>
            <div className="report-card">
              <h3>Seeker Reports</h3>
              <p className="muted">Preferred Type</p>
              <select value={filterType} onChange={(e) => setFilterType(e.target.value)}>
                <option>All Preferred</option>
                <option>Apartment</option>
                <option>House</option>
                <option>Land</option>
              </select>
              <button className="primary">Generate Report</button>
            </div>
            <div className="report-card">
              <h3>Filter Properties</h3>
              <div className="report-filters">
                <div>
                  <p className="muted">City</p>
                  <select value={filterCity} onChange={(e) => setFilterCity(e.target.value)}>
                    <option>Any City</option>
                    <option>Khartoum</option>
                    <option>Port Sudan</option>
                    <option>Suakin</option>
                  </select>
                </div>
                <div>
                  <p className="muted">Price</p>
                  <select value={filterPrice} onChange={(e) => setFilterPrice(e.target.value)}>
                    <option>Any Price</option>
                    <option>Below 1M</option>
                    <option>1M - 5M</option>
                    <option>5M+</option>
                  </select>
                </div>
              </div>
              <button className="primary">Apply Filters</button>
            </div>
          </div>

          <div className="notice">
            <div className="notice-line" />
            <p className="muted">
              System administrator oversees platform operations and reporting.
              Reports can be viewed or exported directly. Admin does not interfere
              with property offers or users directly.
            </p>
          </div>
        </section>

        <section className="activity">
          <div className="section-header">
            <h2>Recent Activity</h2>
            <button className="link">View All</button>
          </div>
          <div className="activity-table">
            <div className="activity-header">
              <span>User / Property</span>
              <span>Type</span>
              <span>Date Added</span>
              <span>Status</span>
              <span>Action</span>
            </div>
            {activity.map((item) => (
              <div key={item.id} className="activity-row">
                <div>
                  <p className="activity-title">{item.title}</p>
                  <span className="muted">{item.subtitle}</span>
                </div>
                <span className="chip">{item.type}</span>
                <span>{item.date}</span>
                <span className={`status ${statusTone[item.status] || "info"}`}>
                  {statusLabel[item.status] || item.status}
                </span>
                <button className="icon-btn">⋯</button>
              </div>
            ))}
          </div>
        </section>
      </main>
    </div>
  );
}
