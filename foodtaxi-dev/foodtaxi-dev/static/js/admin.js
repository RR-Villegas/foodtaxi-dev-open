const STORAGE_KEY = "demoShopData_v1";
let state = {
  products: [],
  orders: [],
  customers: [],
  settings: { storeName: "My Shop", currency: "₱" },
};

function seedDemo() {
  if (localStorage.getItem(STORAGE_KEY)) {
    state = JSON.parse(localStorage.getItem(STORAGE_KEY));
    return;
  }
  state.products = [
    {
      id: 1,
      name: "Leather Wallet",
      sku: "WAL-001",
      price: 450,
      stock: 12,
      category: "Accessories",
      desc: "Minimal leather wallet",
    },
    {
      id: 2,
      name: "Wireless Earbuds",
      sku: "AUD-223",
      price: 2990,
      stock: 6,
      category: "Electronics",
      desc: "Bluetooth 5.2",
    },
    {
      id: 3,
      name: "Cotton T-Shirt",
      sku: "CLO-010",
      price: 499,
      stock: 20,
      category: "Clothing",
      desc: "Unisex tee",
    },
  ];
  state.customers = [
    {
      id: 1,
      name: "Maria Santos",
      email: "maria@example.com",
      orders: 2,
    },
    { id: 2, name: "John Cruz", email: "john@example.com", orders: 1 },
  ];
  state.orders = [
    {
      id: 101,
      customer: "Maria Santos",
      total: 499,
      status: "Fulfilled",
      when: Date.now() - 86400000,
    },
    {
      id: 102,
      customer: "John Cruz",
      total: 2990,
      status: "Processing",
      when: Date.now() - 3600000,
    },
  ];
  saveState();
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  renderAll();
}

function renderAll() {
  document.getElementById("totalProducts").textContent = state.products.length;
  document.getElementById("totalOrders").textContent = state.orders.length;
  document.getElementById("totalCustomers").textContent =
    state.customers.length;
  const totalSales = state.orders.reduce((s, o) => s + o.total, 0);
  document.getElementById("totalSales").textContent =
    (state.settings.currency || "₱") + totalSales.toLocaleString();
  renderProducts();
  renderOrders();
  renderCustomers();
  renderRecentOrders();
  renderChart();
}

function renderProducts() {
  const tbody = document.querySelector("#productsTable tbody");
  tbody.innerHTML = "";
  const tbodyFull = document.querySelector("#productsTableFull tbody");
  tbodyFull.innerHTML = "";
  state.products.forEach((p) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `<td><div style="display:flex;gap:10px;align-items:center"><div class=\"avatar\">${
      p.name[0]
    }</div><div><strong>${
      p.name
    }</strong><div style=\"color:var(--muted);font-size:12px\">${
      p.desc
    }</div></div></div></td><td>${p.sku}</td><td>${
      state.settings.currency || "₱"
    }${p.price}</td><td>${
      p.stock
    }</td><td><button class=\"btn ghost\" onclick=\"editProduct(${
      p.id
    })\">Edit</button> <button class=\"btn ghost\" onclick=\"deleteProduct(${
      p.id
    })\">Delete</button></td>`;
    tbody.appendChild(tr);

    const tr2 = document.createElement("tr");
    tr2.innerHTML = `<td>${p.name}</td><td>${p.sku}</td><td>${
      state.settings.currency || "₱"
    }${p.price}</td><td>${p.stock}</td><td>${
      p.category || ""
    }</td><td><button class=\"btn ghost\" onclick=\"editProduct(${
      p.id
    })\">Edit</button> <button class=\"btn ghost\" onclick=\"deleteProduct(${
      p.id
    })\">Delete</button></td>`;
    tbodyFull.appendChild(tr2);
  });
  document.getElementById("totalProducts").textContent = state.products.length;
}

function renderOrders() {
  const tbody = document.querySelector("#ordersTable tbody");
  tbody.innerHTML = "";
  state.orders.forEach((o) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `<td>#${o.id}</td><td>${o.customer}</td><td>${
      state.settings.currency || "₱"
    }${o.total}</td><td><span class=\"tag\">${
      o.status
    }</span></td><td><button class=\"btn ghost\" onclick=\"viewOrder(${
      o.id
    })\">View</button></td>`;
    tbody.appendChild(tr);
  });
}

function renderCustomers() {
  const tbody = document.querySelector("#customersTable tbody");
  tbody.innerHTML = "";
  state.customers.forEach((c) => {
    const tr = document.createElement("tr");
    tr.innerHTML = `<td>${c.name}</td><td>${c.email}</td><td>${c.orders}</td><td><button class=\"btn ghost\" onclick=\"messageCustomer(${c.id})\">Message</button></td>`;
    tbody.appendChild(tr);
  });
}

function renderRecentOrders() {
  const container = document.getElementById("recentOrders");
  container.innerHTML = "";
  state.orders.slice(0, 6).forEach((o) => {
    const el = document.createElement("div");
    el.style.padding = "8px 0";
    el.innerHTML = `<strong>#${o.id}</strong> — ${
      o.customer
    } <div style=\"color:var(--muted);font-size:13px\">${new Date(
      o.when
    ).toLocaleString()} • ${state.settings.currency || "₱"}${o.total}</div>`;
    container.appendChild(el);
  });
}

// --- Modal ---
let editingId = null;
function openModal(name) {
  document.getElementById("modalBackdrop").style.display = "grid";
  document.getElementById("modalTitle").textContent =
    name === "addProduct" ? "Add product" : "Edit product";
  if (name === "addProduct") {
    editingId = null;
    document.getElementById("p_name").value = "";
    document.getElementById("p_price").value = "";
    document.getElementById("p_stock").value = "";
    document.getElementById("p_sku").value = "";
    document.getElementById("p_desc").value = "";
  }
}
function closeModal() {
  document.getElementById("modalBackdrop").style.display = "none";
}

function saveProduct() {
  const name = document.getElementById("p_name").value.trim();
  if (!name) {
    alert("Product needs a name");
    return;
  }
  const sku =
    document.getElementById("p_sku").value.trim() ||
    "SKU-" + Math.floor(Math.random() * 9999);
  const price = Number(document.getElementById("p_price").value) || 0;
  const stock = Number(document.getElementById("p_stock").value) || 0;
  const desc = document.getElementById("p_desc").value || "";
  if (editingId) {
    const p = state.products.find((x) => x.id === editingId);
    Object.assign(p, { name, sku, price, stock, desc });
  } else {
    const id = state.products.length
      ? Math.max(...state.products.map((x) => x.id)) + 1
      : 1;
    state.products.unshift({ id, name, sku, price, stock, desc });
  }
  closeModal();
  saveState();
}

function editProduct(id) {
  const p = state.products.find((x) => x.id === id);
  if (!p) return;
  editingId = id;
  document.getElementById("p_name").value = p.name;
  document.getElementById("p_price").value = p.price;
  document.getElementById("p_stock").value = p.stock;
  document.getElementById("p_sku").value = p.sku;
  document.getElementById("p_desc").value = p.desc;
  openModal("edit");
}
function deleteProduct(id) {
  if (!confirm("Delete product?")) return;
  state.products = state.products.filter((x) => x.id !== id);
  saveState();
}

function viewOrder(id) {
  const o = state.orders.find((x) => x.id === id);
  if (!o) return;
  alert(
    "Order #" +
      o.id +
      "\nCustomer: " +
      o.customer +
      "\nTotal: " +
      (state.settings.currency || "₱") +
      o.total +
      "\nStatus: " +
      o.status
  );
}
function messageCustomer(id) {
  const c = state.customers.find((x) => x.id === id);
  if (!c) return;
  alert("Message " + c.email + " (demo)");
}

// --- Navigation ---
document.querySelectorAll(".nav a").forEach((a) =>
  a.addEventListener("click", (e) => {
    e.preventDefault();
    document
      .querySelectorAll(".nav a")
      .forEach((x) => x.classList.remove("active"));
    a.classList.add("active");
    const sec = a.dataset.section;
    document
      .querySelectorAll(".section")
      .forEach((s) => (s.style.display = s.id === sec ? "block" : "none"));
  })
);

// --- Search ---
function liveSearch(q) {
  q = q.trim().toLowerCase();
  if (!q) {
    renderAll();
    return;
  } // simple filter: highlight products
  const tbody = document.querySelector("#productsTable tbody");
  tbody.innerHTML = "";
  state.products
    .filter(
      (p) =>
        p.name.toLowerCase().includes(q) ||
        (p.sku || "").toLowerCase().includes(q)
    )
    .forEach((p) => {
      const tr = document.createElement("tr");
      tr.innerHTML = `<td>${p.name}</td><td>${p.sku}</td><td>${
        state.settings.currency || "₱"
      }${p.price}</td><td>${
        p.stock
      }</td><td><button class=\"btn ghost\">Edit</button></td>`;
      tbody.appendChild(tr);
    });
}

// --- Settings ---
function saveSettings() {
  state.settings.storeName =
    document.getElementById("storeName").value || state.settings.storeName;
  state.settings.currency =
    document.getElementById("currency").value || state.settings.currency;
  saveState();
  alert("Saved");
}

function signOut() {
  alert("Signed out (demo)");
}

// --- CSV export ---
function downloadCSV() {
  const rows = [["id", "name", "sku", "price", "stock"]];
  state.products.forEach((p) =>
    rows.push([p.id, p.name, p.sku, p.price, p.stock])
  );
  const csv = rows
    .map((r) => r.map((c) => `"${String(c).replace(/"/g, '""')}"`).join(","))
    .join("\n");
  const blob = new Blob([csv], { type: "text/csv" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "products.csv";
  a.click();
  URL.revokeObjectURL(url);
}

// --- Simple sales chart (vanilla canvas) ---
function renderChart() {
  const canvas = document.getElementById("salesChart");
  const ctx = canvas.getContext("2d");
  const w = canvas.clientWidth;
  canvas.width = w * devicePixelRatio;
  canvas.height = 120 * devicePixelRatio;
  ctx.scale(devicePixelRatio, devicePixelRatio);
  const days = 7;
  const labels = [];
  const values = [];
  for (let i = days - 1; i >= 0; i--) {
    labels.push(new Date(Date.now() - i * 86400000).toLocaleDateString());
    values.push(Math.floor(Math.random() * 2000));
  }
  const max = Math.max(...values) || 1;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  // draw grid
  ctx.strokeStyle = "rgba(255,255,255,0.04)";
  ctx.lineWidth = 1;
  for (let i = 0; i < 5; i++) {
    const y = 20 + i * 20;
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(w, y);
    ctx.stroke();
  }
  // draw line
  ctx.beginPath();
  values.forEach((v, i) => {
    const x = (w - 40) * (i / (values.length - 1)) + 20;
    const y = 100 - (v / max) * 70;
    if (i === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.strokeStyle = "rgba(79,70,229,0.9)";
  ctx.lineWidth = 2;
  ctx.stroke();
  // points
  values.forEach((v, i) => {
    const x = (w - 40) * (i / (values.length - 1)) + 20;
    const y = 100 - (v / max) * 70;
    ctx.beginPath();
    ctx.arc(x, y, 3, 0, Math.PI * 2);
    ctx.fillStyle = "white";
    ctx.fill();
  });
}

// --- Utilities ---
function downloadFile(filename, text) {
  const a = document.createElement("a");
  a.href = "data:text/plain;charset=utf-8," + encodeURIComponent(text);
  a.download = filename;
  a.click();
}

// --- Initialization ---
seedDemo();
document.getElementById("storeName").value = state.settings.storeName;
document.getElementById("currency").value = state.settings.currency;

// Re-render on resize for chart
let rto;
window.addEventListener("resize", () => {
  clearTimeout(rto);
  rto = setTimeout(renderChart, 200);
});
