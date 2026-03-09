## GUI implementation for SovovaMulti — served via HTTP.jl + JSON3.jl

using Printf

# ── Uploaded data cache ──────────────────────────────────────────────
const _gui_data   = Ref{Union{Nothing,Matrix{Float64}}}(nothing)
const _gui_result = Ref{Any}(nothing)  # holds (SovovaResult, ExtractionCurve) after a run

# ── HTML page ────────────────────────────────────────────────────────
const _GUI_HTML = raw"""
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>SovovaMulti — Supercritical Extraction Fitting</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:system-ui,-apple-system,sans-serif;background:#f4f6fb;color:#23283a}
h1{text-align:center;padding:18px 0 6px;font-size:1.45rem;color:#1e3a5f}
.subtitle{text-align:center;color:#6b7280;font-size:.88rem;margin-bottom:14px}
.container{max-width:720px;margin:0 auto;padding:0 14px 40px}
fieldset{border:1px solid #d1d5db;border-radius:8px;padding:14px 16px;margin-bottom:14px;background:#fff}
legend{font-weight:600;font-size:.95rem;padding:0 6px;color:#1e3a5f}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:8px 16px}
label{font-size:.82rem;color:#4b5563;display:flex;flex-direction:column;gap:2px}
input[type=text],input[type=number],input[type=file],select{
  border:1px solid #d1d5db;border-radius:4px;padding:5px 8px;font-size:.88rem;width:100%}
input:focus{outline:2px solid #3b82f6;border-color:transparent}
button{cursor:pointer;border:none;border-radius:6px;padding:10px 28px;font-size:.95rem;
  font-weight:600;color:#fff;background:#2563eb;transition:background .15s}
button:hover{background:#1d4ed8}
button:disabled{background:#93c5fd;cursor:not-allowed}
.btn-row{text-align:center;margin:14px 0}
#status{text-align:center;margin:8px 0;font-size:.9rem;color:#4b5563;min-height:1.4em}
#results{white-space:pre-wrap;font-family:'Fira Code',monospace;font-size:.84rem;
  background:#f9fafb;border:1px solid #e5e7eb;border-radius:6px;padding:12px;display:none;margin-top:10px}
.dl-row{display:none;justify-content:center;gap:12px;margin:12px 0}
.dl-btn{display:inline-block;border-radius:6px;padding:9px 22px;font-size:.9rem;
  font-weight:600;color:#fff;background:#059669;text-decoration:none;transition:background .15s}
.dl-btn:hover{background:#047857}
table.preview{width:100%;border-collapse:collapse;font-size:.82rem;margin-top:8px}
table.preview th,table.preview td{border:1px solid #e5e7eb;padding:3px 6px;text-align:right}
table.preview th{background:#f3f4f6}
</style>
</head>
<body>
<h1>SovovaMulti</h1>
<p class="subtitle">Sovová (1994) supercritical extraction model — multi-curve fitting</p>

<div class="container">

<!-- Data file -->
<fieldset>
<legend>Experimental Data</legend>
<label>Data file (text or .xlsx)
  <input type="file" id="datafile" accept=".txt,.csv,.dat,.tsv,.xlsx"/>
</label>
<div id="preview"></div>
</fieldset>

<!-- Operating conditions -->
<fieldset>
<legend>Operating Conditions</legend>
<div class="grid">
  <label>Temperature (K)        <input type="number" id="temperature" step="any" value="313.15"/></label>
  <label>Porosity                <input type="number" id="porosity" step="any" value="0.4"/></label>
  <label>x₀ (kg/kg)             <input type="number" id="x0" step="any" value="0.05"/></label>
  <label>Solid density (g/cm³)  <input type="number" id="solid_density" step="any" value="1.1"/></label>
  <label>Solvent density (g/cm³)<input type="number" id="solvent_density" step="any" value="0.8"/></label>
  <label>Flow rate (cm³/min)    <input type="number" id="flow_rate" step="any" value="5.0"/></label>
  <label>Bed height (cm)        <input type="number" id="bed_height" step="any" value="20.0"/></label>
  <label>Bed diameter (cm)      <input type="number" id="bed_diameter" step="any" value="2.0"/></label>
  <label>Particle diameter (cm) <input type="number" id="particle_diameter" step="any" value="0.05"/></label>
  <label>Solid mass (g)         <input type="number" id="solid_mass" step="any" value="50.0"/></label>
  <label>Solubility (kg/kg)     <input type="number" id="solubility" step="any" value="0.005"/></label>
  <label>Viscosity (mPa·s)      <input type="number" id="viscosity" step="any" value="0.06"/></label>
</div>
</fieldset>

<!-- Optimizer options -->
<fieldset>
<legend>Optimizer Options</legend>
<div class="grid">
  <label>kya lower bound  <input type="number" id="kya_lo" step="any" value="0.0"/></label>
  <label>kya upper bound  <input type="number" id="kya_hi" step="any" value="0.05"/></label>
  <label>kxa lower bound  <input type="number" id="kxa_lo" step="any" value="0.0"/></label>
  <label>kxa upper bound  <input type="number" id="kxa_hi" step="any" value="0.005"/></label>
  <label>xk/x₀ lower bound <input type="number" id="xk_lo" step="any" value="0.0"/></label>
  <label>xk/x₀ upper bound <input type="number" id="xk_hi" step="any" value="1.0"/></label>
  <label>Max evaluations   <input type="number" id="maxevals" step="1" value="50000"/></label>
</div>
</fieldset>

<div class="btn-row">
  <button id="runbtn" disabled>Run Fitting</button>
</div>
<div id="status"></div>
<pre id="results"></pre>
<div id="dlrow" class="dl-row">
  <a href="/api/download?format=txt"  class="dl-btn" download="SovovaMulti_results.txt">Download TXT</a>
  <a href="/api/download?format=xlsx" class="dl-btn" download="SovovaMulti_results.xlsx">Download XLSX</a>
</div>

</div><!-- container -->
<script>
const $ = id => document.getElementById(id);

// ── File upload → preview ────────────────────────────────────────
$('datafile').addEventListener('change', async e => {
  const file = e.target.files[0];
  if (!file) return;
  const formData = new FormData();
  formData.append('file', file);
  $('status').textContent = 'Uploading…';
  try {
    const res = await fetch('/api/upload', {method:'POST', body:formData});
    const json = await res.json();
    if (json.error) { $('status').textContent = json.error; return; }
    // Show preview table
    const rows = json.data;
    let html = '<table class="preview"><tr>';
    html += '<th>Time (min)</th>';
    for (let j = 1; j < rows[0].length; j++) html += '<th>Rep ' + j + ' (g)</th>';
    html += '</tr>';
    const n = Math.min(rows.length, 8);
    for (let i = 0; i < n; i++) {
      html += '<tr>';
      for (let j = 0; j < rows[i].length; j++) html += '<td>' + rows[i][j] + '</td>';
      html += '</tr>';
    }
    if (rows.length > n) html += '<tr><td colspan="' + rows[0].length + '">… ' + (rows.length - n) + ' more rows</td></tr>';
    html += '</table>';
    $('preview').innerHTML = html;
    $('runbtn').disabled = false;
    $('dlrow').style.display = 'none';
    $('status').textContent = 'Data loaded: ' + rows.length + ' rows × ' + rows[0].length + ' columns.';
  } catch(err) { $('status').textContent = 'Upload failed: ' + err.message; }
});

// ── Run fitting ──────────────────────────────────────────────────
$('runbtn').addEventListener('click', async () => {
  const ids = ['temperature','porosity','x0','solid_density','solvent_density',
    'flow_rate','bed_height','bed_diameter','particle_diameter','solid_mass',
    'solubility','viscosity','kya_lo','kya_hi','kxa_lo','kxa_hi',
    'xk_lo','xk_hi','maxevals'];
  const body = {};
  for (const id of ids) {
    const v = parseFloat($(id).value);
    if (isNaN(v)) { $('status').textContent = 'Invalid value for ' + id; return; }
    body[id] = v;
  }
  $('runbtn').disabled = true;
  $('dlrow').style.display = 'none';
  $('status').textContent = 'Running optimizer — this may take a minute…';
  $('results').style.display = 'none';
  try {
    const res = await fetch('/api/run', {
      method:'POST', headers:{'Content-Type':'application/json'},
      body: JSON.stringify(body)
    });
    const json = await res.json();
    if (json.error) { $('status').textContent = 'Error: ' + json.error; $('runbtn').disabled = false; return; }
    $('status').textContent = 'Done!';
    $('results').style.display = 'block';
    $('results').textContent = json.report;
    $('dlrow').style.display = 'flex';
  } catch(err) { $('status').textContent = 'Error: ' + err.message; }
  $('runbtn').disabled = false;
});
</script>
</body>
</html>
"""

# ── Helper: parse multipart upload and return Matrix{Float64} ────
function _parse_upload(req::HTTP.Request)
    parts = HTTP.parse_multipart_form(req)
    isempty(parts) && error("No file received")
    part = first(parts)
    fname = lowercase(something(part.filename, "data.txt"))
    raw = read(part.data)  # IO → bytes

    if endswith(fname, ".xlsx")
        # Write to temp file and read with XLSX
        tmppath = tempname() * ".xlsx"
        try
            write(tmppath, raw)
            xf = XLSX.readxlsx(tmppath)
            ws = xf[1]
            cells = ws[:]
            # Auto-detect header: if first row has non-numeric values, skip it
            firstval = cells[1, 1]
            start = (firstval isa AbstractString && tryparse(Float64, firstval) === nothing) ? 2 : 1
            data = Float64.(cells[start:end, :])
        finally
            rm(tmppath; force=true)
        end
    else
        data = readdlm(IOBuffer(raw), Float64; comments=true)
    end
    return data
end

# ── Start GUI server ─────────────────────────────────────────────
function _start_gui(port::Int, launch::Bool)
    router = HTTP.Router()

    # Serve the HTML page
    HTTP.register!(router, "GET", "/", _ -> HTTP.Response(200, ["Content-Type" => "text/html"], _GUI_HTML))

    # File upload endpoint
    HTTP.register!(router, "POST", "/api/upload", function(req)
        try
            data = _parse_upload(req)
            _gui_data[] = data
            rows = [data[i, :] for i in 1:size(data, 1)]
            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON3.write(Dict("data" => rows)))
        catch e
            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON3.write(Dict("error" => sprint(showerror, e))))
        end
    end)

    # Run fitting endpoint
    HTTP.register!(router, "POST", "/api/run", function(req)
        try
            p = JSON3.read(String(req.body))
            data = _gui_data[]
            data === nothing && error("No data loaded — upload a file first.")

            curve = ExtractionCurve(
                data              = data,
                temperature       = Float64(p[:temperature]),
                porosity          = Float64(p[:porosity]),
                x0                = Float64(p[:x0]),
                solid_density     = Float64(p[:solid_density]),
                solvent_density   = Float64(p[:solvent_density]),
                flow_rate         = Float64(p[:flow_rate]),
                bed_height        = Float64(p[:bed_height]),
                bed_diameter      = Float64(p[:bed_diameter]),
                particle_diameter = Float64(p[:particle_diameter]),
                solid_mass        = Float64(p[:solid_mass]),
                solubility        = Float64(p[:solubility]),
                viscosity         = Float64(p[:viscosity]),
            )

            result = sovova_multi(curve;
                kya_bounds      = (Float64(p[:kya_lo]), Float64(p[:kya_hi])),
                kxa_bounds      = (Float64(p[:kxa_lo]), Float64(p[:kxa_hi])),
                xk_ratio_bounds = (Float64(p[:xk_lo]),  Float64(p[:xk_hi])),
                maxevals        = Int(p[:maxevals]),
                tracemode       = :silent,
            )
            _gui_result[] = (result, curve)

            report = sprint() do io
                println(io, "══════════════════════════════════════")
                println(io, " SovovaMulti — Fitting Results")
                println(io, "══════════════════════════════════════")
                println(io)
                println(io, "  kya      = ", result.kya[1], " 1/s")
                println(io, "  kxa      = ", result.kxa[1], " 1/s")
                println(io, "  xk/x0    = ", result.xk_ratio)
                println(io, "  xk       = ", result.xk[1], " kg/kg")
                println(io, "  tCER     = ", result.tcer[1], " s")
                println(io, "  SSR      = ", result.objective)
                println(io)
                println(io, "──────────────────────────────────────")
                println(io, " Experimental vs Calculated (kg)")
                println(io, "──────────────────────────────────────")
                t_min = curve.t ./ 60.0
                m_exp = curve.m_ext .* 1000.0   # back to g
                m_cal = result.ycal[1] .* 1000.0
                for i in eachindex(t_min)
                    @Printf.printf(io, "  t=%7.1f min  exp=%8.4f g  cal=%8.4f g\n",
                        t_min[i], m_exp[i], m_cal[i])
                end
            end

            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON3.write(Dict("report" => report)))
        catch e
            return HTTP.Response(200, ["Content-Type" => "application/json"],
                JSON3.write(Dict("error" => sprint(showerror, e))))
        end
    end)

    # Download results endpoint
    HTTP.register!(router, "GET", "/api/download", function(req)
        cached = _gui_result[]
        cached === nothing && return HTTP.Response(400, "No results yet — run the fitting first.")
        result, curve = cached
        fmt = contains(req.target, "format=xlsx") ? "xlsx" : "txt"
        tmpfile = tempname() * "." * fmt
        try
            export_results(tmpfile, result, curve)
            body = read(tmpfile)
            mime = fmt == "xlsx" ?
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" :
                "text/plain; charset=utf-8"
            return HTTP.Response(200,
                ["Content-Type"        => mime,
                 "Content-Disposition" => "attachment; filename=\"SovovaMulti_results.$fmt\""],
                body)
        finally
            rm(tmpfile; force=true)
        end
    end)

    server = HTTP.serve!(router, HTTP.Sockets.localhost, port)
    url = "http://127.0.0.1:$port"
    @info "SovovaMulti GUI running at $url — press Ctrl-C to stop"

    if launch
        try
            if Sys.iswindows()
                run(`cmd /c start $url`)
            elseif Sys.isapple()
                run(`open $url`)
            else
                run(`xdg-open $url`)
            end
        catch
            @info "Could not open browser automatically. Open $url manually."
        end
    end

    return server
end
