// P4 - load the sittings exported from PostgreSQL (pg_sittings.jsonl), so IDs and names match P1.
db = db.getSiblingDB("exam_nosql");
const fs = require("fs");
const lines = fs.readFileSync(__dirname + "/../pg_sittings.jsonl", "utf8").split("\n").filter(l => l.length);
let batch = [], total = 0;
for (const l of lines) {
  const d = JSON.parse(l);
  d.slotDate = new Date(d.slotDate + "T00:00:00Z");
  batch.push(d);
  if (batch.length === 5000) { db.sittings.insertMany(batch); total += batch.length; batch = []; }
}
if (batch.length) { db.sittings.insertMany(batch); total += batch.length; }
print("inserted " + total + " documents; countDocuments = " + db.sittings.countDocuments());
printjson(db.sittings.findOne({}, { _id: 0 }));
