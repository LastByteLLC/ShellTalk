// shelltalk.js — Load ShellTalk WASM and provide a browser UI
//
// Uses the browser's WASI preview 1 shim via @aspect-build/aspect-wasi
// or a minimal stdin/stdout bridge to communicate with the WASM binary.

const WASM_PATH = 'shelltalk.wasm';
const WASM_GZ_PATH = 'shelltalk.wasm.gz';
const WASM_BR_PATH = 'shelltalk.wasm.br';

let wasmInstance = null;
let wasmReady = false;

// WASI memory management for stdin/stdout bridging
let stdinBuffer = '';
let stdinPos = 0;
let stdoutBuffer = '';

// Complete WASI preview1 implementation for the browser.
// Covers all 31 imports needed by the ShellTalk WASM binary.
function createWASI() {
  const textDecoder = new TextDecoder();
  const textEncoder = new TextEncoder();
  const ENOSYS = 52;
  const EBADF = 8;

  function mem() { return new DataView(wasmInstance.exports.memory.buffer); }
  function memBytes() { return new Uint8Array(wasmInstance.exports.memory.buffer); }

  const imports = {
    'wasi_snapshot_preview1': {
      fd_write(fd, iovs, iovsLen, nwrittenPtr) {
        const m = mem();
        let written = 0;
        for (let i = 0; i < iovsLen; i++) {
          const ptr = m.getUint32(iovs + i * 8, true);
          const len = m.getUint32(iovs + i * 8 + 4, true);
          const text = textDecoder.decode(new Uint8Array(wasmInstance.exports.memory.buffer, ptr, len));
          if (fd === 1) stdoutBuffer += text;
          written += len;
        }
        m.setUint32(nwrittenPtr, written, true);
        return 0;
      },

      fd_read(fd, iovs, iovsLen, nreadPtr) {
        const m = mem();
        if (fd !== 0) { m.setUint32(nreadPtr, 0, true); return 0; }
        let totalRead = 0;
        for (let i = 0; i < iovsLen; i++) {
          const ptr = m.getUint32(iovs + i * 8, true);
          const len = m.getUint32(iovs + i * 8 + 4, true);
          const remaining = stdinBuffer.length - stdinPos;
          if (remaining <= 0) break;
          const toRead = Math.min(len, remaining);
          const bytes = textEncoder.encode(stdinBuffer.substring(stdinPos, stdinPos + toRead));
          memBytes().set(bytes, ptr);
          stdinPos += toRead;
          totalRead += toRead;
        }
        m.setUint32(nreadPtr, totalRead, true);
        return 0;
      },

      fd_close()  { return 0; },
      fd_seek()   { return 0; },
      fd_sync()   { return 0; },
      fd_tell(fd, offsetPtr) { mem().setBigUint64(offsetPtr, BigInt(0), true); return 0; },

      fd_fdstat_get(fd, statPtr) {
        const m = mem();
        m.setUint8(statPtr, 2);               // filetype: character device
        m.setUint16(statPtr + 2, 0, true);     // flags
        m.setBigUint64(statPtr + 8, BigInt(0), true);
        m.setBigUint64(statPtr + 16, BigInt(0), true);
        return 0;
      },

      fd_filestat_get(fd, bufPtr) {
        // Zero out the filestat struct (64 bytes)
        memBytes().fill(0, bufPtr, bufPtr + 64);
        return 0;
      },

      fd_filestat_set_times() { return 0; },

      fd_pread(fd, iovs, iovsLen, offset, nreadPtr) {
        mem().setUint32(nreadPtr, 0, true);
        return 0;
      },

      fd_readdir(fd, buf, bufLen, cookie, sizePtr) {
        mem().setUint32(sizePtr, 0, true);
        return 0;
      },

      fd_prestat_get()      { return EBADF; },
      fd_prestat_dir_name() { return EBADF; },

      environ_get() { return 0; },
      environ_sizes_get(countPtr, sizePtr) {
        const m = mem();
        m.setUint32(countPtr, 0, true);
        m.setUint32(sizePtr, 0, true);
        return 0;
      },

      args_get() { return 0; },
      args_sizes_get(countPtr, sizePtr) {
        const m = mem();
        m.setUint32(countPtr, 0, true);
        m.setUint32(sizePtr, 0, true);
        return 0;
      },

      clock_time_get(clockId, precision, timePtr) {
        const now = BigInt(Math.round(performance.now() * 1_000_000));
        mem().setBigUint64(timePtr, now, true);
        return 0;
      },

      clock_res_get(clockId, resPtr) {
        // 1ms resolution in nanoseconds
        mem().setBigUint64(resPtr, BigInt(1_000_000), true);
        return 0;
      },

      proc_exit(code) { throw new WASIExit(code); },

      random_get(bufPtr, bufLen) {
        crypto.getRandomValues(new Uint8Array(wasmInstance.exports.memory.buffer, bufPtr, bufLen));
        return 0;
      },

      poll_oneoff(inPtr, outPtr, nsubscriptions, neventsPtr) {
        mem().setUint32(neventsPtr, 0, true);
        return 0;
      },

      // Filesystem stubs — all return ENOSYS (not supported)
      path_open()                { return ENOSYS; },
      path_filestat_get()        { return ENOSYS; },
      path_filestat_set_times()  { return ENOSYS; },
      path_link()                { return ENOSYS; },
      path_symlink()             { return ENOSYS; },
      path_readlink()            { return ENOSYS; },
      path_remove_directory()    { return ENOSYS; },
      path_rename()              { return ENOSYS; },
      path_unlink_file()         { return ENOSYS; },
      path_create_directory()    { return ENOSYS; },

      // Socket stubs
      sock_accept()              { return ENOSYS; },
      sock_recv()                { return ENOSYS; },
      sock_send()                { return ENOSYS; },
      sock_shutdown()            { return ENOSYS; },

      // Scheduling
      sched_yield()              { return 0; },
    }
  };

  // Wrap with Proxy so any unlisted import returns a stub instead of LinkError
  const raw = imports['wasi_snapshot_preview1'];
  imports['wasi_snapshot_preview1'] = new Proxy(raw, {
    get(target, prop) {
      if (prop in target) return target[prop];
      return () => { console.warn(`WASI stub: ${prop}`); return ENOSYS; };
    }
  });

  return imports;
}

class WASIExit {
  constructor(code) { this.code = code; }
}

// Process a single query through the WASM module
function processQuery(query) {
  if (!wasmReady) return null;

  // Set up stdin with the query
  stdinBuffer = query + '\n';
  stdinPos = 0;
  stdoutBuffer = '';

  try {
    wasmInstance.exports._start();
  } catch (e) {
    if (e instanceof WASIExit) {
      // Normal exit
    } else {
      console.error('WASM error:', e);
      return null;
    }
  }

  // Re-instantiate for next call (WASI _start can only be called once)
  // We'll handle this by re-instantiating
  const output = stdoutBuffer.trim();
  if (!output) return null;

  try {
    return JSON.parse(output);
  } catch {
    return null;
  }
}

// UI binding
const input = document.getElementById('query-input');
const outputArea = document.getElementById('output-area');
const loadingEl = document.getElementById('loading');

function renderResult(result) {
  if (!result) {
    outputArea.innerHTML = '<div class="no-match">No matching command found</div>';
    return;
  }

  if (result.error) {
    outputArea.innerHTML = `<div class="no-match">${result.error}</div>`;
    return;
  }

  const safetyClass = `badge-${result.safety}`;
  const safetyLabel = result.safety;

  // Highlight the first word of the command
  const cmd = result.command;
  const firstSpace = cmd.indexOf(' ');
  const prefix = firstSpace > 0 ? cmd.substring(0, firstSpace) : cmd;
  const rest = firstSpace > 0 ? cmd.substring(firstSpace) : '';

  outputArea.innerHTML = `
    <div class="result">
      <div class="result-command">
        <span class="cmd-prefix">${escapeHtml(prefix)}</span>${escapeHtml(rest)}
      </div>
      <div class="result-meta">
        <span><span class="badge ${safetyClass}">${safetyLabel}</span></span>
        <span>template: ${result.template}</span>
        <span>category: ${result.category}</span>
        <span>confidence: ${Number(result.confidence).toFixed(2)}</span>
      </div>
    </div>
  `;
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Debounced input handler
let debounceTimer;
input.addEventListener('input', () => {
  clearTimeout(debounceTimer);
  debounceTimer = setTimeout(async () => {
    const query = input.value.trim();
    if (!query) {
      outputArea.innerHTML = '<div class="no-match">Type a command description above...</div>';
      return;
    }
    const result = await runQuery(query);
    renderResult(result);
  }, 200);
});

input.addEventListener('keydown', async (e) => {
  if (e.key === 'Enter') {
    clearTimeout(debounceTimer);
    const query = input.value.trim();
    if (!query) return;
    const result = await runQuery(query);
    renderResult(result);
  }
});

// Example buttons
document.querySelectorAll('.example-btn').forEach(btn => {
  btn.addEventListener('click', async () => {
    const query = btn.dataset.query;
    input.value = query;
    input.focus();
    const result = await runQuery(query);
    renderResult(result);
  });
});

// WASM module and instance storage for re-instantiation
let wasmModule = null;
let wasiImports = null;

async function runQuery(query) {
  if (!wasmModule) return null;

  // Re-instantiate for each query (WASI _start is single-use)
  stdinBuffer = query + '\n';
  stdinPos = 0;
  stdoutBuffer = '';

  try {
    const instance = await WebAssembly.instantiate(wasmModule, wasiImports);
    wasmInstance = instance;
    instance.exports._start();
  } catch (e) {
    if (e instanceof WASIExit) {
      // Normal
    } else {
      console.error('WASM error:', e);
      return null;
    }
  }

  const output = stdoutBuffer.trim();
  if (!output) return null;

  try {
    return JSON.parse(output);
  } catch {
    return null;
  }
}

// Prefer compressed variants if available. The raw WASM binary is ~44 MB;
// brotli cuts it to ~12 MB, gzip to ~17 MB. DecompressionStream supports
// gzip in all modern browsers; brotli support landed in Chrome 117+ / Safari
// 17+ so we prefer brotli when the browser advertises support, else gzip,
// else raw. The server never needs to set Content-Encoding — we decompress
// client-side.
async function fetchWasmBytes() {
  const tryFetch = async (url, encoding) => {
    try {
      const resp = await fetch(url);
      if (!resp.ok) return null;
      if (!encoding) return await resp.arrayBuffer();
      loadingEl.textContent = `Decompressing (${encoding})...`;
      const stream = resp.body.pipeThrough(new DecompressionStream(encoding));
      return await new Response(stream).arrayBuffer();
    } catch {
      return null;
    }
  };

  const supportsBrotli =
    typeof DecompressionStream !== 'undefined' &&
    (() => { try { new DecompressionStream('br'); return true; } catch { return false; } })();

  if (supportsBrotli) {
    loadingEl.textContent = 'Downloading (brotli, ~12 MB)...';
    const bytes = await tryFetch(WASM_BR_PATH, 'br');
    if (bytes) return bytes;
  }
  if (typeof DecompressionStream !== 'undefined') {
    loadingEl.textContent = 'Downloading (gzip, ~17 MB)...';
    const bytes = await tryFetch(WASM_GZ_PATH, 'gzip');
    if (bytes) return bytes;
  }
  loadingEl.textContent = 'Downloading (~44 MB) — no compression available...';
  const bytes = await tryFetch(WASM_PATH, null);
  if (!bytes) throw new Error(`Failed to load ${WASM_PATH}`);
  return bytes;
}

// Initialize
async function init() {
  try {
    loadingEl.textContent = 'Downloading ShellTalk WASM module...';

    const bytes = await fetchWasmBytes();

    loadingEl.textContent = 'Compiling WebAssembly...';
    wasmModule = await WebAssembly.compile(bytes);

    wasiImports = createWASI();
    wasmReady = true;

    loadingEl.textContent = '';
    outputArea.innerHTML = '<div class="no-match">Type a command description above...</div>';

    input.focus();
  } catch (err) {
    loadingEl.innerHTML = `<div class="error-msg">Failed to load WASM: ${err.message}</div>`;
    console.error(err);
  }
}

init();
