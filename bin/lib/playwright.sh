# Playwright Chromium provisioning for bin/update-skills. Sourced, never
# executed: the caller sets GSTACK_DIR and defines ok()/info()/warn().
# Split out of update-skills per dispatch/write_any.md §File & Function Length Gate.

# ─── Playwright Chromium (curl fallback) ──────────────────────────────
# gstack's ./setup installs Chromium via 'bunx playwright install chromium',
# which hangs: both bun and node receive all bytes from the Playwright Content
# Delivery Network (CDN) then stall on HTTP/2 stream completion because the
# final frame never arrives. curl fetches the same zips reliably.
# ensure_playwright_chromium runs once so all host setups skip the download.
pw_can_launch() {
    if command -v bun >/dev/null 2>&1; then
        ( cd "$GSTACK_DIR" && bun --eval 'import { chromium } from "playwright"; const b = await chromium.launch(); await b.close();' ) >/dev/null 2>&1
    elif command -v node >/dev/null 2>&1; then
        ( cd "$GSTACK_DIR" && node -e "const { chromium } = require('playwright'); (async () => { const b = await chromium.launch(); await b.close(); })()" ) >/dev/null 2>&1
    else
        return 2
    fi
}

_pw_json_get() {
    bun -e "const j=require('$BROWSERS_JSON'); const c=j.browsers.find(b=>b.name==='$1'); process.stdout.write(String(c.$2))"
}

pw_install_zip() {
    local label="$1" url="$2" dest="$3" tmp
    tmp="$(mktemp "${TMPDIR:-/tmp}/pwcurl.XXXXXX")"
    info "Fetching $label via curl..."
    if ! curl -fL --retry 3 --retry-delay 2 --max-time 280 -o "$tmp" "$url"; then
        rm -f "$tmp"
        warn "curl failed: $url"
        return 1
    fi
    rm -rf "$dest"
    mkdir -p "$dest"
    ( cd "$dest" && unzip -q -o "$tmp" )
    rm -f "$tmp"
    ok "$label installed ($(du -sh "$dest" 2>/dev/null | cut -f1))"
}

# Heal Playwright Chromium via curl when the launch check fails. No-op (ok) when
# the browser already launches, so normal runs pay only one quick launch check.
ensure_playwright_chromium() {
    BROWSERS_JSON="$GSTACK_DIR/node_modules/playwright-core/browsers.json"
    if [ ! -f "$BROWSERS_JSON" ] || [ ! -d "$GSTACK_DIR/node_modules/playwright" ]; then
        warn "playwright not installed in gstack yet; skipping curl preflight (setup will install)"
        return 0
    fi
    if pw_can_launch; then
        ok "Playwright Chromium launches OK; gstack setup will skip download"
        return 0
    fi
    warn "Playwright Chromium missing/broken — running curl fallback"

    local meta_rev meta_ver cache_dir pf_dir chrome_zip shell_zip base
    meta_rev="$(_pw_json_get chromium revision)"
    meta_ver="$(_pw_json_get chromium browserVersion)"
    [ -n "$meta_rev" ] && [ -n "$meta_ver" ] || { warn "could not parse browsers.json; skipping"; return 1; }

    if [ -n "${PLAYWRIGHT_BROWSERS_PATH:-}" ]; then
        cache_dir="$PLAYWRIGHT_BROWSERS_PATH"
    elif [ "$(uname -s)" = "Darwin" ]; then
        cache_dir="$HOME/Library/Caches/ms-playwright"
    else
        cache_dir="$HOME/.cache/ms-playwright"
    fi

    case "$(uname -s)/$(uname -m)" in
        Darwin/arm64)  pf_dir="mac-arm64"; chrome_zip="chrome-mac-arm64.zip";          shell_zip="chrome-headless-shell-mac-arm64.zip" ;;
        Darwin/x86_64) pf_dir="mac-x64";   chrome_zip="chrome-mac-x64.zip";            shell_zip="chrome-headless-shell-mac-x64.zip" ;;
        *) warn "curl fallback supports Darwin only; gstack setup will try bunx (timeout-capped)"; return 1 ;;
    esac
    command -v unzip >/dev/null 2>&1 || { warn "unzip required but not installed"; return 1; }

    base="https://cdn.playwright.dev/builds/cft/$meta_ver/$pf_dir"
    info "Installing Playwright Chromium $meta_ver (revision $meta_rev) via curl into $cache_dir"
    pw_install_zip "chromium ($meta_ver)"             "$base/$chrome_zip" "$cache_dir/chromium-$meta_rev"             || return 1
    pw_install_zip "chromium-headless-shell ($meta_ver)" "$base/$shell_zip" "$cache_dir/chromium_headless_shell-$meta_rev" || return 1

    if pw_can_launch; then
        ok "Playwright Chromium ready (curl fallback)"
        return 0
    fi
    warn "Files installed but launch check failed — inspect $cache_dir"
    return 1
}
