// สรุปไฟล์ .jtl ของ JMeter เป็นตัวเลขที่อ่านได้
//   node summarise.js results/baseline.jtl
const fs = require("fs");

const file = process.argv[2];
if (!file) {
  console.error("usage: node summarise.js <results.jtl>");
  process.exit(1);
}

const lines = fs.readFileSync(file, "utf8").trim().split(/\r?\n/);
const header = lines[0].split(",");
const idx = (name) => header.indexOf(name);

const iElapsed = idx("elapsed");
const iLabel = idx("label");
const iSuccess = idx("success");
const iTs = idx("timeStamp");

const byLabel = new Map();
let firstTs = Infinity;
let lastTs = 0;

for (let i = 1; i < lines.length; i++) {
  const c = lines[i].split(",");
  if (c.length < header.length) continue;

  const label = c[iLabel];
  const elapsed = Number(c[iElapsed]);
  const ok = c[iSuccess] === "true";
  const ts = Number(c[iTs]);

  if (ts < firstTs) firstTs = ts;
  if (ts > lastTs) lastTs = ts;

  if (!byLabel.has(label)) byLabel.set(label, { times: [], errors: 0 });
  const bucket = byLabel.get(label);
  bucket.times.push(elapsed);
  if (!ok) bucket.errors++;
}

const pct = (sorted, p) => sorted[Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length))];

const wallSeconds = (lastTs - firstTs) / 1000 || 1;
const rows = [];
let total = 0;
let totalErrors = 0;

for (const [label, { times, errors }] of byLabel) {
  times.sort((a, b) => a - b);
  total += times.length;
  totalErrors += errors;
  rows.push({
    label,
    samples: times.length,
    errPct: ((errors / times.length) * 100).toFixed(2),
    avg: Math.round(times.reduce((a, b) => a + b, 0) / times.length),
    p50: pct(times, 50),
    p95: pct(times, 95),
    p99: pct(times, 99),
    max: times[times.length - 1],
  });
}

const pad = (s, n) => String(s).padEnd(n);
const padL = (s, n) => String(s).padStart(n);

console.log(`\nไฟล์      : ${file}`);
console.log(`ระยะเวลา  : ${wallSeconds.toFixed(1)} วินาที`);
console.log(`throughput: ${(total / wallSeconds).toFixed(1)} req/s`);
console.log(`ทั้งหมด   : ${total} requests, error ${totalErrors} (${((totalErrors / total) * 100).toFixed(2)}%)\n`);

console.log(
  pad("endpoint", 14) + padL("samples", 9) + padL("err%", 7) +
  padL("avg", 7) + padL("p50", 7) + padL("p95", 7) + padL("p99", 7) + padL("max", 7),
);
console.log("-".repeat(65));
for (const r of rows) {
  console.log(
    pad(r.label, 14) + padL(r.samples, 9) + padL(r.errPct, 7) +
    padL(r.avg, 7) + padL(r.p50, 7) + padL(r.p95, 7) + padL(r.p99, 7) + padL(r.max, 7),
  );
}
console.log();
