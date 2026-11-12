// P4 - three aggregation pipelines
db = db.getSiblingDB("exam_nosql");
print("--- A1: attendance rate by department (SAT vs ABSENT) ---");
db.sittings.aggregate([
  { $match: { status: { $in: ["SAT","ABSENT"] } } },
  { $group: { _id: "$department", sat: { $sum: { $cond: [{ $eq: ["$status","SAT"] },1,0] } }, total: { $sum: 1 } } },
  { $project: { _id: 1, total: 1, attendancePct: { $round: [{ $multiply: [{ $divide: ["$sat","$total"] },100] },2] } } },
  { $sort: { _id: 1 } }
]).forEach(printjson);

print("--- A2: sittings per hall per exam mode ---");
db.sittings.aggregate([
  { $group: { _id: { hall: "$hall", mode: "$examMode" }, sittings: { $sum: 1 } } },
  { $sort: { sittings: -1 } }
]).forEach(printjson);

print("--- A3: top 5 courses by absentees ---");
db.sittings.aggregate([
  { $match: { status: "ABSENT" } },
  { $group: { _id: { code: "$courseCode", title: "$courseTitle" }, absent: { $sum: 1 } } },
  { $sort: { absent: -1, "_id.code": 1 } },
  { $limit: 5 }
]).forEach(printjson);
