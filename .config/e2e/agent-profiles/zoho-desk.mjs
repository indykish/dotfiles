#!/usr/bin/env bun
/**
 * Zoho Desk CLI for ticket pulling
 *
 * Usage:
 *   bun zoho-desk.mjs help                              Show usage
 *   bun zoho-desk.mjs tickets [--limit N] [--from N] [--status open|closed|all]
 *   bun zoho-desk.mjs get <ticketId>                    Get ticket with threads
 *   bun zoho-desk.mjs pull [--output <dir>] [--limit N] [--since <ISO-date>] [--until <ISO-date>]
 *                          [--concurrency N] [--min-delay-ms N] [--credit-buffer N]
 *   bun zoho-desk.mjs count                             Count total tickets
 *
 * Config: ~/.config/e2e/agent-profiles/zoho-desk.json
 * Secrets: ~/.config/e2e/agent-profiles/.env
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { homedir } from 'os';
import { join } from 'path';

const CONFIG_DIR = join(homedir(), '.config', 'e2e', 'agent-profiles');
const CONFIG_FILE = join(CONFIG_DIR, 'zoho-desk.json');
const ENV_FILE = join(CONFIG_DIR, '.env');
const TOKEN_CACHE_FILE = join(CONFIG_DIR, '.zoho-desk-token-cache.json');

const API_PAGE_SIZE = 50;
const API_DELAY_MS = 200;
const MAX_RETRIES = 3;

// --- Config & Env Loading ---

function loadEnv() {
  if (!existsSync(ENV_FILE)) {
    return null;
  }

  const content = readFileSync(ENV_FILE, 'utf-8');
  const env = {};

  for (const line of content.split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eqIndex = trimmed.indexOf('=');
    if (eqIndex === -1) continue;
    env[trimmed.slice(0, eqIndex).trim()] = trimmed.slice(eqIndex + 1).trim();
  }

  return env;
}

function loadConfig() {
  if (!existsSync(CONFIG_FILE)) {
    return null;
  }
  return JSON.parse(readFileSync(CONFIG_FILE, 'utf-8'));
}

function getFullConfig() {
  const env = loadEnv();
  const jsonConfig = loadConfig();

  if (!env) {
    console.error(`Error: ${ENV_FILE} not found.`);
    console.error('Create it with ZOHO_CLIENT_ID, ZOHO_CLIENT_SECRET, ZOHO_DESK_REFRESH_TOKEN, ZOHO_DESK_ORG_ID');
    process.exit(1);
  }

  if (!jsonConfig) {
    console.error(`Error: ${CONFIG_FILE} not found.`);
    console.error('Create it with: { "orgId": "...", "baseUrl": "https://desk.zoho.com/api/v1", "departmentId": "" }');
    process.exit(1);
  }

  const required = ['ZOHO_CLIENT_ID', 'ZOHO_CLIENT_SECRET', 'ZOHO_DESK_REFRESH_TOKEN', 'ZOHO_DESK_ORG_ID'];
  const missing = required.filter(k => !env[k]);

  if (missing.length > 0) {
    console.error(`Error: Missing env vars in ${ENV_FILE}: ${missing.join(', ')}`);
    process.exit(1);
  }

  return {
    clientId: env.ZOHO_CLIENT_ID,
    clientSecret: env.ZOHO_CLIENT_SECRET,
    refreshToken: env.ZOHO_DESK_REFRESH_TOKEN,
    orgId: env.ZOHO_DESK_ORG_ID,
    baseUrl: jsonConfig.baseUrl || 'https://desk.zoho.com/api/v1',
    departmentId: jsonConfig.departmentId || '',
  };
}

// --- Token Management ---

function loadTokenCache() {
  if (!existsSync(TOKEN_CACHE_FILE)) {
    return { accessToken: '', expiresAt: 0 };
  }
  try {
    return JSON.parse(readFileSync(TOKEN_CACHE_FILE, 'utf-8'));
  } catch {
    return { accessToken: '', expiresAt: 0 };
  }
}

function saveTokenCache(cache) {
  writeFileSync(TOKEN_CACHE_FILE, JSON.stringify(cache, null, 2));
}

async function getAccessToken(config) {
  const cache = loadTokenCache();
  const now = Date.now();

  if (cache.accessToken && cache.expiresAt > now + 300_000) {
    return cache.accessToken;
  }

  const params = new URLSearchParams({
    refresh_token: config.refreshToken,
    client_id: config.clientId,
    client_secret: config.clientSecret,
    grant_type: 'refresh_token',
  });

  const resp = await fetch('https://accounts.zoho.com/oauth/v2/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });

  if (!resp.ok) {
    const text = await resp.text();
    console.error(`Token refresh failed: ${resp.status} ${resp.statusText}`);
    console.error(text);
    process.exit(1);
  }

  const data = await resp.json();

  if (!data.access_token) {
    console.error('No access_token in response:', data);
    process.exit(1);
  }

  const expiresIn = (data.expires_in_sec ?? data.expires_in ?? 3600) * 1000;
  saveTokenCache({ accessToken: data.access_token, expiresAt: now + expiresIn });
  return data.access_token;
}

// --- API Helpers ---

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

// --- Rate-Limit Tracker ---

function createRateLimiter(creditBuffer = 5000, minDelayMs = 0) {
  let remainingCredits = Infinity;
  let paused = false;

  function update(headers) {
    const remaining = headers.get('X-Rate-Limit-Remaining-v3');
    if (remaining !== null) {
      remainingCredits = parseInt(remaining, 10);
    }
  }

  async function waitIfNeeded(headers) {
    if (minDelayMs > 0) await sleep(minDelayMs);

    const retryAfter = headers.get('Retry-After');
    if (retryAfter) {
      const waitMs = parseInt(retryAfter, 10) * 1000;
      console.error(`  Rate-limited: waiting ${waitMs}ms (Retry-After)`);
      await sleep(waitMs);
    }

    if (remainingCredits < creditBuffer && !paused) {
      paused = true;
      console.error(`  Credit buffer reached (remaining=${remainingCredits}, buffer=${creditBuffer}). Pausing 60s...`);
      await sleep(60_000);
      paused = false;
    }
  }

  function getRemaining() { return remainingCredits; }

  return { update, waitIfNeeded, getRemaining };
}

const globalRateLimiter = createRateLimiter();

async function deskFetch(config, endpoint, retries = 0) {
  const token = await getAccessToken(config);
  const url = `${config.baseUrl}${endpoint}`;

  await globalRateLimiter.waitIfNeeded({ get: () => null });

  const resp = await fetch(url, {
    headers: {
      Authorization: `Zoho-oauthtoken ${token}`,
      orgId: config.orgId,
      'Content-Type': 'application/json',
    },
  });

  globalRateLimiter.update(resp.headers);

  if (resp.status === 429) {
    const retryAfter = resp.headers.get('Retry-After');
    const waitMs = retryAfter ? parseInt(retryAfter, 10) * 1000 : Math.pow(2, retries) * 1000;
    if (retries < MAX_RETRIES) {
      console.error(`  429 rate-limited on ${endpoint}, waiting ${waitMs}ms (attempt ${retries + 1}/${MAX_RETRIES})`);
      await sleep(waitMs);
      return deskFetch(config, endpoint, retries + 1);
    }
  }

  if (resp.status >= 500 && retries < MAX_RETRIES) {
    const backoff = Math.pow(2, retries) * 1000;
    console.error(`  Retrying ${endpoint} after ${backoff}ms (status ${resp.status}, attempt ${retries + 1}/${MAX_RETRIES})`);
    await sleep(backoff);
    return deskFetch(config, endpoint, retries + 1);
  }

  if (!resp.ok) {
    const text = await resp.text();
    throw new Error(`API GET ${endpoint} failed: ${resp.status} ${resp.statusText} — ${text}`);
  }

  return resp.json();
}

// --- HTML Stripping ---

function stripHtml(html) {
  if (!html) return '';
  let text = html;
  text = text.replace(/<br\s*\/?>/gi, '\n');
  text = text.replace(/<\/p>/gi, '\n');
  text = text.replace(/<\/div>/gi, '\n');
  text = text.replace(/<\/li>/gi, '\n');
  text = text.replace(/<[^>]*>/g, '');
  text = text.replace(/&amp;/g, '&');
  text = text.replace(/&lt;/g, '<');
  text = text.replace(/&gt;/g, '>');
  text = text.replace(/&quot;/g, '"');
  text = text.replace(/&#39;/g, "'");
  text = text.replace(/&nbsp;/g, ' ');
  text = text.replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)));
  text = text.replace(/\n{3,}/g, '\n\n');
  return text.trim();
}

// --- Ticket Normalization ---

function normalizeTicket(raw) {
  return {
    ticket_id: String(raw.id || ''),
    ticket_number: String(raw.ticketNumber || ''),
    subject: raw.subject || '',
    status: raw.status || '',
    status_type: raw.statusType || '',
    priority: raw.priority || '',
    category: raw.category || '',
    sub_category: raw.subCategory || '',
    channel: raw.channel || '',
    sentiment: raw.sentiment || '',
    created_time: raw.createdTime || '',
    modified_time: raw.modifiedTime || '',
    closed_time: raw.closedTime || '',
    due_date: raw.dueDate || '',
    response_due_date: raw.responseDueDate || '',
    customer_response_time: raw.customerResponseTime || '',
    thread_count: parseInt(raw.threadCount || '0', 10),
    department_id: raw.departmentId || '',
    assignee_id: raw.assigneeId || '',
    contact: raw.contact ? {
      name: raw.contact.lastName
        ? `${raw.contact.firstName || ''} ${raw.contact.lastName}`.trim()
        : (raw.contact.firstName || raw.contact.name || ''),
      email: raw.contact.email || '',
    } : (raw.email ? { name: '', email: raw.email } : null),
    description: stripHtml(raw.description || ''),
    threads: [],
  };
}

function normalizeThread(raw) {
  return {
    thread_id: String(raw.id || ''),
    direction: raw.direction || '',
    type: raw.type || '',
    created_time: raw.createdTime || '',
    from_email: raw.fromEmailAddress || raw.from || '',
    to_email: raw.to || '',
    content: stripHtml(raw.content || raw.plainText || ''),
    has_attachment: Boolean(raw.hasAttach || raw.hasAttachment || false),
  };
}

// --- Commands ---

async function cmdTickets(config, options = {}) {
  const limit = parseInt(options.limit, 10) || 50;
  const from = parseInt(options.from, 10) || 0;
  const status = options.status || '';

  let endpoint = `/tickets?from=${from}&limit=${limit}&sortBy=modifiedTime`;
  if (status && status !== 'all') {
    endpoint += `&status=${encodeURIComponent(status)}`;
  }

  const data = await deskFetch(config, endpoint);
  const tickets = (data.data || data || []).map(normalizeTicket);
  console.log(JSON.stringify({ tickets, count: tickets.length }, null, 2));
}

async function cmdGet(config, ticketId) {
  const ticket = await deskFetch(config, `/tickets/${ticketId}`);
  const normalized = normalizeTicket(ticket);

  await sleep(API_DELAY_MS);

  try {
    const threadsData = await deskFetch(config, `/tickets/${ticketId}/threads`);
    const threadList = threadsData.data || threadsData || [];

    for (const t of threadList) {
      await sleep(API_DELAY_MS);
      try {
        const detail = await deskFetch(config, `/tickets/${ticketId}/threads/${t.id}`);
        normalized.threads.push(normalizeThread(detail));
      } catch (err) {
        console.error(`  Error fetching thread ${t.id}: ${err.message}`);
        normalized.threads.push(normalizeThread(t));
      }
    }
  } catch (err) {
    console.error(`  Error fetching threads for ticket ${ticketId}: ${err.message}`);
  }

  console.log(JSON.stringify(normalized, null, 2));
}

async function cmdCount(config) {
  const data = await deskFetch(config, '/tickets?from=0&limit=1');
  const arr = data.data || data || [];
  // Zoho Desk doesn't always return a total count header easily via fetch,
  // so we paginate to find the total if the first page returns results
  if (arr.length === 0) {
    console.log(JSON.stringify({ total: 0 }, null, 2));
    return;
  }

  let total = 0;
  let from = 0;
  const pageSize = 50;

  while (true) {
    const page = await deskFetch(config, `/tickets?from=${from}&limit=${pageSize}&sortBy=modifiedTime`);
    const items = page.data || page || [];
    total += items.length;
    if (items.length < pageSize) break;
    from += pageSize;
    await sleep(API_DELAY_MS);
  }

  console.log(JSON.stringify({ total }, null, 2));
}

// --- Concurrency Pool ---
// Shared pool ensures total inflight requests never exceed concurrency limit,
// whether they come from listing, thread listing, or thread detail fetches.

function createPool(concurrency) {
  let active = 0;
  const queue = [];

  function drain() {
    while (queue.length > 0 && active < concurrency) {
      active++;
      const { fn, resolve, reject } = queue.shift();
      fn().then(resolve, reject).finally(() => {
        active--;
        drain();
      });
    }
  }

  return function run(fn) {
    return new Promise((resolve, reject) => {
      queue.push({ fn, resolve, reject });
      drain();
    });
  };
}

// --- Enrich a single ticket with threads ---

async function enrichTicket(config, ticket, pool) {
  const threadsData = await pool(() =>
    deskFetch(config, `/tickets/${ticket.ticket_id}/threads`)
  );
  const threadList = threadsData.data || threadsData || [];
  if (threadList.length === 0) return 0;

  // All thread detail fetches go through the shared pool — truly concurrent
  const results = await Promise.allSettled(
    threadList.map(t =>
      pool(() => deskFetch(config, `/tickets/${ticket.ticket_id}/threads/${t.id}`))
    )
  );

  let errors = 0;
  for (let i = 0; i < results.length; i++) {
    if (results[i].status === 'fulfilled') {
      ticket.threads.push(normalizeThread(results[i].value));
    } else {
      // Fallback: use summary from list response instead of failing
      ticket.threads.push(normalizeThread(threadList[i]));
      errors++;
    }
  }
  return errors;
}

// --- Pipelined Pull ---
// Listing and enrichment run concurrently. As each listing page arrives,
// its tickets are immediately fed into the enrichment pool. No waiting
// for all pages to finish before enrichment starts.

async function cmdPull(config, options = {}) {
  const outputDir = options.output || './zoho-desk-export';
  const maxLimit = options.limit ? parseInt(options.limit, 10) : Infinity;
  const sinceDate = options.since ? new Date(options.since) : null;
  const untilDate = options.until ? new Date(options.until) : null;
  const concurrency = Math.min(options.concurrency ? parseInt(options.concurrency, 10) : 10, 25);
  const minDelayMs = options['min-delay-ms'] ? parseInt(options['min-delay-ms'], 10) : 0;
  const creditBuffer = options['credit-buffer'] ? parseInt(options['credit-buffer'], 10) : 5000;

  // Reconfigure global rate limiter with pull-specific settings
  const rateLimiter = createRateLimiter(creditBuffer, minDelayMs);
  globalRateLimiter.update = rateLimiter.update;
  globalRateLimiter.waitIfNeeded = rateLimiter.waitIfNeeded;
  globalRateLimiter.getRemaining = rateLimiter.getRemaining;

  mkdirSync(outputDir, { recursive: true });

  const t0 = Date.now();
  console.error(`Pull: concurrency=${concurrency}, credit-buffer=${creditBuffer}, min-delay-ms=${minDelayMs}`);
  if (sinceDate) console.error(`  since: ${sinceDate.toISOString()}`);
  if (untilDate) console.error(`  until: ${untilDate.toISOString()}`);
  console.error('');

  // Shared pool for ALL API calls (listing + thread list + thread detail)
  const pool = createPool(concurrency);

  // Pipeline: listing feeds tickets into enrichment immediately
  const allTickets = [];        // preserves insertion order
  const enrichPromises = [];    // parallel enrichment futures
  let errorCount = 0;
  let from = 0;
  let keepGoing = true;
  let apiCalls = 0;

  // Wrap deskFetch to count calls
  const trackedFetch = (endpoint) => {
    apiCalls++;
    return deskFetch(config, endpoint);
  };
  const trackedPool = (fn) => pool(() => {
    apiCalls++;
    return fn();
  });

  while (keepGoing) {
    const pageLimit = Math.min(API_PAGE_SIZE, maxLimit - allTickets.length);
    if (pageLimit <= 0) break;

    console.error(`Listing tickets ${from + 1}-${from + pageLimit}...`);

    let data;
    try {
      data = await trackedFetch(`/tickets?from=${from}&limit=${pageLimit}&sortBy=modifiedTime&include=contacts`);
    } catch (err) {
      console.error(`  Error listing at from=${from}: ${err.message}`);
      break;
    }

    const rawTickets = data.data || data || [];
    if (rawTickets.length === 0) break;

    for (const raw of rawTickets) {
      const modTime = new Date(raw.modifiedTime || raw.createdTime || 0);

      if (sinceDate && modTime < sinceDate) { keepGoing = false; break; }
      if (untilDate && modTime > untilDate) continue;

      const ticket = normalizeTicket(raw);
      allTickets.push(ticket);

      // Immediately start enriching — don't wait for listing to finish
      const idx = allTickets.length;
      enrichPromises.push(
        enrichTicket(config, ticket, trackedPool)
          .then(errs => {
            console.error(`  ✓ #${ticket.ticket_number} (${ticket.threads.length} threads) [${idx}/${maxLimit === Infinity ? '∞' : maxLimit}]`);
            return errs;
          })
          .catch(err => {
            console.error(`  ✗ #${ticket.ticket_number}: ${err.message}`);
            return 1;
          })
      );

      if (allTickets.length >= maxLimit) { keepGoing = false; break; }
    }

    if (rawTickets.length < pageLimit) break;
    from += rawTickets.length;
  }

  // Wait for all enrichment to complete
  console.error(`\nListed ${allTickets.length} tickets, waiting for enrichment...`);
  const results = await Promise.allSettled(enrichPromises);
  for (const r of results) {
    if (r.status === 'fulfilled') errorCount += r.value;
    else errorCount++;
  }

  // Write per-ticket JSONL files in year/month/ structure
  console.error('');
  let written = 0;
  for (const ticket of allTickets) {
    const ts = ticket.created_time || ticket.modified_time || '';
    const d = ts ? new Date(ts) : new Date();
    const yyyy = String(d.getFullYear());
    const mm = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const hh = String(d.getHours()).padStart(2, '0');
    const min = String(d.getMinutes()).padStart(2, '0');
    const ss = String(d.getSeconds()).padStart(2, '0');
    const monthDir = join(outputDir, yyyy, mm);
    mkdirSync(monthDir, { recursive: true });

    const fileName = `${day}_${hh}${min}${ss}_${ticket.ticket_number}.txt`;
    const filePath = join(monthDir, fileName);
    writeFileSync(filePath, JSON.stringify(ticket) + '\n', 'utf-8');
    written++;

    if (written % 100 === 0) {
      const rem = globalRateLimiter.getRemaining();
      console.error(`  Wrote ${written}/${allTickets.length} tickets` +
        (rem !== Infinity ? ` | credits remaining: ${rem}` : ''));
    }
  }
  console.error(`Wrote ${written} ticket files to ${outputDir}/`);

  const remaining = globalRateLimiter.getRemaining();
  const elapsed = ((Date.now() - t0) / 1000).toFixed(1);
  console.error(`\nDone. ${allTickets.length} tickets, ${apiCalls} API calls, ${errorCount} errors, ${elapsed}s`);
  if (remaining !== Infinity) console.error(`  API credits remaining: ${remaining}`);
}

// --- Arg Parsing ---

function parseArgs(args) {
  const result = { _: [] };

  for (let i = 0; i < args.length; i++) {
    const arg = args[i];

    if (arg.startsWith('--')) {
      const key = arg.slice(2);
      const next = args[i + 1];
      if (next && !next.startsWith('--')) {
        result[key] = next;
        i++;
      } else {
        result[key] = true;
      }
    } else {
      result._.push(arg);
    }
  }

  return result;
}

// --- Main ---

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const command = args._[0];

  if (!command || command === 'help') {
    console.log(`
Zoho Desk CLI

Usage:
  zoho-desk.mjs help                                     Show this help
  zoho-desk.mjs tickets [--limit N] [--from N] [--status open|closed|all]
                                                         List tickets (JSON)
  zoho-desk.mjs get <ticketId>                           Get ticket with threads (JSON)
  zoho-desk.mjs pull [options]                           Pull tickets to JSONL files
  zoho-desk.mjs count                                    Count total tickets

Config files:
  ${ENV_FILE}
    ZOHO_CLIENT_ID, ZOHO_CLIENT_SECRET
    ZOHO_DESK_REFRESH_TOKEN, ZOHO_DESK_ORG_ID

  ${CONFIG_FILE}
    { "orgId": "...", "baseUrl": "https://desk.zoho.com/api/v1", "departmentId": "" }

Pull options:
  --output <dir>       Output directory (default: ./zoho-desk-export)
  --limit N            Max tickets to pull
  --since <date>       Only include tickets modified on/after ISO date (e.g. 2021-01-01)
  --until <date>       Only include tickets modified on/before ISO date (e.g. 2021-12-31)
  --concurrency N      Max parallel API requests (default: 10, max: 25)
  --min-delay-ms N     Minimum delay between requests in ms (default: 0)
  --credit-buffer N    Pause when remaining API credits drop below N (default: 5000)

Output structure:
  <output>/<YYYY>/<MM>/<DD>_<HHMMSS>_<ticket#>.txt
  Each .txt file = one ticket (single JSON line) with "threads" array.
`);
    process.exit(0);
  }

  const config = getFullConfig();

  switch (command) {
    case 'tickets':
      await cmdTickets(config, { limit: args.limit, from: args.from, status: args.status });
      break;

    case 'get':
      if (!args._[1]) {
        console.error('Usage: zoho-desk.mjs get <ticketId>');
        process.exit(1);
      }
      await cmdGet(config, args._[1]);
      break;

    case 'pull':
      await cmdPull(config, {
        output: args.output, limit: args.limit, since: args.since, until: args.until,
        concurrency: args.concurrency,
        'min-delay-ms': args['min-delay-ms'], 'credit-buffer': args['credit-buffer'],
      });
      break;

    case 'count':
      await cmdCount(config);
      break;

    default:
      console.error(`Unknown command: ${command}`);
      console.error('Run: zoho-desk.mjs help');
      process.exit(1);
  }
}

main().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
