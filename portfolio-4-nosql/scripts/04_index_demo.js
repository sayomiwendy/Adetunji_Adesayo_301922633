// P4 - COLLSCAN -> IXSCAN demo with real executionStats. Safe to re-run (drops each index first).
db = db.getSiblingDB("exam_nosql");
function stages(node, acc) {            // collect stage names anywhere in the plan tree
  if (!node) return acc;
  if (node.stage) acc.push(node.stage);
  if (node.inputStage) stages(node.inputStage, acc);
  (node.inputStages || []).forEach(n => stages(n, acc));
  return acc;
}
function run(label, query) {
  const e = db.sittings.find(query).explain("executionStats").executionStats;
  const st = stages(e.executionStages, []);
  const scan = st.includes("COLLSCAN") ? "COLLSCAN" : (st.includes("IXSCAN") ? "IXSCAN" : st.join(">"));
  return { label, stage: scan, docsExamined: e.totalDocsExamined, returned: e.nReturned, ms: e.executionTimeMillis };
}
const target = db.sittings.findOne({ status: "ABSENT" });          // pick a real target dynamically
const tests = [
  { name: "student lookup",       q: { matric: target.matric },                                    idx: { matric: 1 } },
  { name: "course absentees",     q: { courseCode: target.courseCode, status: "ABSENT" },         idx: { courseCode: 1, status: 1 } },
  { name: "hall + semester + period", q: { hall: target.hall, semester: target.semester, period: target.period }, idx: { hall: 1, semester: 1, period: 1 } }
];
const rows = [];
tests.forEach(t => {
  try { db.sittings.dropIndexes(); } catch (e) { /* nothing to drop */ }
  const before = run(t.name + " BEFORE", t.q);
  db.sittings.createIndex(t.idx);
  const after = run(t.name + " AFTER", t.q);
  rows.push(before, after);
  try { db.sittings.dropIndex(Object.keys(t.idx).map(k => k + "_1").join("_")); } catch (e) { /* ok */ }
});
print("Label | Stage | Docs examined | Returned | Time ms");
rows.forEach(r => print([r.label, r.stage, r.docsExamined, r.returned, r.ms].join(" | ")));
print("documents in collection: " + db.sittings.countDocuments());
