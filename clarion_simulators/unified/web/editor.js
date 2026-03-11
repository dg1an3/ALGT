async function parseEditor() {
  const source = document.getElementById("editor").value;
  const output = document.getElementById("editor-ast");
  output.textContent = "Parsing...";
  try {
    const resp = await fetch("/api/parse", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({source: source})
    });
    const data = await resp.json();
    if (data.status === "ok") {
      output.textContent = "=== Simple AST ===\n" + data.simple_ast + "\n\n=== Bridged AST ===\n" + data.bridged_ast;
    } else {
      output.innerHTML = '<span class="run-error">' + data.message + '</span>';
    }
  } catch(e) {
    output.innerHTML = '<span class="run-error">' + e.message + '</span>';
  }
}

async function runEditor() {
  const source = document.getElementById("editor").value;
  const proc = prompt("Procedure name:", "MyAdd");
  if (!proc) return;
  const args = prompt("Arguments (comma-separated):", "3, 4");
  const output = document.getElementById("editor-ast");
  output.textContent = "Running " + proc + "...";
  try {
    const resp = await fetch("/api/run", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({source: source, procedure: proc, args: args || ""})
    });
    const data = await resp.json();
    if (data.status === "ok") {
      output.innerHTML = '<span class="run-result">Result: ' + data.result + '</span>';
    } else {
      output.innerHTML = '<span class="run-error">Error: ' + data.message + '</span>';
    }
  } catch(e) {
    output.innerHTML = '<span class="run-error">' + e.message + '</span>';
  }
}
