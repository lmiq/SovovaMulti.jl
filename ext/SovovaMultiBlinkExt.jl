module SovovaMultiBlinkExt

using SovovaMulti
using Blink

const GUI_HTML = """
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>SovovaMulti — Supercritical Extraction Model Fitting</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: "Segoe UI", Tahoma, Geneva, Verdana, sans-serif;
         background: #f0f2f5; color: #333; padding: 20px; }
  h1 { text-align: center; margin-bottom: 6px; color: #2c3e50; font-size: 1.5em; }
  .subtitle { text-align: center; color: #7f8c8d; margin-bottom: 18px; font-size: 0.95em; }
  .container { max-width: 820px; margin: 0 auto; }
  .card { background: #fff; border-radius: 8px; padding: 20px 24px;
          margin-bottom: 16px; box-shadow: 0 1px 3px rgba(0,0,0,0.12); }
  .card h2 { font-size: 1.1em; color: #2980b9; margin-bottom: 12px;
             border-bottom: 2px solid #eee; padding-bottom: 6px; }
  .form-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px 20px; }
  .form-group { display: flex; flex-direction: column; }
  .form-group label { font-size: 0.85em; font-weight: 600; margin-bottom: 3px; color: #555; }
  .form-group .unit { font-size: 0.78em; color: #999; font-weight: 400; }
  .form-group input[type="number"],
  .form-group input[type="text"],
  .form-group select { padding: 7px 10px; border: 1px solid #ccc; border-radius: 4px;
                        font-size: 0.92em; width: 100%; }
  .form-group input:focus, .form-group select:focus {
    outline: none; border-color: #3498db; box-shadow: 0 0 3px rgba(52,152,219,0.3); }
  .file-upload { margin-top: 4px; }
  .file-upload input[type="file"] { font-size: 0.88em; }
  .full-width { grid-column: 1 / -1; }
  .btn { padding: 12px 32px; border: none; border-radius: 6px; cursor: pointer;
         font-size: 1em; font-weight: 600; transition: background 0.2s; }
  .btn-primary { background: #2980b9; color: #fff; }
  .btn-primary:hover { background: #2471a3; }
  .btn-primary:disabled { background: #95a5a6; cursor: not-allowed; }
  .btn-row { text-align: center; margin-top: 10px; }
  #status { margin-top: 14px; padding: 12px; border-radius: 6px; display: none;
            font-family: "Consolas", "Courier New", monospace; font-size: 0.88em;
            white-space: pre-wrap; word-wrap: break-word; line-height: 1.5; }
  #status.info { display: block; background: #eaf2f8; color: #2c3e50; border: 1px solid #aed6f1; }
  #status.success { display: block; background: #eafaf1; color: #1e8449; border: 1px solid #a9dfbf; }
  #status.error { display: block; background: #fdedec; color: #943126; border: 1px solid #f5b7b1; }
  .data-preview { margin-top: 10px; font-family: monospace; font-size: 0.82em;
                  max-height: 180px; overflow-y: auto; background: #fafafa;
                  border: 1px solid #ddd; border-radius: 4px; padding: 8px; display: none; }
  table.preview { border-collapse: collapse; width: 100%; }
  table.preview th, table.preview td { border: 1px solid #ddd; padding: 4px 8px; text-align: right; }
  table.preview th { background: #f0f0f0; font-weight: 600; }
</style>
</head>
<body>
<div class="container">
  <h1>SovovaMulti</h1>
  <p class="subtitle">Sovová Supercritical Fluid Extraction Model Fitting</p>

  <div class="card">
    <h2>📁 Experimental Data</h2>
    <p style="font-size:0.88em; color:#666; margin-bottom:10px;">
      Upload a data file (text or Excel) with column 1 = time (min) and columns 2…N = replicate m_ext (g).
    </p>
    <div class="form-grid">
      <div class="form-group">
        <label>File type</label>
        <select id="fileType">
          <option value="txt">Text file (.txt, .csv, .dat)</option>
          <option value="xlsx">Excel file (.xlsx)</option>
        </select>
      </div>
      <div class="form-group">
        <label>Upload file</label>
        <div class="file-upload">
          <input type="file" id="dataFile" accept=".txt,.csv,.dat,.xlsx,.xls">
        </div>
      </div>
    </div>
    <div id="dataPreview" class="data-preview"></div>
  </div>

  <div class="card">
    <h2>⚙️ Operating Conditions</h2>
    <div class="form-grid">
      <div class="form-group">
        <label>Temperature <span class="unit">(K)</span></label>
        <input type="number" id="temperature" step="any" value="333.15">
      </div>
      <div class="form-group">
        <label>Porosity <span class="unit">(dimensionless)</span></label>
        <input type="number" id="porosity" step="any" value="0.7">
      </div>
      <div class="form-group">
        <label>x₀ — Total extractable yield <span class="unit">(kg/kg)</span></label>
        <input type="number" id="x0" step="any" value="0.069">
      </div>
      <div class="form-group">
        <label>Solid density <span class="unit">(g/cm³)</span></label>
        <input type="number" id="solid_density" step="any" value="1.32">
      </div>
      <div class="form-group">
        <label>Solvent density <span class="unit">(g/cm³)</span></label>
        <input type="number" id="solvent_density" step="any" value="0.78">
      </div>
      <div class="form-group">
        <label>Flow rate <span class="unit">(cm³/min)</span></label>
        <input type="number" id="flow_rate" step="any" value="9.9">
      </div>
      <div class="form-group">
        <label>Bed height <span class="unit">(cm)</span></label>
        <input type="number" id="bed_height" step="any" value="9.2">
      </div>
      <div class="form-group">
        <label>Bed diameter <span class="unit">(cm)</span></label>
        <input type="number" id="bed_diameter" step="any" value="5.42">
      </div>
      <div class="form-group">
        <label>Particle diameter <span class="unit">(cm)</span></label>
        <input type="number" id="particle_diameter" step="any" value="0.0337">
      </div>
      <div class="form-group">
        <label>Solid mass <span class="unit">(g)</span></label>
        <input type="number" id="solid_mass" step="any" value="100.0">
      </div>
      <div class="form-group">
        <label>Solubility <span class="unit">(kg/kg)</span></label>
        <input type="number" id="solubility" step="any" value="0.003166">
      </div>
      <div class="form-group">
        <label>Viscosity <span class="unit">(mPa·s = cP)</span></label>
        <input type="number" id="viscosity" step="any" value="0.0677">
      </div>
    </div>
  </div>

  <div class="card">
    <h2>🔧 Optimizer Settings</h2>
    <div class="form-grid">
      <div class="form-group">
        <label>Max evaluations</label>
        <input type="number" id="maxevals" step="1" value="50000">
      </div>
      <div class="form-group">
        <label>kya bounds <span class="unit">(min, max)</span></label>
        <div style="display:flex; gap:6px;">
          <input type="number" id="kya_min" step="any" value="0.0" style="width:48%">
          <input type="number" id="kya_max" step="any" value="0.05" style="width:48%">
        </div>
      </div>
      <div class="form-group">
        <label>kxa bounds <span class="unit">(min, max)</span></label>
        <div style="display:flex; gap:6px;">
          <input type="number" id="kxa_min" step="any" value="0.0" style="width:48%">
          <input type="number" id="kxa_max" step="any" value="0.005" style="width:48%">
        </div>
      </div>
      <div class="form-group">
        <label>xk/x0 bounds <span class="unit">(min, max)</span></label>
        <div style="display:flex; gap:6px;">
          <input type="number" id="xk_min" step="any" value="0.0" style="width:48%">
          <input type="number" id="xk_max" step="any" value="1.0" style="width:48%">
        </div>
      </div>
    </div>
  </div>

  <div class="btn-row">
    <button class="btn btn-primary" id="runBtn" onclick="runFit()">Run Fitting</button>
  </div>
  <div id="status"></div>
</div>

<script>
  // Store uploaded data contents
  var uploadedData = null;
  var uploadedFileName = null;

  document.getElementById('dataFile').addEventListener('change', function(e) {
    var file = e.target.files[0];
    if (!file) return;
    uploadedFileName = file.name;
    var reader = new FileReader();
    var ftype = document.getElementById('fileType').value;
    if (ftype === 'xlsx') {
      reader.onload = function(ev) {
        // Send as base64
        var base64 = btoa(new Uint8Array(ev.target.result).reduce(
          function(data, byte) { return data + String.fromCharCode(byte); }, ''));
        uploadedData = {type: 'xlsx', content: base64, name: file.name};
        showPreviewFromJulia();
      };
      reader.readAsArrayBuffer(file);
    } else {
      reader.onload = function(ev) {
        uploadedData = {type: 'txt', content: ev.target.result, name: file.name};
        showPreviewFromJulia();
      };
      reader.readAsText(file);
    }
  });

  function showPreviewFromJulia() {
    Blink.msg('preview', uploadedData, function(result) {
      var div = document.getElementById('dataPreview');
      if (result.error) {
        div.innerHTML = '<span style="color:red;">' + result.error + '</span>';
      } else {
        var html = '<table class="preview"><tr>';
        for (var j = 0; j < result.ncols; j++) {
          html += '<th>' + (j === 0 ? 'time (min)' : 'rep ' + j + ' (g)') + '</th>';
        }
        html += '</tr>';
        var maxRows = Math.min(result.nrows, 10);
        for (var i = 0; i < maxRows; i++) {
          html += '<tr>';
          for (var j = 0; j < result.ncols; j++) {
            html += '<td>' + result.data[i][j] + '</td>';
          }
          html += '</tr>';
        }
        if (result.nrows > 10) {
          html += '<tr><td colspan="' + result.ncols + '" style="text-align:center;color:#999;">… ' +
                  (result.nrows - 10) + ' more rows</td></tr>';
        }
        html += '</table>';
        html += '<p style="margin-top:6px;font-size:0.85em;color:#555;">' +
                result.nrows + ' rows × ' + result.ncols + ' columns (' +
                (result.ncols - 1) + ' replicate' + (result.ncols > 2 ? 's' : '') + ')</p>';
        div.innerHTML = html;
      }
      div.style.display = 'block';
    });
  }

  function runFit() {
    if (!uploadedData) {
      setStatus('error', 'Please upload a data file first.');
      return;
    }
    var params = {
      data: uploadedData,
      temperature: parseFloat(document.getElementById('temperature').value),
      porosity: parseFloat(document.getElementById('porosity').value),
      x0: parseFloat(document.getElementById('x0').value),
      solid_density: parseFloat(document.getElementById('solid_density').value),
      solvent_density: parseFloat(document.getElementById('solvent_density').value),
      flow_rate: parseFloat(document.getElementById('flow_rate').value),
      bed_height: parseFloat(document.getElementById('bed_height').value),
      bed_diameter: parseFloat(document.getElementById('bed_diameter').value),
      particle_diameter: parseFloat(document.getElementById('particle_diameter').value),
      solid_mass: parseFloat(document.getElementById('solid_mass').value),
      solubility: parseFloat(document.getElementById('solubility').value),
      viscosity: parseFloat(document.getElementById('viscosity').value),
      maxevals: parseInt(document.getElementById('maxevals').value),
      kya_bounds: [parseFloat(document.getElementById('kya_min').value),
                   parseFloat(document.getElementById('kya_max').value)],
      kxa_bounds: [parseFloat(document.getElementById('kxa_min').value),
                   parseFloat(document.getElementById('kxa_max').value)],
      xk_bounds:  [parseFloat(document.getElementById('xk_min').value),
                   parseFloat(document.getElementById('xk_max').value)]
    };
    var btn = document.getElementById('runBtn');
    btn.disabled = true;
    btn.textContent = 'Running…';
    setStatus('info', 'Fitting model — this may take a minute…');

    Blink.msg('run', params, function(result) {
      btn.disabled = false;
      btn.textContent = 'Run Fitting';
      if (result.error) {
        setStatus('error', 'Error: ' + result.error);
      } else {
        setStatus('success', result.text);
      }
    });
  }

  function setStatus(cls, msg) {
    var el = document.getElementById('status');
    el.className = cls;
    el.textContent = msg;
  }
</script>
</body>
</html>
"""

function _parse_data_from_gui(info::Dict)
    if info["type"] == "txt"
        content = info["content"]
        io = IOBuffer(content)
        return SovovaMulti.TextTable(io)
    else
        # Excel: decode base64 to temp file
        raw = base64decode(info["content"])
        tmpfile = tempname() * ".xlsx"
        try
            write(tmpfile, raw)
            return SovovaMulti.ExcelTable(tmpfile)
        finally
            rm(tmpfile; force=true)
        end
    end
end

function _format_result(result::SovovaResult)
    io = IOBuffer()
    nexp = length(result.kya)
    println(io, "═══ Fitting Results ═══")
    println(io)
    println(io, "  xk/x0 ratio = ", round(result.xk_ratio; digits=6))
    println(io, "  Objective (SSR) = ", round(result.objective; sigdigits=6))
    println(io)
    for i in 1:nexp
        if nexp > 1
            println(io, "  ── Curve $i ──")
        end
        println(io, "  kya  = ", round(result.kya[i]; sigdigits=6), " 1/s")
        println(io, "  kxa  = ", round(result.kxa[i]; sigdigits=6), " 1/s")
        println(io, "  xk   = ", round(result.xk[i]; sigdigits=6), " kg/kg")
        println(io, "  tCER = ", round(result.tcer[i]; digits=2), " s")
        println(io)
    end
    return String(take!(io))
end

function SovovaMulti.sovovagui()
    w = Window(Dict("title" => "SovovaMulti", "width" => 880, "height" => 920))
    body!(w, GUI_HTML; fade=false)

    # Handle data preview requests
    Blink.handle(w, "preview") do info
        try
            data = _parse_data_from_gui(info)
            nrows, ncols = size(data)
            rows = [data[i, :] for i in 1:min(nrows, 10)]
            return Dict("nrows" => nrows, "ncols" => ncols,
                        "data" => [round.(r; digits=6) for r in rows])
        catch e
            return Dict("error" => sprint(showerror, e))
        end
    end

    # Handle fitting requests
    Blink.handle(w, "run") do params
        try
            data = _parse_data_from_gui(params["data"])

            curve = ExtractionCurve(
                data              = data,
                temperature       = Float64(params["temperature"]),
                porosity          = Float64(params["porosity"]),
                x0                = Float64(params["x0"]),
                solid_density     = Float64(params["solid_density"]),
                solvent_density   = Float64(params["solvent_density"]),
                flow_rate         = Float64(params["flow_rate"]),
                bed_height        = Float64(params["bed_height"]),
                bed_diameter      = Float64(params["bed_diameter"]),
                particle_diameter = Float64(params["particle_diameter"]),
                solid_mass        = Float64(params["solid_mass"]),
                solubility        = Float64(params["solubility"]),
                viscosity         = Float64(params["viscosity"]),
            )

            kya_bounds = Tuple{Float64,Float64}(params["kya_bounds"])
            kxa_bounds = Tuple{Float64,Float64}(params["kxa_bounds"])
            xk_bounds  = Tuple{Float64,Float64}(params["xk_bounds"])
            maxevals   = Int(params["maxevals"])

            result = sovova_multi(curve;
                kya_bounds      = kya_bounds,
                kxa_bounds      = kxa_bounds,
                xk_ratio_bounds = xk_bounds,
                maxevals        = maxevals,
            )

            return Dict("text" => _format_result(result))
        catch e
            return Dict("error" => sprint(showerror, e))
        end
    end

    return w
end

end # module
