// P4 - create the 'sittings' collection with a $jsonSchema validator.
// One document = one exam sitting (student + course + slot + hall + seat embedded together).
db = db.getSiblingDB("exam_nosql");
db.sittings.drop();
db.createCollection("sittings", {
  validator: { $jsonSchema: {
    bsonType: "object",
    additionalProperties: false,
    required: ["_id","seatingId","matric","studentName","department","level","courseCode","courseTitle",
               "examMode","semester","slotDate","period","hall","seatCode","status"],
    properties: {
      _id:         { bsonType: "objectId" },
      seatingId:   { bsonType: ["int","long"] },
      matric:      { bsonType: "string", pattern: "^EX/[0-9]{5}$" },
      studentName: { bsonType: "string" },
      department:  { bsonType: "string" },
      level:       { enum: [100,200,300,400] },
      needsAccessible: { bsonType: "bool" },
      courseCode:  { bsonType: "string", pattern: "^[A-Z]{3} [0-9]{3}$" },
      courseTitle: { bsonType: "string" },
      examMode:    { enum: ["CBT","PAPER"] },
      semester:    { bsonType: "string", pattern: "^[0-9]{4}/[0-9]{4}-S[12]$" },
      slotDate:    { bsonType: "date" },
      period:      { enum: ["MORNING","AFTERNOON"] },
      hall:        { bsonType: "string" },
      seatCode:    { bsonType: "string" },
      status:      { enum: ["ASSIGNED","SAT","ABSENT","CANCELLED"] }
    }
  } },
  validationAction: "error"
});
print("collection created with validator");

// two BAD documents - both must be rejected by the validator
const bad = [
  { seatingId: 1, matric: "WRONG", studentName: "Test", department: "X", level: 100, courseCode: "CSC 101",
    courseTitle: "T", examMode: "CBT", semester: "2026/2027-S1", slotDate: new Date(), period: "MORNING",
    hall: "H", seatCode: "S001", status: "SAT" },
  { seatingId: 2, matric: "EX/00001", studentName: "Test", department: "X", level: 100, courseCode: "CSC 101",
    courseTitle: "T", examMode: "CBT", semester: "2026/2027-S1", slotDate: new Date(), period: "MORNING",
    hall: "H", seatCode: "S001", status: "PRESENT" }
];
bad.forEach((d, i) => {
  try { db.sittings.insertOne(d); print("BAD DOC " + (i+1) + ": FAIL - it was accepted!"); }
  catch (e) { print("BAD DOC " + (i+1) + ": PASS - rejected (code " + e.code + ")"); }
});
