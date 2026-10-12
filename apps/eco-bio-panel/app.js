const $ = (selector, root = document) => root.querySelector(selector);
const $$ = (selector, root = document) => [...root.querySelectorAll(selector)];
const SUPABASE_SDK = "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.58.0/+esm";
const SITE_ORIGIN = "https://eco-bio-panel.helenlopezj669.chatgpt.site";
let supabase = null;
let language = localStorage.getItem("eco-bio-language") || "vi";
let currentAdminTable = "products";
let adminSession = null;

const tableDefinitions = {
  products: { title: "Sản phẩm", label: "CATALOG / 01", cols: ["name", "status", "is_active", "created_at"], headers: ["TÊN", "TRẠNG THÁI", "ĐANG HIỂN THỊ", "TẠO LÚC"], order: "created_at", fields: [
    ["name", "Tên sản phẩm", "text", true], ["description", "Mô tả ngắn", "textarea"], ["dimensions", "Kích thước", "text"], ["expected_price_vnd", "Giá dự kiến (VND)", "number"], ["image_path", "Đường dẫn ảnh trong Storage", "text"], ["status", "Trạng thái", "select", ["research", "pilot", "available"], true], ["is_active", "Hiển thị công khai", "checkbox"]
  ]},
  material_collections: { title: "Phiếu thu gom", label: "COLLECTIONS / 02", cols: ["material_type", "amount_kg", "collection_date", "status", "is_public"], headers: ["NGUYÊN LIỆU", "KHỐI LƯỢNG (KG)", "NGÀY THU GOM", "TRẠNG THÁI", "CÔNG KHAI"], order: "created_at", fields: [
    ["material_type", "Nguyên liệu", "select", ["straw", "hair"], true], ["amount_kg", "Khối lượng thực tế (kg)", "number", true], ["collection_date", "Ngày thu gom", "date", true], ["status", "Trạng thái", "select", ["pending", "confirmed", "rejected"], true], ["is_public", "Công khai số liệu", "checkbox"]
  ]},
  production_batches: { title: "Lô sản xuất", label: "PRODUCTION / 03", cols: ["batch_code", "production_date", "panels_count", "status", "is_public"], headers: ["MÃ LÔ", "NGÀY SẢN XUẤT", "SỐ TẤM", "TRẠNG THÁI", "CÔNG KHAI"], order: "created_at", fields: [
    ["batch_code", "Mã lô", "text", true], ["production_date", "Ngày sản xuất", "date"], ["panels_count", "Số tấm đã sản xuất", "number", true], ["straw_used_kg", "Rơm đã dùng (kg)", "number"], ["hair_used_kg", "Tóc đã dùng (kg)", "number"], ["status", "Trạng thái", "select", ["draft", "confirmed"], true], ["is_public", "Công khai", "checkbox"]
  ]},
  lab_tests: { title: "Kết quả Eco Lab", label: "ECO LAB / 04", cols: ["test_type", "sample_code", "test_date", "status", "is_public"], headers: ["PHÉP THỬ", "MÃ MẪU", "NGÀY THỬ", "TRẠNG THÁI", "CÔNG KHAI"], order: "created_at", fields: [
    ["test_type", "Loại thử nghiệm", "select", ["acoustic", "durability", "humidity", "fire_safety", "other"], true], ["sample_code", "Mã mẫu", "text", true], ["passport_code", "Mã hộ chiếu liên quan (nếu có)", "text"], ["test_date", "Ngày thử", "date", true], ["result_summary", "Tóm tắt kết quả / điều kiện đo", "textarea", true], ["method", "Phương pháp / đơn vị thực hiện", "text"], ["evidence_path", "Đường dẫn file minh chứng trong Storage", "text"], ["status", "Trạng thái", "select", ["preliminary", "verified"], true], ["is_public", "Công khai kết quả", "checkbox"]
  ]},
  product_passports: { title: "Eco-Passport", label: "PASSPORTS / 05", cols: ["passport_code", "material_summary", "status", "created_at"], headers: ["MÃ HỒ SƠ", "VẬT LIỆU", "TRẠNG THÁI", "TẠO LÚC"], order: "created_at", fields: [
    ["passport_code", "Mã hộ chiếu", "text", true], ["batch_code", "Mã lô liên quan (nếu có)", "text"], ["material_summary", "Tóm tắt nguyên liệu", "text", true], ["status", "Trạng thái", "select", ["draft", "published"], true], ["usage_notes", "Hướng dẫn sử dụng", "textarea"]
  ]},
  partner_applications: { title: "Đăng ký đối tác", label: "NETWORK / 06", cols: ["contact_name", "email", "partner_type", "material_types", "status", "created_at"], headers: ["CÁ NHÂN / ĐƠN VỊ", "EMAIL", "LOẠI ĐỐI TÁC", "NGUỒN NGUYÊN LIỆU", "TRẠNG THÁI", "NGÀY GỬI"], order: "created_at"},
  customer_inquiries: { title: "Đề nghị khách hàng", label: "INQUIRIES / 07", cols: ["name", "contact_info", "quantity", "status", "created_at"], headers: ["KHÁCH HÀNG", "THÔNG TIN LIÊN HỆ", "SỐ LƯỢNG QUAN TÂM", "TRẠNG THÁI", "NGÀY GỬI"], order: "created_at"}
};

function applyLanguage(next) {
  language = next;
  localStorage.setItem("eco-bio-language", language);
  document.documentElement.lang = language;
  $$('[data-vi][data-en]').forEach((node) => {
    const value = node.dataset[language];
    if (value !== undefined) node.innerHTML = value;
  });
  const toggle = $("#language-toggle");
  if (toggle) { toggle.textContent = language === "vi" ? "EN" : "VI"; toggle.setAttribute("aria-label", language === "vi" ? "Switch to English" : "Chuyển sang tiếng Việt"); }
}

function showToast(message) {
  const toast = $("#toast");
  if (!toast) return;
  toast.textContent = message;
  toast.classList.add("show");
  clearTimeout(showToast.timer);
  showToast.timer = setTimeout(() => toast.classList.remove("show"), 2700);
}

function setFormStatus(element, message, kind = "") {
  element.textContent = message;
  element.className = `form-status ${kind}`.trim();
}

function connectionMessage() {
  return language === "vi"
    ? "Biểu mẫu chưa gửi: Supabase chưa được kết nối. Nhóm chưa nhận thông tin của bạn."
    : "Not sent: Supabase is not connected. The project team has not received your details.";
}

async function connectSupabase() {
  const cfg = window.ECO_SUPABASE_CONFIG || {};
  const configured = /^https:\/\/[\w-]+\.supabase\.co$/.test(cfg.url || "") && /^sb_publishable_[A-Za-z0-9_-]+$/.test(cfg.publishableKey || "");
  const state = $("#admin-connection-state");
  if (!configured) {
    if (state) state.textContent = language === "vi" ? "CHƯA KẾT NỐI DATABASE" : "DATABASE NOT CONNECTED";
    setFormStatus($("#partner-status"), language === "vi" ? "Bản xem trước: chưa kết nối Supabase nên biểu mẫu chưa nhận đăng ký." : "Preview mode: Supabase is not connected, so this form cannot receive registrations.");
    setFormStatus($("#inquiry-status"), language === "vi" ? "Bản xem trước: chưa kết nối Supabase nên biểu mẫu chưa nhận đăng ký." : "Preview mode: Supabase is not connected, so this form cannot receive requests.");
    return null;
  }
  try {
    const { createClient } = await import(SUPABASE_SDK);
    supabase = createClient(cfg.url, cfg.publishableKey, { auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true } });
    if (state) state.textContent = language === "vi" ? "SUPABASE ĐÃ CẤU HÌNH" : "SUPABASE CONFIGURED";
    return supabase;
  } catch (error) {
    if (state) state.textContent = language === "vi" ? "KHÔNG TẢI ĐƯỢC SUPABASE SDK" : "SUPABASE SDK UNAVAILABLE";
    console.error("Supabase client could not load", error);
    return null;
  }
}

function initNavigation() {
  const toggle = $("#menu-toggle");
  const nav = $("#main-nav");
  toggle?.addEventListener("click", () => {
    const open = nav.classList.toggle("open");
    toggle.setAttribute("aria-expanded", String(open));
  });
  $$("#main-nav a").forEach((link) => link.addEventListener("click", () => {
    nav.classList.remove("open");
    toggle?.setAttribute("aria-expanded", "false");
  }));
  $("#language-toggle")?.addEventListener("click", () => {
    applyLanguage(language === "vi" ? "en" : "vi");
    if (supabase) loadPublicData();
    else {
      const notice = language === "vi" ? "Bản xem trước: chưa kết nối Supabase nên biểu mẫu chưa nhận đăng ký." : "Preview mode: Supabase is not connected, so the forms cannot receive requests.";
      setFormStatus($("#partner-status"), notice); setFormStatus($("#inquiry-status"), notice);
    }
  });
}

function passportLink(code) {
  const origin = location.origin === "null" ? SITE_ORIGIN : location.origin;
  const url = new URL(origin);
  url.searchParams.set("passport", code);
  return url.href;
}

function renderSamplePassport(code = "EBP-DEMO-001") {
  const codeNode = $("#passport-result-code");
  codeNode.textContent = code;
  const qr = $("#passport-qr");
  const qrUrl = `https://api.qrserver.com/v1/create-qr-code/?size=180x180&margin=5&color=244c39&bgcolor=f2f0e5&data=${encodeURIComponent(passportLink(code))}`;
  qr.src = qrUrl;
  qr.onerror = () => { qr.hidden = true; };
}

function initPassport() {
  renderSamplePassport();
  const params = new URLSearchParams(location.search);
  const requested = params.get("passport");
  if (requested) {
    $("#passport-code").value = requested;
    lookupPassport(requested);
    setTimeout(() => $("#passport").scrollIntoView({ behavior: "smooth" }), 80);
  }
  $("#passport-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const code = $("#passport-code").value.trim();
    if (code) await lookupPassport(code);
  });
  $("#copy-passport-link")?.addEventListener("click", async () => {
    try { await navigator.clipboard.writeText(passportLink($("#passport-result-code").textContent)); showToast(language === "vi" ? "Đã sao chép liên kết hồ sơ." : "Passport link copied."); }
    catch { showToast(passportLink($("#passport-result-code").textContent)); }
  });
}

async function lookupPassport(code) {
  const card = $("#passport-result");
  card.classList.remove("is-not-found");
  if (supabase) {
    const { data, error } = await supabase.from("product_passports").select("passport_code,material_summary,status,usage_notes,production_batches(batch_code,production_date,panels_count),lab_tests(test_type,test_date,result_summary,status)").eq("passport_code", code).eq("status", "published").maybeSingle();
    if (error) { showToast(language === "vi" ? "Chưa thể tra cứu hồ sơ. Kiểm tra kết nối dữ liệu." : "Could not load this passport. Check the database connection."); return; }
    if (data) {
      $("#passport-result-code").textContent = data.passport_code;
      const details = $$(".passport-details > div", card);
      details[0].querySelector("b").textContent = data.material_summary || "—";
      details[1].querySelector("b").textContent = data.production_batches?.batch_code ? `${data.production_batches.batch_code} · ${data.production_batches.panels_count ?? "—"} tấm` : (language === "vi" ? "Đã công bố" : "Published");
      details[2].querySelector("b").textContent = data.lab_tests?.length ? `${data.lab_tests.length} ${language === "vi" ? "kết quả" : "results"}` : (language === "vi" ? "Chưa cập nhật" : "Not yet available");
      $(".passport-card-footer span", card).textContent = data.usage_notes || (language === "vi" ? "Hồ sơ được công bố bởi Eco-Bio Panel." : "Published by Eco-Bio Panel.");
      renderSamplePassport(data.passport_code);
      return;
    }
  }
  if (code.toUpperCase() === "EBP-DEMO-001") {
    renderSamplePassport("EBP-DEMO-001");
    $$(".passport-details > div", card).forEach((detail, index) => {
      const value = [language === "vi" ? "Rơm rạ + tóc tái chế" : "Rice straw + recycled hair", language === "vi" ? "Mẫu nghiên cứu" : "Research sample", language === "vi" ? "Chưa cập nhật" : "Not yet available"][index];
      detail.querySelector("b").textContent = value;
    });
    $(".passport-card-footer span", card).textContent = language === "vi" ? "Hồ sơ mẫu · Chưa gắn với lô sản xuất thật" : "Sample record · Not linked to a production batch";
    return;
  }
  card.classList.add("is-not-found");
  showToast(language === "vi" ? "Không tìm thấy hồ sơ đã công bố cho mã này." : "No published passport was found for this code.");
}

function initForms() {
  $("#partner-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const status = $("#partner-status");
    if (!supabase) { setFormStatus(status, connectionMessage(), "error"); return; }
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    const types = form.get("material_type") === "both" ? ["hair", "straw"] : [form.get("material_type")];
    const { error } = await supabase.from("partner_applications").insert({
      contact_name: String(form.get("name")).trim(), email: String(form.get("email")).trim(), phone: String(form.get("phone") || "").trim() || null,
      partner_type: form.get("partner_type"), material_types: types,
      estimated_kg: form.get("estimated_kg") ? Number(form.get("estimated_kg")) : null,
      address_text: String(form.get("message") || "").trim() || null, consent: form.get("consent") === "on"
    });
    if (error) { setFormStatus(status, language === "vi" ? "Chưa gửi được đăng ký. Vui lòng thử lại sau." : "Registration could not be sent. Please try again.", "error"); return; }
    formElement.reset();
    setFormStatus(status, language === "vi" ? "Đã gửi đăng ký. Nhóm sẽ liên hệ với bạn." : "Registration sent. The team will follow up.", "success");
  });
  $("#inquiry-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const status = $("#inquiry-status");
    if (!supabase) { setFormStatus(status, connectionMessage(), "error"); return; }
    const formElement = event.currentTarget;
    const form = new FormData(formElement);
    const contact = String(form.get("contact")).trim();
    const { error } = await supabase.from("customer_inquiries").insert({
      name: String(form.get("name")).trim(), contact_info: contact,
      email: contact.includes("@") ? contact : null, phone: contact.includes("@") ? null : contact,
      quantity: Number(form.get("quantity") || 1), inquiry_type: "sample_interest", consent: form.get("consent") === "on"
    });
    if (error) { setFormStatus(status, language === "vi" ? "Chưa gửi được đăng ký. Vui lòng thử lại sau." : "Your request could not be sent. Please try again.", "error"); return; }
    formElement.reset();
    setFormStatus(status, language === "vi" ? "Đã nhận đăng ký quan tâm. Nhóm sẽ liên hệ khi có mẫu phù hợp." : "Interest registered. The team will follow up when a sample is available.", "success");
  });
}

async function loadPublicData() {
  if (!supabase) return;
  const { data: products, error: productError } = await supabase.from("products").select("name,description,dimensions,status,expected_price_vnd").eq("is_active", true).order("created_at", { ascending: false }).limit(1);
  if (!productError && products?.[0]) {
    const product = products[0];
    $("#product-name").textContent = product.name;
    if (product.description) $("#product-description").textContent = product.description;
    if (product.dimensions) $("#product-dimensions").textContent = product.dimensions;
    if (product.expected_price_vnd != null) $("#product-price").textContent = `${Number(product.expected_price_vnd).toLocaleString(language === "vi" ? "vi-VN" : "en-US")} ₫`;
    const statusNames = { research: language === "vi" ? "Đang nghiên cứu" : "In research", pilot: language === "vi" ? "Thử nghiệm thị trường" : "Pilot", available: language === "vi" ? "Đang giới thiệu" : "Available" };
    $("#product-certification").textContent = statusNames[product.status] || (language === "vi" ? "Chưa cập nhật" : "Not yet available");
  }
  const { data: impact, error: impactError } = await supabase.rpc("get_eco_impact");
  if (!impactError && impact) {
    const metrics = { straw: impact.straw_kg, hair: impact.hair_kg, panels: impact.panels, partners: impact.partners };
    Object.entries(metrics).forEach(([key, value]) => {
      const node = $(`[data-impact="${key}"]`);
      if (node) node.textContent = value == null ? "—" : Number(value).toLocaleString(language === "vi" ? "vi-VN" : "en-US", { maximumFractionDigits: 1 });
    });
    $("#impact-source-text").textContent = language === "vi" ? "Cập nhật từ hồ sơ đã xác nhận" : "Updated from confirmed records";
  }
  const { data: tests, error: testsError } = await supabase.from("lab_tests").select("test_type,test_date,result_summary,status").eq("is_public", true).order("test_date", { ascending: false }).limit(8);
  if (!testsError && tests?.length) {
    const grid = $("#lab-grid");
    grid.replaceChildren();
    const typeTitles = { acoustic: ["Khả năng tiêu âm", "Acoustic performance"], durability: ["Độ bền vật liệu", "Material durability"], humidity: ["Độ ẩm & bảo quản", "Humidity & care"], fire_safety: ["An toàn cháy", "Fire safety"], other: ["Thử nghiệm khác", "Other test"] };
    tests.forEach((test, index) => {
      const article = document.createElement("article"); article.className = "lab-card";
      const stamp = document.createElement("span"); stamp.className = "lab-index"; stamp.textContent = `LAB / ${String(index + 1).padStart(2, "0")}`;
      const title = document.createElement("h3"); title.textContent = typeTitles[test.test_type]?.[language === "vi" ? 0 : 1] || test.test_type;
      const desc = document.createElement("p"); desc.textContent = `${test.test_date || ""}${test.result_summary ? ` · ${test.result_summary}` : ""}`;
      const state = document.createElement("span"); state.className = "lab-empty"; state.textContent = test.status === "verified" ? (language === "vi" ? "ĐÃ KIỂM ĐỊNH" : "VERIFIED") : (language === "vi" ? "DỮ LIỆU SƠ BỘ" : "PRELIMINARY DATA");
      article.append(stamp, title, desc, state); grid.append(article);
    });
    $("#lab-data-status").textContent = language === "vi" ? `${tests.length} kết quả được công bố` : `${tests.length} published results`;
  }
}

function humanize(value) {
  if (value == null || value === "") return "—";
  if (typeof value === "boolean") return value ? "Có" : "Không";
  if (Array.isArray(value)) return value.join(", ");
  if (typeof value === "object") return value.batch_code || value.name || value.id || "—";
  return String(value);
}

async function loadAdminTable(table) {
  if (!supabase || !adminSession) return;
  const def = tableDefinitions[table];
  currentAdminTable = table;
  $("#admin-table-label").textContent = def.label;
  $("#admin-table-title").textContent = def.title;
  const head = $("#admin-table-head"); head.replaceChildren();
  const tr = document.createElement("tr");
  def.headers.forEach((label) => { const th = document.createElement("th"); th.textContent = label; tr.append(th); });
  if (def.cols.includes("status") || def.cols.includes("is_active")) { const th = document.createElement("th"); th.textContent = "CẬP NHẬT"; tr.append(th); }
  head.append(tr);
  const body = $("#admin-table-body"); body.replaceChildren();
  const { data, error } = await supabase.from(table).select("*").order(def.order, { ascending: false }).limit(60);
  if (error) {
    const row = document.createElement("tr"), cell = document.createElement("td"); cell.colSpan = def.cols.length + Number(def.cols.includes("status") || def.cols.includes("is_active")); cell.textContent = "Không tải được dữ liệu. Kiểm tra migration và quyền RLS."; row.append(cell); body.append(row); return;
  }
  if (!data?.length) {
    const row = document.createElement("tr"), cell = document.createElement("td"); cell.colSpan = def.cols.length + Number(def.cols.includes("status") || def.cols.includes("is_active")); cell.textContent = "Chưa có bản ghi."; row.append(cell); body.append(row); return;
  }
  data.forEach((record) => {
    const row = document.createElement("tr");
    def.cols.forEach((col) => { const td = document.createElement("td"); const value = humanize(record[col]); td.textContent = col === "created_at" || col.endsWith("_date") ? (value === "—" ? value : new Date(value).toLocaleDateString(language === "vi" ? "vi-VN" : "en-US")) : value; row.append(td); });
    if (def.cols.includes("status") || def.cols.includes("is_active")) {
      const transitions = {
        material_collections: { pending: ["confirmed", "Xác nhận"], confirmed: ["rejected", "Từ chối"], rejected: ["pending", "Mở lại"] },
        production_batches: { draft: ["confirmed", "Xác nhận lô"], confirmed: ["draft", "Đưa về nháp"] },
        partner_applications: { pending: ["verified", "Duyệt đối tác"], verified: ["rejected", "Từ chối"], rejected: ["verified", "Duyệt lại"] },
        customer_inquiries: { new: ["contacted", "Đã liên hệ"], contacted: ["closed", "Đóng"], closed: ["new", "Mở lại"] },
        product_passports: { draft: ["published", "Công bố"], published: ["draft", "Ẩn hồ sơ"] },
        lab_tests: { preliminary: ["verified", "Xác minh"], verified: ["preliminary", "Đưa về sơ bộ"] }
      };
      const action = transitions[table]?.[record.status] || (table === "products" ? [!record.is_active, record.is_active ? "Ẩn sản phẩm" : "Hiển thị sản phẩm"] : null);
      const cell = document.createElement("td");
      if (action) {
        const button = document.createElement("button"); button.type = "button"; button.className = "admin-inline-action"; button.textContent = action[1];
        button.addEventListener("click", async () => {
          const patch = table === "products" ? { is_active: action[0] } : { status: action[0] };
          if (table === "partner_applications" && action[0] === "verified") patch.is_public = true;
          const { error: updateError } = await supabase.from(table).update(patch).eq("id", record.id);
          if (updateError) { showToast("Không cập nhật được bản ghi. Kiểm tra quyền RLS."); return; }
          await loadAdminTable(table); await loadAdminCounts(); await loadPublicData();
        });
        cell.append(button);
      } else cell.textContent = "—";
      if (table === "products") {
        const edit = document.createElement("button"); edit.type = "button"; edit.className = "admin-inline-action"; edit.textContent = "Sửa"; edit.style.marginLeft = "5px";
        edit.addEventListener("click", () => renderEntryForm(tableDefinitions.products, record));
        cell.append(edit);
      }
      row.append(cell);
    }
    body.append(row);
  });
}

async function loadAdminCounts() {
  if (!supabase || !adminSession) return;
  const counts = [["products", "admin-count-products"], ["material_collections", "admin-count-collections"], ["production_batches", "admin-count-batches"], ["customer_inquiries", "admin-count-inquiries"]];
  await Promise.all(counts.map(async ([table, id]) => {
    const { count, error } = await supabase.from(table).select("id", { count: "exact", head: true });
    if (!error) $("#" + id).textContent = (count ?? 0).toLocaleString(language === "vi" ? "vi-VN" : "en-US");
  }));
}

function renderEntryForm(def, existing = null) {
  const wrap = $("#admin-entry-form-wrap"); wrap.replaceChildren(); wrap.hidden = false;
  if (!def.fields) { wrap.hidden = true; return; }
  const form = document.createElement("form"); form.className = "admin-entry-form";
  def.fields.forEach(([name, label, type, options, required]) => {
    const fieldRequired = type === "select" ? required === true : options === true;
    const fieldLabel = document.createElement("label"); fieldLabel.textContent = label + (fieldRequired ? " *" : "");
    let input;
    if (type === "select") {
      input = document.createElement("select");
      const empty = document.createElement("option"); empty.value = ""; empty.textContent = "Chọn"; input.append(empty);
      options.forEach((option) => { const o = document.createElement("option"); o.value = option; o.textContent = option; input.append(o); });
    } else if (type === "textarea") { input = document.createElement("textarea"); input.rows = 2; if (fieldRequired) input.required = true; }
    else if (type === "checkbox") { input = document.createElement("input"); input.type = "checkbox"; }
    else { input = document.createElement("input"); input.type = type; if (fieldRequired) input.required = true; if (type === "number") { input.min = name === "amount_kg" ? "0.1" : "0"; input.step = name === "panels_count" ? "1" : "0.1"; } }
    input.name = name;
    if (existing && type === "checkbox") input.checked = Boolean(existing[name]);
    else if (existing && existing[name] != null) input.value = existing[name];
    fieldLabel.append(input); form.append(fieldLabel);
  });
  const actions = document.createElement("div"); actions.className = "entry-actions";
  const cancel = document.createElement("button"); cancel.type = "button"; cancel.className = "cancel-entry"; cancel.textContent = "Hủy"; cancel.addEventListener("click", () => { wrap.hidden = true; });
  const submit = document.createElement("button"); submit.type = "submit"; submit.className = "button button-dark"; submit.textContent = "Lưu bản ghi";
  actions.append(cancel, submit); form.append(actions);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const payload = {};
    new FormData(form).forEach((value, key) => {
      const field = def.fields.find(([fieldName]) => fieldName === key);
      const type = field?.[2];
      payload[key] = type === "number" ? (value === "" ? (["straw_used_kg", "hair_used_kg", "panels_count"].includes(key) ? 0 : null) : Number(value)) : value;
    });
    def.fields.filter(([, , type]) => type === "checkbox").forEach(([name]) => { payload[name] = form.elements[name].checked; });
    if (currentAdminTable === "product_passports") {
      const batchCode = payload.batch_code; delete payload.batch_code;
      if (batchCode) {
        const { data: batch, error: batchError } = await supabase.from("production_batches").select("id").eq("batch_code", batchCode).maybeSingle();
        if (batchError || !batch) { showToast("Không tìm thấy mã lô. Hãy tạo lô trước hoặc để trống."); return; }
        payload.batch_id = batch.id;
      }
    }
    if (currentAdminTable === "lab_tests") {
      const passportCode = payload.passport_code; delete payload.passport_code;
      if (passportCode) {
        const { data: passport, error: passportError } = await supabase.from("product_passports").select("id").eq("passport_code", passportCode).maybeSingle();
        if (passportError || !passport) { showToast("Không tìm thấy mã hộ chiếu. Hãy tạo hồ sơ trước hoặc để trống."); return; }
        payload.passport_id = passport.id;
      }
    }
    const request = existing ? supabase.from(currentAdminTable).update(payload).eq("id", existing.id) : supabase.from(currentAdminTable).insert(payload);
    const { error } = await request;
    if (error) { showToast("Không lưu được bản ghi. Hãy kiểm tra dữ liệu bắt buộc và quyền RLS."); return; }
    showToast("Đã lưu dữ liệu."); wrap.hidden = true;
    await loadAdminTable(currentAdminTable); await loadAdminCounts(); await loadPublicData();
  });
  wrap.append(form);
}

function showAdminDashboard(session) {
  const role = session?.user?.app_metadata?.role;
  const allowed = ["admin", "operator"].includes(role);
  $("#admin-login").hidden = allowed;
  $("#admin-dashboard").hidden = !allowed;
  if (!allowed) {
    setFormStatus($("#admin-login-status"), session ? (language === "vi" ? "Tài khoản đã đăng nhập nhưng chưa được cấp quyền quản trị." : "This account is signed in but has no admin role.") : "", "error");
    return;
  }
  adminSession = session;
  $("#admin-user-email").textContent = `${session.user.email || ""} · ${role}`;
  loadAdminTable(currentAdminTable); loadAdminCounts();
}

function initAdmin() {
  const params = new URLSearchParams(location.search);
  const adminRoute = params.get("admin") === "1";
  if (!adminRoute) return;
  $("#public-site").hidden = true;
  $("#admin-app").hidden = false;
  document.title = "Eco-Bio Panel — Admin";
  $("#admin-close")?.addEventListener("click", () => { location.href = "/"; });
  $("#admin-login-form")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const status = $("#admin-login-status");
    if (!supabase) { setFormStatus(status, language === "vi" ? "Chưa gửi được liên kết: hãy cấu hình Supabase trước." : "Sign-in link not sent: configure Supabase first.", "error"); return; }
    const email = new FormData(event.currentTarget).get("email");
    const { error } = await supabase.auth.signInWithOtp({ email, options: { emailRedirectTo: `${location.origin}${location.pathname}?admin=1` } });
    setFormStatus(status, error ? (language === "vi" ? "Không gửi được email đăng nhập. Kiểm tra cấu hình Supabase Auth." : "Could not send the sign-in email. Check Supabase Auth settings.") : (language === "vi" ? "Đã gửi liên kết. Kiểm tra hộp thư của bạn." : "Sign-in link sent. Check your inbox."), error ? "error" : "success");
  });
  $("#admin-signout")?.addEventListener("click", async () => { await supabase?.auth.signOut(); adminSession = null; $("#admin-dashboard").hidden = true; $("#admin-login").hidden = false; });
  $$(".admin-tab").forEach((tab) => tab.addEventListener("click", () => {
    $$(".admin-tab").forEach((item) => item.classList.remove("active")); tab.classList.add("active");
    currentAdminTable = tab.dataset.table; $("#admin-entry-form-wrap").hidden = true; $("#admin-add-record").hidden = !tableDefinitions[currentAdminTable].fields; loadAdminTable(currentAdminTable);
  }));
  $("#admin-add-record")?.addEventListener("click", () => renderEntryForm(tableDefinitions[currentAdminTable]));
  if (!tableDefinitions[currentAdminTable].fields) $("#admin-add-record").hidden = true;
}

async function init() {
  applyLanguage(language);
  initNavigation(); initForms(); initAdmin();
  await connectSupabase();
  initPassport();
  if (supabase) {
    await loadPublicData();
    if (new URLSearchParams(location.search).get("admin") === "1") {
      const { data } = await supabase.auth.getSession();
      showAdminDashboard(data?.session || null);
      supabase.auth.onAuthStateChange((_event, session) => showAdminDashboard(session));
    }
  }
}

init();
