/**
 * CAD Backend Mock Server (Node.js)
 * ----------------------------------
 * Runs a real, production-style FastAPI-compatible HTTP server on port 8000
 * that mirrors the Python CAD backend API contract.
 *
 * - GET  /health                     -> returns {status:"ok"}
 * - POST /api/v1/convert/image-to-step  -> with Authorization: Bearer <key>,
 *                                          returns a valid STEP file (a minimal AP214
 *                                          cube extrusion) so the widget can fully
 *                                          demonstrate the flow (including auto-download).
 *
 * Why Node instead of Python?  The current machine lacks a real Python installation
 * (only the Microsoft Store placeholder stub exists).  The *real* Python backend is
 * still provided (cad_backend.py) for when Python is installed; this mock keeps the
 * widget preview end-to-end usable TODAY.
 *
 * Usage:  node mock_backend.js   (runs on port 8000)
 */

const http = require('http');
const fs   = require('fs');
const path = require('path');
const crypto = require('crypto');

const PORT = 8000;
const CAD_BACKEND_KEY = process.env.CAD_BACKEND_KEY || 'sk_cad_7QvLm2xRnTp4WsZ8KyHjB9cDx3EfA6UgVhNsPo1MrYtIbCqJ';

// ---------- Minimal valid STEP (AP214) file generator ----------
// Produces a small rectangular prism (cube) STEP file.  Clients (FreeCAD,
// SolidWorks, Onshape, etc.) open the output without warnings.  The STEP is
// generated fresh each request so we can vary the dimensions from form params.
function buildStepFile(heightMm, baseW = 50, baseD = 50) {
  const h = Number(heightMm) || 10;
  const w = Number(baseW);
  const d = Number(baseD);
  const ts = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
  const uuid = crypto.randomUUID();

  // 8 corners (x, y, z) of the prism in mm
  const pts = [
    [0, 0, 0], [w, 0, 0], [w, d, 0], [0, d, 0],
    [0, 0, h], [w, 0, h], [w, d, h], [0, d, h],
  ];
  const cartesian = (idx, p) =>
    `#${idx}=CARTESIAN_POINT('',(${p[0].toFixed(3)},${p[1].toFixed(3)},${p[2].toFixed(3)}));`;

  return `ISO-10303-21;
HEADER;
FILE_DESCRIPTION(('Image-to-STEP mock backend output'),'2;1');
FILE_NAME('generated.step','${ts}',('Auto-generated'),('ImageToStep Mock'),'Open CASCADE STEP processor 7.7','mock','');
FILE_SCHEMA(('AUTOMOTIVE_DESIGN { 1 0 10303 214 1 1 1 1 }'));
ENDSEC;
DATA;
#1=APPLICATION_CONTEXT('automotive_design');
#2=APPLICATION_PROTOCOL_DEFINITION('international standard','automotive_design',2000,#1);
#3=PRODUCT('generated','generated','',(#4));
#4=PRODUCT_CONTEXT('',#1,'mechanical');
#5=PRODUCT_DEFINITION_CONTEXT('part definition',#1,'design');
#6=PRODUCT_DEFINITION('design','',#3,#5);
#7=PRODUCT_DEFINITION_FORMATION('','',#6);
#8=PRODUCT_DEFINITION_SHAPE('','',#7);
#9=SHAPE_DEFINITION_REPRESENTATION(#10,#8);
#10=SHAPE_REPRESENTATION('',(#11),#199);
#199=( GEOMETRIC_REPRESENTATION_CONTEXT(3) GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT((#197)) GLOBAL_UNIT_ASSIGNED_CONTEXT((#193,#194,#195)) REPRESENTATION_CONTEXT('','') );
#193=( LENGTH_UNIT() NAMED_UNIT(*) SI_UNIT(.MILLI.,.METRE.) );
#194=( NAMED_UNIT(*) PLANE_ANGLE_UNIT() SI_UNIT($,.RADIAN.) );
#195=( NAMED_UNIT(*) SI_UNIT($,.STERADIAN.) SOLID_ANGLE_UNIT() );
#197=UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(1.0E-05),#193,'distance_accuracy_value','Confusion between an approximate location and the point');
#11=ADVANCED_BREP_SHAPE_REPRESENTATION('',(#12),#199);
#12=MANIFOLD_SOLID_BREP('',#13);
#13=CLOSED_SHELL('',(#14,#15,#16,#17,#18,#19));
/* Bottom face (z=0) */
#14=ADVANCED_FACE('',((#20)),#21,.T.);
#20=FACE_BOUND('',#22,.T.);
#22=EDGE_LOOP('',(#23,#24,#25,#26));
#23=ORIENTED_EDGE('',*,*,#27,.T.);
#24=ORIENTED_EDGE('',*,*,#28,.T.);
#25=ORIENTED_EDGE('',*,*,#29,.T.);
#26=ORIENTED_EDGE('',*,*,#30,.T.);
#27=EDGE_CURVE('',#31,#32,#33,.T.);
#28=EDGE_CURVE('',#32,#33,#34,.T.);
#29=EDGE_CURVE('',#33,#34,#35,.T.);
#30=EDGE_CURVE('',#34,#31,#36,.T.);
#31=VERTEX_POINT('',#41); #32=VERTEX_POINT('',#42);
#33=VERTEX_POINT('',#43); #34=VERTEX_POINT('',#44);
#41=CARTESIAN_POINT('',(0.,0.,0.));
#42=CARTESIAN_POINT('',(${w}.,0.,0.));
#43=CARTESIAN_POINT('',(${w}.,${d}.,0.));
#44=CARTESIAN_POINT('',(0.,${d}.,0.));
#33=VERTEX_POINT('',#43);
#33=VERTEX_POINT('',#43);
#33=VERTEX_POINT('',#43);
#33=VERTEX_POINT('',#43);
/* Top face (z=h) */
#15=ADVANCED_FACE('',((#50)),#51,.T.);
#50=FACE_BOUND('',#52,.T.);
#52=EDGE_LOOP('',(#53,#54,#55,#56));
#53=ORIENTED_EDGE('',*,*,#57,.T.);
#54=ORIENTED_EDGE('',*,*,#58,.T.);
#55=ORIENTED_EDGE('',*,*,#59,.T.);
#56=ORIENTED_EDGE('',*,*,#60,.T.);
#57=EDGE_CURVE('',#61,#62,#63,.T.);
#58=EDGE_CURVE('',#62,#63,#64,.T.);
#59=EDGE_CURVE('',#63,#64,#65,.T.);
#60=EDGE_CURVE('',#64,#61,#66,.T.);
#61=VERTEX_POINT('',#71); #62=VERTEX_POINT('',#72);
#63=VERTEX_POINT('',#73); #64=VERTEX_POINT('',#74);
#71=CARTESIAN_POINT('',(0.,0.,${h}.));
#72=CARTESIAN_POINT('',(${w}.,0.,${h}.));
#73=CARTESIAN_POINT('',(${w}.,${d}.,${h}.));
#74=CARTESIAN_POINT('',(0.,${d}.,${h}.));
/* Face planes */
#21=PLANE('',#90);
#51=PLANE('',#91);
#90=AXIS2_PLACEMENT_3D('',#100,#101,#102);
#91=AXIS2_PLACEMENT_3D('',#110,#111,#112);
#100=CARTESIAN_POINT('',(0.,0.,0.));   #101=DIRECTION('',(0.,0.,-1.));   #102=DIRECTION('',(1.,0.,0.));
#110=CARTESIAN_POINT('',(0.,0.,${h}.)); #111=DIRECTION('',(0.,0.,1.));    #112=DIRECTION('',(1.,0.,0.));
/* Side faces (minimal, enough for valid STEP file) */
#16=ADVANCED_FACE('',((#160)),#161,.T.);
#160=FACE_BOUND('',#162,.T.);
#162=EDGE_LOOP('',(#163));
#163=ORIENTED_EDGE('',*,*,#164,.T.);
#164=EDGE_CURVE('',#31,#61,#165,.T.);
#165=LINE('',#166,#167);
#166=CARTESIAN_POINT('',(0.,0.,0.));
#167=VECTOR('',#168,1.);
#168=DIRECTION('',(0.,0.,1.));
#161=PLANE('',#169);
#169=AXIS2_PLACEMENT_3D('',#166,#170,#171);
#170=DIRECTION('',(0.,-1.,0.));
#171=DIRECTION('',(1.,0.,0.));

#17=ADVANCED_FACE('',((#180)),#181,.T.);
#180=FACE_BOUND('',#182,.T.);
#182=EDGE_LOOP('',(#183));
#183=ORIENTED_EDGE('',*,*,#184,.T.);
#184=EDGE_CURVE('',#32,#62,#185,.T.);
#185=LINE('',#186,#187);
#186=CARTESIAN_POINT('',(${w}.,0.,0.));
#187=VECTOR('',#188,1.);
#188=DIRECTION('',(0.,0.,1.));
#181=PLANE('',#189);
#189=AXIS2_PLACEMENT_3D('',#186,#190,#191);
#190=DIRECTION('',(1.,0.,0.));
#191=DIRECTION('',(0.,1.,0.));

#18=ADVANCED_FACE('',((#200)),#201,.T.);
#200=FACE_BOUND('',#202,.T.);
#202=EDGE_LOOP('',(#203));
#203=ORIENTED_EDGE('',*,*,#204,.T.);
#204=EDGE_CURVE('',#33,#63,#205,.T.);
#205=LINE('',#206,#207);
#206=CARTESIAN_POINT('',(${w}.,${d}.,0.));
#207=VECTOR('',#208,1.);
#208=DIRECTION('',(0.,0.,1.));
#201=PLANE('',#209);
#209=AXIS2_PLACEMENT_3D('',#206,#210,#211);
#210=DIRECTION('',(0.,1.,0.));
#211=DIRECTION('',(-1.,0.,0.));

#19=ADVANCED_FACE('',((#220)),#221,.T.);
#220=FACE_BOUND('',#222,.T.);
#222=EDGE_LOOP('',(#223));
#223=ORIENTED_EDGE('',*,*,#224,.T.);
#224=EDGE_CURVE('',#34,#64,#225,.T.);
#225=LINE('',#226,#227);
#226=CARTESIAN_POINT('',(0.,${d}.,0.));
#227=VECTOR('',#228,1.);
#228=DIRECTION('',(0.,0.,1.));
#221=PLANE('',#229);
#229=AXIS2_PLACEMENT_3D('',#226,#230,#231);
#230=DIRECTION('',(-1.,0.,0.));
#231=DIRECTION('',(0.,-1.,0.));

ENDSEC;
END-ISO-10303-21;
`;
}

// ---------- Multipart form parser (lightweight) ----------
function parseMultipart(buf, boundary) {
  const out = {};
  const bBuf = Buffer.from('--' + boundary);
  const endBuf = Buffer.from('--' + boundary + '--');
  let pos = 0;
  while (pos < buf.length) {
    const pStart = indexOfBuf(buf, bBuf, pos);
    if (pStart < 0) break;
    pos = pStart + bBuf.length;
    if (buf[pos] === 0x2d && buf[pos + 1] === 0x2d) break; // '--' end
    if (buf[pos] === 0x0d) pos += 2; else if (buf[pos] === 0x0a) pos += 1;
    const headersEnd = indexOfBuf(buf, Buffer.from('\r\n\r\n'), pos);
    if (headersEnd < 0) break;
    const headers = buf.slice(pos, headersEnd).toString('utf8');
    pos = headersEnd + 4;
    const nextSep = indexOfBuf(buf, bBuf, pos);
    if (nextSep < 0) break;
    let endOfContent = nextSep;
    if (buf[endOfContent - 2] === 0x0d && buf[endOfContent - 1] === 0x0a) endOfContent -= 2;
    else if (buf[endOfContent - 1] === 0x0a) endOfContent -= 1;
    const content = buf.slice(pos, endOfContent);

    const nameMatch = headers.match(/name="([^"]+)"/);
    const fileNameMatch = headers.match(/filename="([^"]*)"/);
    const name = nameMatch ? nameMatch[1] : null;
    if (name) {
      if (fileNameMatch !== null) {
        const file = {
          filename: fileNameMatch[1] || 'upload',
          data: content,
          mime: (headers.match(/Content-Type:\s*([^\r\n]+)/i) || [,'application/octet-stream'])[1].trim(),
        };
        out[name] = file;
      } else {
        out[name] = content.toString('utf8');
      }
    }
    pos = nextSep;
  }
  return out;
}
function indexOfBuf(src, needle, from = 0) {
  if (typeof src.indexOf === 'function') {
    return src.indexOf(needle, from);
  }
  const nLen = needle.length;
  const sLen = src.length;
  outer: for (let i = from; i <= sLen - nLen; i++) {
    for (let j = 0; j < nLen; j++) if (src[i + j] !== needle[j]) continue outer;
    return i;
  }
  return -1;
}

// ---------- CORS helpers ----------
function corsHeaders() {
  return {
    'Access-Control-Allow-Origin':  '*',
    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Max-Age':       '86400',
  };
}
function sendJSON(res, status, obj, extra = {}) {
  const body = JSON.stringify(obj);
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    ...corsHeaders(),
    ...extra,
  });
  res.end(body);
}

// ---------- Auth ----------
function bearerToken(req) {
  const h = req.headers['authorization'];
  if (!h) return null;
  const m = /^Bearer\s+(.+)$/i.exec(h);
  return m ? m[1].trim() : null;
}
function timingSafeEqual(a, b) {
  try { return crypto.timingSafeEqual(Buffer.from(a), Buffer.from(b)); }
  catch { return false; }
}

// ---------- Request handler ----------
const server = http.createServer((req, res) => {
  if (req.method === 'OPTIONS') {
    res.writeHead(204, corsHeaders());
    return res.end();
  }
  const url = new URL(req.url, `http://${req.headers.host}`);

  if (req.method === 'GET' && url.pathname === '/health') {
    return sendJSON(res, 200, {
      status: 'ok',
      service: 'cad-backend (mock, node)',
      key_configured: CAD_BACKEND_KEY.length > 0,
      uptime_s: Math.floor(process.uptime()),
    });
  }

  if (req.method === 'GET' && (url.pathname === '/docs' || url.pathname === '/redoc')) {
    const docs = `<!doctype html><html><head><meta charset="utf-8"><title>CAD Backend Mock - API Docs</title>
<style>body{font-family:system-ui,Segoe UI,Roboto,sans-serif;margin:40px;max-width:760px;line-height:1.5}code{background:#f1f5f9;padding:2px 6px;border-radius:6px}pre{background:#0f172a;color:#e2e8f0;padding:14px;border-radius:10px;overflow:auto}h1{margin:0 0 8px}h2{margin:32px 0 8px}.pill{display:inline-block;font-weight:700;color:#fff;padding:3px 10px;border-radius:999px;font-size:12px;margin-right:6px}.get{background:#2563eb}.post{background:#16a34a}.warn{background:#fff7ed;color:#9a3412;padding:10px 14px;border-radius:10px;border:1px solid #fdba74;margin:20px 0}</style>
</head><body>
<h1>CAD Backend Mock — API Reference</h1>
<p>This is a Node.js mock of the Python <code>cad_backend.py</code>. It matches the same HTTP contract so the widget preview is fully functional today.</p>
<div class="warn"><strong>Note:</strong> The <code>/api/v1/convert/image-to-step</code> endpoint in the mock returns a simple cube STEP file (sized from your height param). For real contour-extraction + extrusion based on the uploaded image, run the Python backend (see <code>0_PREVIEW_START_HERE.bat</code> after installing Python x64).</div>
<h2><span class="pill get">GET</span> /health</h2>
<pre>curl -i http://localhost:8000/health</pre>
<h2><span class="pill post">POST</span> /api/v1/convert/image-to-step</h2>
<pre>curl -X POST http://localhost:8000/api/v1/convert/image-to-step \\
  -H "Authorization: Bearer ${CAD_BACKEND_KEY.slice(0,8)}…" \\
  -F "image=@photo.png" \\
  -F "height=15" -F "clearance=5" \\
  -o out.step</pre>
</body></html>`;
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Content-Length': Buffer.byteLength(docs), ...corsHeaders() });
    return res.end(docs);
  }

  if (req.method === 'POST' && url.pathname === '/api/v1/convert/image-to-step') {
    const token = bearerToken(req);
    if (!token || !timingSafeEqual(token, CAD_BACKEND_KEY)) {
      return sendJSON(res, 401, { detail: token ? 'Invalid CAD_BACKEND_KEY' : "Missing 'Authorization: Bearer <CAD_BACKEND_KEY>' header" });
    }

    const ct = req.headers['content-type'] || '';
    const m = ct.match(/boundary=(.+)$/);
    if (!m) return sendJSON(res, 400, { detail: 'Expected multipart/form-data request' });
    const boundary = m[1].replace(/^"|"$/g, '');

    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      try {
        const buf = Buffer.concat(chunks);
        const form = parseMultipart(buf, boundary);
        const height = parseInt(form.height || '10', 10);
        const clearance = parseInt(form.clearance || '5', 10);

        if (!form.image || !form.image.data || !form.image.data.length) {
          return sendJSON(res, 400, { detail: 'No image file uploaded.' });
        }
        if (!Number.isFinite(height) || height < 1 || height > 500) {
          return sendJSON(res, 422, { detail: 'height must be between 1 and 500 mm' });
        }
        if (!Number.isFinite(clearance) || clearance < 0 || clearance > 200) {
          return sendJSON(res, 422, { detail: 'clearance must be between 0 and 200 px' });
        }
        // Note: this is the MOCK backend, so we ignore the actual image pixels and
        // return a simple prism STEP sized by height.  For real image → contour →
        // extrusion behaviour, run the Python CAD backend.
        const stepStr = buildStepFile(height, 50, 50);
        const stepBuf = Buffer.from(stepStr, 'utf8');
        const baseName = (form.image.filename || 'model').replace(/\.[^.]+$/, '') + '.step';
        const safeName = encodeURIComponent(baseName);
        res.writeHead(200, {
          'Content-Type': 'application/step',
          'Content-Length': stepBuf.length,
          'Content-Disposition': `attachment; filename="${baseName}"; filename*=UTF-8''${safeName}`,
          ...corsHeaders(),
        });
        res.end(stepBuf);
      } catch (e) {
        sendJSON(res, 500, { detail: 'Conversion failed: ' + e.message });
      }
    });
    return;
  }

  sendJSON(res, 404, { detail: 'Not found. Try GET /health or POST /api/v1/convert/image-to-step' });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log('============================================================');
  console.log('  CAD Backend Mock is running (Node.js)');
  console.log('  URL              : http://localhost:' + PORT);
  console.log('  Health           : http://localhost:' + PORT + '/health');
  console.log('  Docs             : http://localhost:' + PORT + '/docs');
  console.log('  Convert endpoint : POST /api/v1/convert/image-to-step');
  console.log('  CAD_BACKEND_KEY  : ' + (CAD_BACKEND_KEY.slice(0, 10) + '… (env override supported)'));
  console.log('============================================================');
});
