#!/usr/bin/env node
import crypto from 'node:crypto';
import fs from 'node:fs';
import http from 'node:http';
import net from 'node:net';
import { pathToFileURL } from 'node:url';

const PRODUCTION_ROOTS = Object.freeze([
  'openai.com',
  'chatgpt.com',
  'oaistatic.com',
  'oaiusercontent.com',
]);

function fail(message) {
  throw new Error(message);
}

function readRegularSecret(file, label) {
  const stat = fs.lstatSync(file);
  if (!stat.isFile() || stat.isSymbolicLink()) fail(`${label} path is not a regular file`);
  const value = fs.readFileSync(file, 'utf8').trim();
  if (!value || value.length > 1024 || /[\r\n]/.test(value)) fail(`${label} is empty or malformed`);
  return value;
}

function constantTimeEqual(actual, expected) {
  const a = Buffer.from(actual, 'utf8');
  const b = Buffer.from(expected, 'utf8');
  if (a.length !== b.length) {
    const ah = crypto.createHash('sha256').update(a).digest();
    const bh = crypto.createHash('sha256').update(b).digest();
    return crypto.timingSafeEqual(ah, bh) && false;
  }
  return crypto.timingSafeEqual(a, b);
}

export function normalizeHost(raw) {
  if (typeof raw !== 'string') return null;
  const host = raw.trim().toLowerCase().replace(/[.]$/, '');
  if (!host || host.length > 253 || host.includes('..') || net.isIP(host)) return null;
  if (!/^[a-z0-9.-]+$/.test(host)) return null;
  const labels = host.split('.');
  if (labels.some((label) => !label || label.length > 63 || label.startsWith('-') || label.endsWith('-'))) return null;
  return host;
}

export function hostAllowed(host, roots = PRODUCTION_ROOTS) {
  const normalized = normalizeHost(host);
  if (!normalized) return false;
  return roots.some((root) => normalized === root || normalized.endsWith(`.${root}`));
}

export function parseConnectTarget(raw, allowedPorts = new Set([443])) {
  if (typeof raw !== 'string' || raw.includes('/') || raw.includes('@') || raw.includes('[') || raw.includes(']')) return null;
  const match = raw.match(/^([A-Za-z0-9.-]+):([0-9]{1,5})$/);
  if (!match) return null;
  const host = normalizeHost(match[1]);
  const port = Number(match[2]);
  if (!host || !Number.isSafeInteger(port) || port < 1 || port > 65535 || !allowedPorts.has(port)) return null;
  return { host, port };
}

export function main() {
  const testMode = process.env.EGRESS_PROXY_TEST_MODE === '1';
  const clientCredential = readRegularSecret(
    testMode && process.env.EGRESS_CLIENT_SECRET_FILE
      ? process.env.EGRESS_CLIENT_SECRET_FILE
      : '/run/secrets/client_credential',
    'egress proxy client credential',
  );
  const listenHost = testMode ? (process.env.EGRESS_PROXY_LISTEN_HOST || '127.0.0.1') : '0.0.0.0';
  const listenPort = Number(testMode ? (process.env.EGRESS_PROXY_LISTEN_PORT || '8082') : '8082');
  const maxRequests = Number(process.env.EGRESS_PROXY_MAX_REQUESTS || 2000);
  const maxConcurrent = Number(process.env.EGRESS_PROXY_MAX_CONCURRENT || 16);
  const idleTimeoutMs = Number(process.env.EGRESS_PROXY_IDLE_TIMEOUT_MS || 300_000);

  const testRoots = (process.env.EGRESS_PROXY_ALLOWED_HOSTS || '')
    .split(',')
    .map((entry) => entry.trim().toLowerCase())
    .filter(Boolean);
  const allowedRoots = testMode && testRoots.length ? testRoots : PRODUCTION_ROOTS;
  const testPorts = (process.env.EGRESS_PROXY_ALLOWED_PORTS || '')
    .split(',')
    .map((entry) => Number(entry.trim()))
    .filter((value) => Number.isSafeInteger(value) && value >= 1 && value <= 65535);
  const allowedPorts = new Set(testMode && testPorts.length ? testPorts : [443]);

  for (const [name, value, min, max] of [
    ['listen port', listenPort, 0, 65535],
    ['request limit', maxRequests, 1, 1_000_000],
    ['concurrency limit', maxConcurrent, 1, 4096],
    ['idle timeout', idleTimeoutMs, 1000, 3_600_000],
  ]) {
    if (!Number.isSafeInteger(value) || value < min || value > max) fail(`invalid ${name}`);
  }

  let acceptedRequests = 0;
  let activeRequests = 0;

  function authorized(req) {
    const value = req.headers['proxy-authorization'];
    if (typeof value !== 'string' || !value.startsWith('Basic ')) return false;
    let decoded;
    try {
      decoded = Buffer.from(value.slice(6), 'base64').toString('utf8');
    } catch {
      return false;
    }
    return constantTimeEqual(decoded, `codex:${clientCredential}`);
  }

  function socketResponse(socket, status, message, extra = '') {
    if (socket.destroyed) return;
    const body = `${message}\n`;
    socket.end(
      `HTTP/1.1 ${status}\r\n` +
      'Connection: close\r\n' +
      'Cache-Control: no-store\r\n' +
      'X-Content-Type-Options: nosniff\r\n' +
      extra +
      `Content-Length: ${Buffer.byteLength(body)}\r\n\r\n${body}`,
    );
  }

  const server = http.createServer((req, res) => {
    if (req.method === 'GET' && req.url === '/healthz') {
      const body = 'ok\n';
      res.writeHead(200, {
        'content-type': 'text/plain; charset=utf-8',
        'content-length': String(Buffer.byteLength(body)),
        'cache-control': 'no-store',
        connection: 'close',
      });
      res.end(body);
      return;
    }
    res.writeHead(405, { connection: 'close', 'content-length': '0' });
    res.end();
  });

  server.on('connect', (req, clientSocket, head) => {
    if (!authorized(req)) {
      socketResponse(clientSocket, '407 Proxy Authentication Required', 'proxy authentication required', 'Proxy-Authenticate: Basic realm="codex-egress"\r\n');
      return;
    }
    const target = parseConnectTarget(req.url || '', allowedPorts);
    if (!target || !hostAllowed(target.host, allowedRoots)) {
      socketResponse(clientSocket, '403 Forbidden', 'destination is not permitted');
      return;
    }
    if (acceptedRequests >= maxRequests) {
      socketResponse(clientSocket, '429 Too Many Requests', 'per-run connection limit reached');
      return;
    }
    if (activeRequests >= maxConcurrent) {
      socketResponse(clientSocket, '503 Service Unavailable', 'egress proxy concurrency limit reached');
      return;
    }

    acceptedRequests += 1;
    activeRequests += 1;
    let released = false;
    const release = () => {
      if (released) return;
      released = true;
      activeRequests = Math.max(0, activeRequests - 1);
    };

    const upstream = net.connect({ host: target.host, port: target.port });
    upstream.setTimeout(idleTimeoutMs);
    clientSocket.setTimeout(idleTimeoutMs);

    upstream.once('connect', () => {
      if (clientSocket.destroyed) {
        upstream.destroy();
        release();
        return;
      }
      clientSocket.write('HTTP/1.1 200 Connection Established\r\nProxy-Agent: hardened-codex-egress\r\n\r\n');
      if (head?.length) upstream.write(head);
      clientSocket.pipe(upstream);
      upstream.pipe(clientSocket);
    });

    const terminate = () => {
      release();
      if (!upstream.destroyed) upstream.destroy();
      if (!clientSocket.destroyed) clientSocket.destroy();
    };
    upstream.once('timeout', terminate);
    clientSocket.once('timeout', terminate);
    upstream.once('error', () => {
      release();
      if (!clientSocket.destroyed) socketResponse(clientSocket, '502 Bad Gateway', 'upstream connection failed');
    });
    clientSocket.once('error', terminate);
    upstream.once('close', release);
    clientSocket.once('close', () => {
      release();
      if (!upstream.destroyed) upstream.destroy();
    });
  });

  server.on('clientError', (_error, socket) => {
    socketResponse(socket, '400 Bad Request', 'malformed proxy request');
  });
  server.requestTimeout = 0;
  server.headersTimeout = 30_000;
  server.keepAliveTimeout = 5_000;
  server.listen(listenPort, listenHost, () => {
    const address = server.address();
    const port = typeof address === 'object' && address ? address.port : listenPort;
    process.stdout.write(`Codex egress proxy listening on ${listenHost}:${port}\n`);
  });
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  main();
}
