(function () {
  const config = window.JEJU_DASHBOARD_CONFIG || {};
  const hasConfig = Boolean(config.supabaseUrl && config.supabaseAnonKey);

  if (!hasConfig) {
    window.JejuSupabase = {
      client: null,
      isReady: () => false,
      configError: "config.js에 Supabase URL과 anon key가 설정되지 않았습니다."
    };
    return;
  }

  if (!window.supabase?.createClient) {
    window.JejuSupabase = {
      client: null,
      isReady: () => false,
      configError: "Supabase 라이브러리를 불러오지 못했습니다."
    };
    return;
  }

  window.JejuSupabase = {
    client: window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey),
    isReady: () => true,
    configError: ""
  };
})();
