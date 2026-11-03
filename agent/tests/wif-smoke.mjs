// End-to-end smoke test: Vault AppRole -> Vault identity token -> Anthropic WIF -> Claude Code.
// Runs as agent-bot (uid 1040). Never prints a secret or a token; only claim names and results.
import { readFileSync, writeFileSync, appendFileSync } from "node:fs";
import { spawnSync } from "node:child_process";

const LOG = "/work/_agent/logs/wif-smoke.log";
const V = process.env.VAULT_ADDR;
const log = (m) => { const l = `${new Date().toISOString()} ${m}`; console.log(l); appendFileSync(LOG, l + "\n"); };
const fail = (m) => { log("FAIL " + m); process.exit(1); };

async function vault(path, { method = "GET", token, body, ns } = {}) {
  const headers = { "content-type": "application/json" };
  if (token) headers["X-Vault-Token"] = token;
  if (ns) headers["X-Vault-Namespace"] = ns;
  const r = await fetch(`${V}/v1/${path}`, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const j = await r.json().catch(() => ({}));
  if (!r.ok) throw new Error(`${method} ${path} -> HTTP ${r.status} ${JSON.stringify(j.errors || j)}`);
  return j;
}

writeFileSync(LOG, "");
log("start");

// 1. Unwrap the one-time secret ID (single use; wrapping token is useless afterwards).
let secretId;
try {
  const wrapped = readFileSync("/work/_agent/secrets/wrapped-secret-id", "utf8").trim();
  const j = await vault("sys/wrapping/unwrap", { method: "POST", token: wrapped });
  secretId = j.data.secret_id;
  log("1 unwrap secret ID: OK");
} catch (e) { fail("1 unwrap: " + e.message); }

// 2. AppRole login in the agent namespace.
let token;
try {
  const j = await vault("auth/approle/login", { method: "POST", ns: "agent", body: { role_id: process.env.ROLE_ID, secret_id: secretId } });
  token = j.auth.client_token;
  log(`2 AppRole login: OK (policies ${j.auth.policies.join(",")}, ttl ${j.auth.lease_duration}s)`);
} catch (e) { fail("2 login: " + e.message); }

// 3. Policy check: read agent-bot's username only.
try {
  const j = await vault("kv/data/dsm/agent-bot", { token, ns: "agent" });
  log(`3 read DSM credential: OK (username ${j.data.data.username}, password present ${Boolean(j.data.data.password)})`);
} catch (e) { fail("3 kv read: " + e.message); }

// 4. Mint the identity token and show its claims (not the token).
let jwt;
try {
  const j = await vault("identity/oidc/token/claude-agent", { token, ns: "agent" });
  jwt = j.data.token;
  const c = JSON.parse(Buffer.from(jwt.split(".")[1], "base64url").toString());
  log(`4 identity token: OK iss=${c.iss} aud=${c.aud} agent=${c.agent} sub=${c.sub} lifetime=${c.exp - c.iat}s jti=${"jti" in c ? "present" : "absent"}`);
  writeFileSync(process.env.ANTHROPIC_IDENTITY_TOKEN_FILE, jwt, { mode: 0o600 });
} catch (e) { fail("4 identity token: " + e.message); }

// 5. Claude Code exchanges the token with Anthropic and makes one tiny request.
const r = spawnSync("/tmp/cc/node_modules/.bin/claude", ["-p", "Reply with exactly the word OK and nothing else.", "--model", "haiku"], { encoding: "utf8", timeout: 180000, env: process.env });
const out = (r.stdout || "").trim().slice(0, 300);
const err = (r.stderr || "").trim().slice(0, 600);
if (r.status === 0 && /OK/.test(out)) log(`5 Claude Code via WIF: OK (reply: ${out})`);
else fail(`5 Claude Code: exit ${r.status} stdout="${out}" stderr="${err}" ${r.error ? r.error.message : ""}`);

// 6. Revoke the Vault token we used.
try { await vault("auth/token/revoke-self", { method: "POST", token, ns: "agent" }); log("6 revoke Vault token: OK"); }
catch (e) { log("6 revoke: " + e.message); }
log("done");
