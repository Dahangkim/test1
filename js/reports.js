(function () {
  const TABLE = "reports";
  const PUBLIC_COLUMNS = "id,shop_id,shop_name,shop_address,report_type,report_content,source_url,status,created_at,reviewed_at";
  const ADMIN_COLUMNS = "id,shop_id,shop_name,shop_address,report_type,report_content,source_url,reporter_contact,status,admin_memo,created_at,updated_at,reviewed_at,reviewed_by";

  function client() {
    return window.JejuSupabase?.client || null;
  }

  function isReady() {
    return Boolean(window.JejuSupabase?.isReady?.() && client());
  }

  function requireClient() {
    const supabase = client();
    if (!supabase) {
      throw new Error(window.JejuSupabase?.configError || "Supabase 설정이 필요합니다.");
    }
    return supabase;
  }

  function normalizeReportPayload(payload) {
    return {
      shop_id: String(payload.shopId || "").trim(),
      shop_name: String(payload.shopName || "").trim(),
      shop_address: String(payload.shopAddress || "").trim(),
      report_type: String(payload.reportType || "").trim(),
      report_content: String(payload.reportContent || "").trim(),
      source_url: String(payload.sourceUrl || "").trim() || null,
      reporter_contact: String(payload.reporterContact || "").trim() || null,
      status: "pending"
    };
  }

  async function submitReport(payload) {
    const row = normalizeReportPayload(payload);
    if (!row.shop_id || !row.shop_name || !row.report_type || !row.report_content) {
      throw new Error("업소 정보, 제보 유형, 제보 내용을 확인하세요.");
    }
    const { data, error } = await requireClient()
      .from(TABLE)
      .insert(row)
      .select("id,status,created_at")
      .single();
    if (error) throw error;
    return data;
  }

  async function listApprovedReports() {
    if (!isReady()) return [];
    const { data, error } = await requireClient()
      .from(TABLE)
      .select(PUBLIC_COLUMNS)
      .eq("status", "approved")
      .order("reviewed_at", { ascending: false, nullsFirst: false })
      .order("created_at", { ascending: false });
    if (error) throw error;
    return data || [];
  }

  async function getSession() {
    const { data, error } = await requireClient().auth.getSession();
    if (error) throw error;
    return data.session;
  }

  async function signIn(email, password) {
    const { data, error } = await requireClient().auth.signInWithPassword({ email, password });
    if (error) throw error;
    return data.session;
  }

  async function signOut() {
    const { error } = await requireClient().auth.signOut();
    if (error) throw error;
  }

  async function listAdminReports(status) {
    let query = requireClient()
      .from(TABLE)
      .select(ADMIN_COLUMNS)
      .order("created_at", { ascending: false });
    if (status && status !== "ALL") query = query.eq("status", status);
    const { data, error } = await query;
    if (error) throw error;
    return data || [];
  }

  async function updateAdminReport(id, updates) {
    const row = {
      status: updates.status,
      admin_memo: updates.adminMemo || null,
      reviewed_at: new Date().toISOString()
    };
    const { data: userData } = await requireClient().auth.getUser();
    if (userData?.user?.id) row.reviewed_by = userData.user.id;

    const { data, error } = await requireClient()
      .from(TABLE)
      .update(row)
      .eq("id", id)
      .select(ADMIN_COLUMNS)
      .single();
    if (error) throw error;
    return data;
  }

  function openModal(shop) {
    const modal = document.getElementById("reportModal");
    if (!modal) return;
    document.getElementById("reportShopId").value = shop.shopId || "";
    document.getElementById("reportShopName").value = shop.shopName || "";
    document.getElementById("reportShopAddress").value = shop.shopAddress || "";
    document.getElementById("reportType").value = "";
    document.getElementById("reportContent").value = "";
    document.getElementById("reportSourceUrl").value = "";
    document.getElementById("reporterContact").value = "";
    document.getElementById("reportSubmitStatus").textContent = "";
    modal.classList.add("on");
    modal.setAttribute("aria-hidden", "false");
  }

  function closeModal() {
    const modal = document.getElementById("reportModal");
    if (!modal) return;
    modal.classList.remove("on");
    modal.setAttribute("aria-hidden", "true");
  }

  function bindPublicForm(options = {}) {
    const form = document.getElementById("reportForm");
    if (!form || form.dataset.bound === "true") return;
    form.dataset.bound = "true";
    form.addEventListener("submit", async (event) => {
      event.preventDefault();
      const status = document.getElementById("reportSubmitStatus");
      status.textContent = "제출 중입니다.";
      try {
        await submitReport({
          shopId: document.getElementById("reportShopId").value,
          shopName: document.getElementById("reportShopName").value,
          shopAddress: document.getElementById("reportShopAddress").value,
          reportType: document.getElementById("reportType").value,
          reportContent: document.getElementById("reportContent").value,
          sourceUrl: document.getElementById("reportSourceUrl").value,
          reporterContact: document.getElementById("reporterContact").value
        });
        status.textContent = "접수되었습니다. 관리자 검토 후 공개됩니다.";
        form.reset();
        setTimeout(closeModal, 900);
        options.onSubmitted?.();
      } catch (err) {
        status.textContent = err.message || "제출 중 오류가 발생했습니다.";
      }
    });
  }

  window.ReportService = {
    isReady,
    submitReport,
    listApprovedReports,
    getSession,
    signIn,
    signOut,
    listAdminReports,
    updateAdminReport
  };

  window.ReportUI = {
    bindPublicForm,
    openModal,
    closeModal
  };
})();
