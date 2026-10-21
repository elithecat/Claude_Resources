import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import https from 'node:https';
import { URL } from 'node:url';

const MODES = {
  'anthropic-api-key': {
    upstream: 'https://api.anthropic.com',
    authHeader: 'x-api-key',
    authPrefix: '',
    routes: {
      GET: ['/v1/models', '/api/oauth'],
      POST: ['/v1/messages'],
    },
  },
  'anthropic-oauth': {
    upstream: 'https://api.anthropic.com',
    authHeader: 'authorization',
    authPrefix: 'Bearer ',
    routes: {
      GET: ['/v1/models', '/api/oauth'],
      POST: ['/v1/messages'],
    },
  },
  'openai-api-key': {
    upstream: 'https://api.openai.com',
    authHeader: 'authorization',
    authPrefix: 'Bearer ',
    routes: {
      GET: ['/v1/models', '/v1/responses'],
      POST: ['/v1/responses'],
      DELETE: ['/v1/responses'],
    },
  },
};

const HOP_BY_HOP = new Set([
  'connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization',
  'te', 'trailer', 'transfer-encoding', 'upgrade',
]);
const STRIP_REQUEST = new Set([
  ...HOP_BY_HOP, 'authorization', 'x-api-key', 'cookie', 'host',
  'content-length', 'expect', 'forwarded', 'via', 'traceparent', 'tracestate',
  'baggage', 'x-forwarded-for', 'x-forwarded-host', 'x-forwarded-proto',
  'x-forwarded-port', 'x-real-ip',
]);
const STRIP_RESPONSE = new Set([
  ...HOP_BY_HOP, 'content-length', 'set-cookie', 'server',
]);

const testMode = process.env.PROXY_TEST_MODE === '1';
const modeName = process.env.PROXY_MODE ?? '';
const mode = MODES[modeName];
if (!mode) throw new Error('unsupported proxy mode');

function readRegularSecret(file, label) {
  const stat = fs.lstatSync(file);
  if (!stat.isFile() || stat.isSymbolicLink()) throw new Error(`${label} path is not a regular file`);
  const value = fs.readFileSync(file, 'utf8').trim();
  if (!value || /[\r\n]/.test(value)) throw new Error(`${label} is empty or malformed`);
  return value;
}

const providerSecretFile = testMode
  ? (process.env.PROXY_SECRET_FILE || '/run/secrets/provider_credential')
  : '/run/secrets/provider_credential';
const clientSecretFile = testMode
  ? (process.env.PROXY_CLIENT_SECRET_FILE || '/run/secrets/client_credential')
  : '/run/secrets/client_credential';
const credential = readRegularSecret(providerSecretFile, 'provider credential');
const clientCredential = readRegularSecret(clientSecretFile, 'client credential');

const upstream = new URL(
  testMode && process.env.PROXY_TEST_UPSTREAM
    ? process.env.PROXY_TEST_UPSTREAM
    : mode.upstream,
);
if (!testMode && upstream.protocol !== 'https:') throw new Error('production upstream must use TLS');

const listenHost = testMode ? (process.env.PROXY_LISTEN_HOST || '127.0.0.1') : '0.0.0.0';
const listenPort = Number(testMode ? (process.env.PROXY_LISTEN_PORT || '8080') : '8080');
const maxBodyBytes = Number(process.env.PROXY_MAX_BODY_BYTES || 67_108_864);
const maxRequests = Number(process.env.PROXY_MAX_REQUESTS || 1000);
const maxConcurrent = Number(process.env.PROXY_MAX_CONCURRENT || 8);
if (!Number.isSafeInteger(listenPort) || listenPort < 0 || listenPort > 65535) throw new Error('invalid listen port');
if (!Number.isSafeInteger(maxBodyBytes) || maxBodyBytes < 1024) throw new Error('invalid body limit');
if (!Number.isSafeInteger(maxRequests) || maxRequests < 1) throw new Error('invalid request limit');
if (!Number.isSafeInteger(maxConcurrent) || maxConcurrent < 1) throw new Error('invalid concurrency limit');

let acceptedRequests = 0;
let activeRequests = 0;

function pathAllowed(method, rawPathname) {
  const prefixes = mode.routes[method] || [];
  // Percent-decode fully before any matching; URL parsing does NOT decode the
  // path, so /v1/messages/%62atches would otherwise slip a literal check.
  let pathname = rawPathname;
  try {
    for (let i = 0; i < 5 && /%[0-9a-fA-F]{2}/.test(pathname); i++) {
      pathname = decodeURIComponent(pathname);
    }
  } catch { return false; }
  if (/%[0-9a-fA-F]{2}/.test(pathname)) return false;
  if (pathname.includes('\0') || pathname.includes('..')) return false;
  if (/(^|\/)batches(\/|$)/.test(pathname)) return false;
  // Exact route or exactly one path segment under it (e.g. /v1/messages/{id}),
  // never deeper, so sub-resources like .../batches are not reachable by prefix.
  return prefixes.some((prefix) => {
    if (pathname === prefix) return true;
    if (!pathname.startsWith(`${prefix}/`)) return false;
    const rest = pathname.slice(prefix.length + 1);
    return rest.length > 0 && !rest.includes('/');
  });
}

function constantTimeEqual(actual, expected) {
  const a = Buffer.from(actual, 'utf8');
  const b = Buffer.from(expected, 'utf8');
  if (a.length !== b.length) {
    // Compare fixed-size digests so length mismatches do not become a fast path.
    return crypto.timingSafeEqual(crypto.createHash('sha256').update(a).digest(), crypto.createHash('sha256').update(b).digest()) && false;
  }
  return crypto.timingSafeEqual(a, b);
}

function requestAuthorized(req) {
  const raw = req.headers[mode.authHeader];
  if (raw === undefined || Array.isArray(raw)) return false;
  return constantTimeEqual(String(raw), `${mode.authPrefix}${clientCredential}`);
}

function localResponse(res, status, message) {
  const body = Buffer.from(`${message}\n`, 'utf8');
  res.writeHead(status, {
    'content-type': 'text/plain; charset=utf-8',
    'content-length': String(body.length),
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
    connection: 'close',
  });
  res.end(body);
}

async function readBody(req) {
  return await new Promise((resolve, reject) => {
    const chunks = [];
    let total = 0;
    req.on('data', (chunk) => {
      total += chunk.length;
      if (total > maxBodyBytes) {
        reject(Object.assign(new Error('body too large'), { statusCode: 413 }));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

const server = http.createServer(async (req, res) => {
  if (req.method === 'GET' && req.url === '/healthz') {
    localResponse(res, 200, 'ok');
    return;
  }

  if (!requestAuthorized(req)) {
    localResponse(res, 401, 'invalid proxy client credential');
    return;
  }
  if (!req.url || !req.url.startsWith('/') || req.url.startsWith('//')) {
    localResponse(res, 400, 'malformed request target');
    return;
  }

  let target;
  try {
    target = new URL(req.url, 'http://proxy.invalid');
  } catch {
    localResponse(res, 400, 'malformed request target');
    return;
  }

  if (!pathAllowed(req.method || '', target.pathname)) {
    localResponse(res, 403, 'provider route is not allowed');
    return;
  }
  if (acceptedRequests >= maxRequests) {
    localResponse(res, 429, 'per-run provider request limit reached');
    return;
  }
  if (activeRequests >= maxConcurrent) {
    localResponse(res, 503, 'proxy concurrency limit reached');
    return;
  }
  if (req.headers['transfer-encoding'] && req.headers['transfer-encoding'] !== 'identity') {
    localResponse(res, 411, 'chunked request bodies are not supported');
    return;
  }

  const declaredLength = req.headers['content-length'];
  if (declaredLength !== undefined) {
    const parsed = Number(declaredLength);
    if (!Number.isSafeInteger(parsed) || parsed < 0) {
      localResponse(res, 400, 'invalid content length');
      return;
    }
    if (parsed > maxBodyBytes) {
      localResponse(res, 413, 'request body is too large');
      return;
    }
  }

  acceptedRequests += 1;
  activeRequests += 1;

  let slotReleased = false;
  const releaseSlot = () => {
    if (slotReleased) return;
    slotReleased = true;
    activeRequests = Math.max(0, activeRequests - 1);
  };

  let body;
  try {
    body = await readBody(req);
  } catch (error) {
    releaseSlot();
    if (!res.headersSent) localResponse(res, error.statusCode || 400, 'request body could not be read');
    return;
  }

  const headers = {};
  for (const [name, rawValue] of Object.entries(req.headers)) {
    const lower = name.toLowerCase();
    if (STRIP_REQUEST.has(lower) || rawValue === undefined) continue;
    const value = Array.isArray(rawValue) ? rawValue.join(', ') : String(rawValue);
    if (/\r|\n/.test(value)) {
      releaseSlot();
      localResponse(res, 400, 'invalid request header');
      return;
    }
    headers[lower] = value;
  }
  headers[mode.authHeader] = `${mode.authPrefix}${credential}`;
  headers.host = upstream.host;
  headers['content-length'] = String(body.length);

  const transport = upstream.protocol === 'http:' ? http : https;
  let upstreamRequest;
  let upstreamResponseRef;
  try {
    upstreamRequest = transport.request({
      protocol: upstream.protocol,
      hostname: upstream.hostname,
      port: upstream.port || undefined,
      method: req.method,
      path: `${target.pathname}${target.search}`,
      headers,
      timeout: 600_000,
    }, (upstreamResponse) => {
      upstreamResponseRef = upstreamResponse;
      const closeDownstream = () => {
        releaseSlot();
        if (!res.destroyed) res.destroy();
      };
      upstreamResponse.once('aborted', closeDownstream);
      upstreamResponse.once('error', closeDownstream);
      upstreamResponse.once('end', releaseSlot);
      upstreamResponse.once('close', () => {
        if (!upstreamResponse.complete && !res.destroyed) res.destroy();
        releaseSlot();
      });

      if (res.destroyed) {
        upstreamResponse.destroy(new Error('client disconnected'));
        releaseSlot();
        return;
      }

      const responseHeaders = {
        'cache-control': 'no-store',
        'x-content-type-options': 'nosniff',
        connection: 'close',
      };
      for (const [name, rawValue] of Object.entries(upstreamResponse.headers)) {
        const lower = name.toLowerCase();
        if (STRIP_RESPONSE.has(lower) || rawValue === undefined) continue;
        responseHeaders[lower] = rawValue;
      }
      res.writeHead(upstreamResponse.statusCode || 502, responseHeaders);
      upstreamResponse.pipe(res);
    });
  } catch {
    releaseSlot();
    localResponse(res, 502, 'provider request failed');
    return;
  }

  res.once('finish', releaseSlot);
  res.once('close', () => {
    const clientDisconnected = !res.writableFinished;
    releaseSlot();
    if (!clientDisconnected) return;

    const error = new Error('client disconnected');
    if (upstreamResponseRef && !upstreamResponseRef.destroyed) {
      upstreamResponseRef.destroy(error);
    }
    if (!upstreamRequest.destroyed) {
      upstreamRequest.destroy(error);
    }
  });

  upstreamRequest.once('timeout', () => {
    releaseSlot();
    upstreamRequest.destroy(new Error('upstream timeout'));
  });
  upstreamRequest.once('error', () => {
    releaseSlot();
    if (!res.headersSent && !res.destroyed) localResponse(res, 502, 'provider request failed');
    else if (!res.destroyed) res.destroy();
  });

  try {
    upstreamRequest.end(body);
  } catch {
    releaseSlot();
    upstreamRequest.destroy();
    if (!res.headersSent && !res.destroyed) localResponse(res, 502, 'provider request failed');
    else if (!res.destroyed) res.destroy();
  }
});

server.requestTimeout = 610_000;
server.headersTimeout = 15_000;
server.keepAliveTimeout = 1_000;
server.maxHeadersCount = 128;
server.listen(listenPort, listenHost, () => {
  // Do not log request data, headers, provider responses, or credentials.
  process.stdout.write('credential proxy ready\n');
});

for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => server.close(() => process.exit(0)));
}
