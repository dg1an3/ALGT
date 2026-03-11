function switchTab(el, id) {
  document.querySelectorAll(".tab").forEach(t => t.classList.remove("active"));
  document.querySelectorAll(".tab-content").forEach(t => t.classList.remove("active"));
  el.classList.add("active");
  document.getElementById(id).classList.add("active");
}

async function runProcedure() {
  const proc = document.getElementById("proc").value;
  const argsStr = document.getElementById("args").value;
  const output = document.getElementById("run-output");
  output.textContent = "Running " + proc + "...";
  try {
    const resp = await fetch("/api/run", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify({
        file: window.__filePath,
        procedure: proc,
        args: argsStr
      })
    });
    const data = await resp.json();
    if (data.status === "ok") {
      output.innerHTML = '<span class="run-result">Result: ' + data.result + '</span>';
    } else {
      output.innerHTML = '<span class="run-error">Error: ' + data.message + '</span>';
    }
  } catch(e) {
    output.innerHTML = '<span class="run-error">Error: ' + e.message + '</span>';
  }
}
