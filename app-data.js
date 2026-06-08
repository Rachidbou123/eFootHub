(function () {
    const DEFAULT_STORAGE_PREFIX = 'efh_';
    const FALLBACK_KEYS = {
        players: 'players_data',
        blogs: 'blog_posts',
        managers: 'managers',
        boosters: 'boosters',
        predicted_players: 'predicted_players',
        settings: 'settings',
        build_battles: 'build_battles',
        squads: 'squads',
        profiles: 'profiles'
    };

    const config = window.EFHUB_CONFIG || {};
    const supabaseConfig = {
        url: config.supabaseUrl || '',
        anonKey: config.supabaseAnonKey || ''
    };

    function safeParse(value, fallback) {
        try {
            return JSON.parse(value);
        } catch {
            return fallback;
        }
    }

    function readLocal(table) {
        const key = `${DEFAULT_STORAGE_PREFIX}${FALLBACK_KEYS[table] || table}_v1`;
        const raw = localStorage.getItem(key);
        if (!raw) return [];
        const parsed = safeParse(raw, []);
        return Array.isArray(parsed) ? parsed : [];
    }

    function writeLocal(table, records) {
        const key = `${DEFAULT_STORAGE_PREFIX}${FALLBACK_KEYS[table] || table}_v1`;
        localStorage.setItem(key, JSON.stringify(records));
    }

    function getClient() {
        if (!window.supabase || !supabaseConfig.url || !supabaseConfig.anonKey) return null;
        if (!window.__EFHUB_SUPABASE__) {
            window.__EFHUB_SUPABASE__ = window.supabase.createClient(supabaseConfig.url, supabaseConfig.anonKey, {
                auth: {
                    persistSession: true,
                    autoRefreshToken: true,
                    detectSessionInUrl: true
                }
            });
        }
        return window.__EFHUB_SUPABASE__;
    }

    async function loadCollection(table, options = {}) {
        const client = getClient();
        if (client) {
            let query = client.from(table).select(options.select || '*');
            if (options.filter && options.filter.column) {
                query = query.eq(options.filter.column, options.filter.value);
            }
            if (options.order && options.order.column) {
                query = query.order(options.order.column, { ascending: options.order.ascending !== false });
            }
            if (options.limit) {
                query = query.limit(options.limit);
            }
            const { data, error } = await query;
            if (!error && Array.isArray(data)) return data;
        }

        return readLocal(table);
    }

    async function saveCollection(table, records) {
        const client = getClient();
        if (client) {
            const { error } = await client.from(table).upsert(records, { onConflict: 'id' });
            if (!error) return records;
        }
        writeLocal(table, records);
        return records;
    }

    async function saveRecord(table, record) {
        const client = getClient();
        if (client) {
            const { error } = await client.from(table).upsert(record, { onConflict: 'id' });
            if (!error) return record;
        }

        const records = readLocal(table);
        const index = records.findIndex(item => String(item.id) === String(record.id));
        if (index >= 0) records[index] = record;
        else records.unshift(record);
        writeLocal(table, records);
        return record;
    }

    async function deleteRecord(table, id) {
        const client = getClient();
        if (client) {
            const { error } = await client.from(table).delete().eq('id', id);
            if (!error) return true;
        }

        const records = readLocal(table).filter(item => String(item.id) !== String(id));
        writeLocal(table, records);
        return true;
    }

    async function getSession() {
        const client = getClient();
        if (!client) return null;
        const { data } = await client.auth.getSession();
        return data?.session || null;
    }

    async function getProfile() {
        const session = await getSession();
        if (!session) return null;
        const client = getClient();
        if (!client) return null;
        const { data } = await client.from('profiles').select('*').eq('id', session.user.id).maybeSingle();
        return data || null;
    }

    async function isAdmin() {
        const profile = await getProfile();
        return profile?.role === 'admin';
    }

    async function signInWithGoogle(redirectTo) {
        const client = getClient();
        if (!client) throw new Error('Supabase is not configured.');
        const { error } = await client.auth.signInWithOAuth({
            provider: 'google',
            options: {
                redirectTo: redirectTo || window.location.href
            }
        });
        if (error) throw error;
    }

    async function signOut() {
        const client = getClient();
        if (!client) return;
        await client.auth.signOut();
    }

    function slugify(value) {
        return String(value || '')
            .toLowerCase()
            .replace(/[^a-z0-9]+/g, '-')
            .replace(/(^-|-$)+/g, '');
    }

    function formatDate(value) {
        if (!value) return '';
        const date = new Date(value);
        if (Number.isNaN(date.getTime())) return '';
        return date.toLocaleDateString(undefined, {
            year: 'numeric',
            month: 'short',
            day: 'numeric'
        });
    }

    window.EFHubData = {
        getClient,
        loadCollection,
        saveCollection,
        saveRecord,
        deleteRecord,
        getSession,
        getProfile,
        isAdmin,
        signInWithGoogle,
        signOut,
        slugify,
        formatDate
    };
})();
