// =============================================================================
// Standalone Spreadsheet Controller (WebAssembly & JS)
// =============================================================================

// Active spreadsheet state
const COLS = 26; // A-Z
const ROWS = 30; // 1-30
let rawCells = {}; // cellId -> raw input (e.g. "=A1+B1" or "10")
let evaluatedCells = {}; // cellId -> evaluated string/number
let selectedCell = "A1";

// WASI / WebAssembly state
let wasmModule = null;

// Initialize grid on load
document.addEventListener("DOMContentLoaded", async () => {
  createGrid();
  selectCell("A1");
  setupEventListeners();
  await loadWasm();
  await evaluateSheet();
});

// Load the compiled PatLang spreadsheet WASM
async function loadWasm() {
  try {
    const response = await fetch("../portfolio/build/spreadsheet.wasm");
    const buffer = await response.arrayBuffer();
    wasmModule = await WebAssembly.compile(buffer);
    console.log("PatLang Spreadsheet WebAssembly loaded successfully.");
  } catch (err) {
    console.error("Failed to load spreadsheet.wasm via fetch, trying to fall back to local relative path...", err);
    try {
      const response = await fetch("spreadsheet.wasm");
      const buffer = await response.arrayBuffer();
      wasmModule = await WebAssembly.compile(buffer);
      console.log("PatLang Spreadsheet WebAssembly loaded successfully from local path.");
    } catch (err2) {
      console.error("WebAssembly loading failed completely. Make sure to serve via HTTP/HTTPS.", err2);
    }
  }
}

// WASI simulator for running PatLang compiler/engine in browser
async function runPatLangEngine(inputJson) {
  if (!wasmModule) {
    console.error("WASM module not loaded yet.");
    return null;
  }

  let stdout = '';
  const dec = new TextDecoder();
  const enc = new TextEncoder();
  let mem = null;

  // Set up command line arguments (argv[0] is program, argv[1] is the JSON payload)
  const args = ["spreadsheet", inputJson];
  const abufs = args.map(a => enc.encode(a));

  const wasi = {
    fd_write(fd, iovs, len, nw) {
      const dv = new DataView(mem.buffer);
      let w = 0;
      for (let i = 0; i < len; i++) {
        const p = iovs + 8 * i;
        const ptr = dv.getUint32(p, true);
        const l = dv.getUint32(p + 4, true);
        stdout += dec.decode(new Uint8Array(mem.buffer, ptr, l));
        w += l;
      }
      dv.setUint32(nw, w, true);
      return 0;
    },
    random_get(p, l) {
      crypto.getRandomValues(new Uint8Array(mem.buffer, p, l));
      return 0;
    },
    clock_time_get(cid, prec, tp) {
      const dv = new DataView(mem.buffer);
      const ns = BigInt(Math.round((performance.timeOrigin + performance.now()) * 1e6));
      dv.setBigUint64(tp, ns, true);
      return 0;
    },
    args_sizes_get(pc, ps) {
      const dv = new DataView(mem.buffer);
      let total = 0;
      for (const a of abufs) total += a.length + 1;
      dv.setUint32(pc, abufs.length, true);
      dv.setUint32(ps, total, true);
      return 0;
    },
    args_get(argvP, dataP) {
      const dv = new DataView(mem.buffer);
      let off = dataP;
      for (let i = 0; i < abufs.length; i++) {
        dv.setUint32(argvP + 4 * i, off, true);
        new Uint8Array(mem.buffer, off, abufs[i].length).set(abufs[i]);
        dv.setUint8(off + abufs[i].length, 0);
        off += abufs[i].length + 1;
      }
      return 0;
    },
    environ_sizes_get(pc, ps) {
      const dv = new DataView(mem.buffer);
      dv.setUint32(pc, 0, true);
      dv.setUint32(ps, 0, true);
      return 0;
    },
    environ_get() { return 0; },
    proc_exit(c) {
      const e = new Error('exit');
      e.exitCode = c;
      throw e;
    },
    fd_close() { return 0; },
    fd_fdstat_get() { return 0; },
    fd_seek() { return 70; },
    fd_read() { return 8; },
    fd_prestat_get() { return 8; },
    fd_prestat_dir_name() { return 8; },
    path_open() { return 76; },
    sched_yield() { return 0; },
    poll_oneoff() { return 52; }
  };

  const wasiNs = new Proxy(wasi, { get(t, k) { return k in t ? t[k] : (() => 58); } });

  try {
    const inst = await WebAssembly.instantiate(wasmModule, { wasi_snapshot_preview1: wasiNs });
    mem = inst.exports.memory;
    try {
      inst.exports._start();
    } catch (e) {
      if (!(e && e.exitCode === 0)) throw e;
    }
    return stdout;
  } catch (err) {
    console.error("WASM Run Error:", err, stdout);
    return null;
  }
}

// Evaluate sheet cells via PatLang WebAssembly Engine
async function evaluateSheet() {
  const payload = JSON.stringify({
    cells: rawCells,
    max_col: COLS - 1,
    max_row: ROWS - 1
  });

  const output = await runPatLangEngine(payload);
  if (!output) return;

  try {
    const res = JSON.parse(output.trim());
    evaluatedCells = res.values || {};
    
    // Update grid cells with evaluated values
    for (let c = 0; c < COLS; c++) {
      for (let r = 0; r < ROWS; r++) {
        const cellId = getCellId(c, r);
        const cellEl = document.getElementById(cellId);
        if (cellEl && document.activeElement !== cellEl) {
          const val = evaluatedCells[cellId] || "";
          cellEl.textContent = val;
        }
      }
    }

    // Update Markdown table preview
    if (res.markdown) {
      document.getElementById("preview-content").innerHTML = marked.parse(res.markdown);
    }
  } catch (err) {
    console.error("Error parsing PatLang response:", err, output);
  }
}

// Generate the HTML table cells dynamically
function createGrid() {
  const grid = document.getElementById("grid");
  grid.innerHTML = "";

  // Corner cell
  const corner = document.createElement("div");
  corner.className = "grid-header corner-header";
  grid.appendChild(corner);

  // Column headers (A-Z)
  for (let c = 0; c < COLS; c++) {
    const colHeader = document.createElement("div");
    colHeader.className = "grid-header column-header";
    colHeader.textContent = String.fromCharCode(65 + c);
    grid.appendChild(colHeader);
  }

  // Rows
  for (let r = 0; r < ROWS; r++) {
    // Row header (1-30)
    const rowHeader = document.createElement("div");
    rowHeader.className = "grid-header row-header";
    rowHeader.textContent = r + 1;
    grid.appendChild(rowHeader);

    // Cells
    for (let c = 0; c < COLS; c++) {
      const cell = document.createElement("div");
      cell.className = "cell";
      cell.id = getCellId(c, r);
      cell.contentEditable = "false";
      grid.appendChild(cell);
    }
  }
}

function getCellId(col, row) {
  return String.fromCharCode(65 + col) + (row + 1);
}

function selectCell(cellId) {
  // Deselect previous
  if (selectedCell) {
    const prevCell = document.getElementById(selectedCell);
    if (prevCell) {
      prevCell.classList.remove("selected");
      prevCell.contentEditable = "false";
    }
  }

  selectedCell = cellId;
  const activeCell = document.getElementById(cellId);
  if (activeCell) {
    activeCell.classList.add("selected");
    activeCell.focus();
    document.getElementById("active-cell-address").textContent = cellId;
    document.getElementById("formula-input").value = rawCells[cellId] || "";
  }
}

// Convert cell ID like "B5" to column and row indices
function getCellCoords(cellId) {
  const colLetter = cellId[0];
  const col = colLetter.charCodeAt(0) - 65;
  const row = parseInt(cellId.slice(1), 10) - 1;
  return { col, row };
}

// Set up UI event listeners
function setupEventListeners() {
  const grid = document.getElementById("grid");

  // Selection on click
  grid.addEventListener("click", (e) => {
    if (e.target.classList.contains("cell")) {
      selectCell(e.target.id);
    }
  });

  // Enter edit mode on double click
  grid.addEventListener("dblclick", (e) => {
    if (e.target.classList.contains("cell")) {
      enterEditMode(e.target);
    }
  });

  // Handle cell key navigation and editing shortcuts
  grid.addEventListener("keydown", (e) => {
    if (!e.target.classList.contains("cell")) return;

    const cellEl = e.target;
    const isEditing = cellEl.classList.contains("editing");
    const { col, row } = getCellCoords(cellEl.id);

    if (isEditing) {
      // While editing: Enter/Tab commit and navigate
      if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault();
        cellEl.blur(); // Triggers focusout/save
        // Move selection down
        if (row < ROWS - 1) {
          selectCell(getCellId(col, row + 1));
        }
      } else if (e.key === "Tab") {
        e.preventDefault();
        cellEl.blur();
        // Move selection right (or left with Shift)
        if (e.shiftKey) {
          if (col > 0) selectCell(getCellId(col - 1, row));
        } else {
          if (col < COLS - 1) selectCell(getCellId(col + 1, row));
        }
      } else if (e.key === "Escape") {
        e.preventDefault();
        // Cancel edits by restoring raw content
        cellEl.textContent = evaluatedCells[cellEl.id] || "";
        cellEl.classList.remove("editing");
        cellEl.contentEditable = "false";
        selectCell(cellEl.id);
      }
    } else {
      // Not editing: Arrows/Tab/Enter navigate or trigger edit mode
      let targetCol = col;
      let targetRow = row;
      let shouldNavigate = false;

      if (e.key === "ArrowUp") {
        e.preventDefault();
        if (row > 0) { targetRow = row - 1; shouldNavigate = true; }
      } else if (e.key === "ArrowDown") {
        e.preventDefault();
        if (row < ROWS - 1) { targetRow = row + 1; shouldNavigate = true; }
      } else if (e.key === "ArrowLeft") {
        e.preventDefault();
        if (col > 0) { targetCol = col - 1; shouldNavigate = true; }
      } else if (e.key === "ArrowRight") {
        e.preventDefault();
        if (col < COLS - 1) { targetCol = col + 1; shouldNavigate = true; }
      } else if (e.key === "Tab") {
        e.preventDefault();
        if (e.shiftKey) {
          if (col > 0) { targetCol = col - 1; shouldNavigate = true; }
        } else {
          if (col < COLS - 1) { targetCol = col + 1; shouldNavigate = true; }
        }
      } else if (e.key === "Enter") {
        e.preventDefault();
        enterEditMode(cellEl);
      } else if (e.key === "Backspace" || e.key === "Delete") {
        e.preventDefault();
        delete rawCells[cellEl.id];
        cellEl.textContent = "";
        evaluateSheet();
        document.getElementById("formula-input").value = "";
      } else if (e.key.length === 1 && !e.ctrlKey && !e.metaKey && !e.altKey) {
        // Start typing directly to replace value
        enterEditMode(cellEl, true);
      }

      if (shouldNavigate) {
        selectCell(getCellId(targetCol, targetRow));
      }
    }
  });

  // Focusout commits the cell edit
  grid.addEventListener("focusout", async (e) => {
    if (e.target.classList.contains("cell")) {
      const cellEl = e.target;
      if (cellEl.classList.contains("editing")) {
        cellEl.classList.remove("editing");
        cellEl.contentEditable = "false";
        const text = cellEl.textContent.trim();
        if (text) {
          rawCells[cellEl.id] = text;
        } else {
          delete rawCells[cellEl.id];
        }
        await evaluateSheet();
      }
    }
  });

  // Formula bar input updates active cell
  const formulaInput = document.getElementById("formula-input");
  formulaInput.addEventListener("input", (e) => {
    if (selectedCell) {
      rawCells[selectedCell] = e.target.value;
      const cellEl = document.getElementById(selectedCell);
      if (cellEl && !cellEl.classList.contains("editing")) {
        cellEl.textContent = e.target.value;
      }
    }
  });

  formulaInput.addEventListener("keydown", async (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      await evaluateSheet();
      const cellEl = document.getElementById(selectedCell);
      if (cellEl) cellEl.focus();
    }
  });

  // Action Buttons
  document.getElementById("btn-export-markdown").addEventListener("click", exportMarkdown);
  document.getElementById("btn-import-markdown").addEventListener("click", importMarkdown);
  document.getElementById("btn-export-xlsx").addEventListener("click", exportXLSX);
  document.getElementById("file-import-xlsx").addEventListener("change", importXLSX);
}

function enterEditMode(cellEl, overwrite = false) {
  cellEl.classList.add("editing");
  cellEl.contentEditable = "true";
  if (overwrite) {
    cellEl.textContent = "";
  } else {
    cellEl.textContent = rawCells[cellEl.id] || "";
  }
  cellEl.focus();
  
  // Place cursor at the end of the text
  const range = document.createRange();
  const sel = window.getSelection();
  range.selectNodeContents(cellEl);
  range.collapse(false);
  sel.removeAllRanges();
  sel.addRange(range);
}

// Markdown Import/Export
function exportMarkdown() {
  const mdText = document.getElementById("preview-content").innerText;
  const blob = new Blob([mdText], { type: "text/markdown" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "spreadsheet_export.md";
  a.click();
}

function importMarkdown() {
  const input = prompt("Paste Markdown table here:");
  if (!input) return;

  const lines = input.split("\n").map(l => l.trim()).filter(l => l.startsWith("|"));
  if (lines.length < 2) {
    alert("Invalid Markdown table format.");
    return;
  }

  rawCells = {};
  
  let row = 0;
  for (let i = 0; i < lines.length; i++) {
    if (i === 1) continue; // Skip separator line
    const parts = lines[i].split("|").map(p => p.trim()).filter((_, idx, arr) => idx > 0 && idx < arr.length - 1);
    for (let col = 0; col < Math.min(parts.length, COLS); col++) {
      const cellId = getCellId(col, row);
      rawCells[cellId] = parts[col];
    }
    row++;
  }

  evaluateSheet();
}

// SheetJS XLSX Import/Export
function exportXLSX() {
  const data = [];
  for (let r = 0; r < ROWS; r++) {
    const rowData = {};
    for (let c = 0; c < COLS; c++) {
      const cellId = getCellId(c, r);
      const val = evaluatedCells[cellId] || rawCells[cellId] || "";
      rowData[String.fromCharCode(65 + c)] = val;
    }
    data.push(rowData);
  }

  const ws = XLSX.utils.json_to_sheet(data);
  const wb = XLSX.utils.book_new();
  XLSX.utils.book_append_sheet(wb, ws, "Sheet1");
  XLSX.writeFile(wb, "patlang_spreadsheet.xlsx");
}

function importXLSX(e) {
  const files = e.target.files;
  if (!files || files.length === 0) return;
  const file = files[0];

  const reader = new FileReader();
  reader.onload = (event) => {
    const data = new Uint8Array(event.target.result);
    const workbook = XLSX.read(data, { type: "array" });
    const sheetName = workbook.SheetNames[0];
    const worksheet = workbook.Sheets[sheetName];
    
    // Convert sheet back to raw cell mappings directly via keys
    rawCells = {};
    for (let key in worksheet) {
      if (key[0] === '!') continue; // Skip metadata
      const cellObj = worksheet[key];
      if (cellObj && cellObj.v !== undefined) {
        rawCells[key] = cellObj.v.toString();
      }
    }

    evaluateSheet();
    // Re-select active cell to update UI state
    selectCell(selectedCell);
  };
  reader.readAsArrayBuffer(file);
}

