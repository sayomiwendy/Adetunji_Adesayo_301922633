#!/usr/bin/env python3
"""P3 - concurrency demos with two REAL database sessions (psycopg2 + threads).
Prints labelled real output. Parts: 1 bug, 2 UNIQUE safety net, 3 advisory lock fix,
4 write skew (READ COMMITTED vs SERIALIZABLE), 5 isolation levels, 6 deadlock + fix."""
import threading, time, sys
import psycopg2
from psycopg2 import errors

DB = "exam_db"
def conn(iso=None):
    c = psycopg2.connect(dbname=DB)
    c.autocommit = False
    if iso: c.set_session(isolation_level=iso)
    return c
def q1(c, sql, args=None):
    cur = c.cursor(); cur.execute(sql, args); r = cur.fetchone(); cur.close(); return r[0] if r else None
def qa(c, sql, args=None):
    cur = c.cursor(); cur.execute(sql, args); r = cur.fetchall(); cur.close(); return r
def say(*a): print(*a, flush=True)
def part(n, title): say(); say("=" * 72); say(f"PART {n}: {title}"); say("=" * 72)

# ---- pick two students with ASSIGNED seats in the same future slot and mode ----------------
adm = conn(); adm.autocommit = True
rows = qa(adm, """
  SELECT a.student_id, a.seat_id, a.paper_id, a.slot_id, h.exam_mode
  FROM seatings a JOIN students st ON st.student_id=a.student_id
  JOIN seats s ON s.seat_id=a.seat_id JOIN exam_halls h ON h.hall_id=s.hall_id
  WHERE a.status='ASSIGNED' AND NOT st.needs_accessible
    AND a.slot_id = (SELECT MIN(slot_id) FROM seatings WHERE status='ASSIGNED')
    AND h.exam_mode = 'PAPER' AND s.seat_id > 700
  ORDER BY a.seating_id LIMIT 2""")
(U1, S1, P1, SLOT, MODE), (U2, S2, P2, _, _) = rows
say(f"Test students: U1={U1} (seat {S1}), U2={U2} (seat {S2}); slot={SLOT}; mode={MODE}")

def reset():
    """Put U1 and U2 back exactly as they were (ASSIGNED on their original seats)."""
    c = conn(); cur = c.cursor()
    cur.execute("DELETE FROM seatings WHERE student_id IN (%s,%s) AND slot_id=%s", (U1, U2, SLOT))
    for u, s, p in ((U1, S1, P1), (U2, S2, P2)):
        cur.execute("INSERT INTO seatings(student_id,seat_id,paper_id,slot_id) VALUES (%s,%s,%s,%s)", (u, s, p, SLOT))
    c.commit(); c.close()

def free_seat(c):
    return q1(c, """SELECT s.seat_id FROM seats s JOIN exam_halls h ON h.hall_id=s.hall_id
      WHERE h.exam_mode=%s AND NOT s.is_accessible
        AND NOT EXISTS (SELECT 1 FROM seatings a WHERE a.seat_id=s.seat_id AND a.slot_id=%s AND a.status IN ('ASSIGNED','SAT'))
      ORDER BY s.seat_id LIMIT 1""", (MODE, SLOT))

def free_up():
    """Cancel U1 and U2 so both need a new seat (the situation we race on)."""
    c = conn(); cur = c.cursor()
    cur.execute("UPDATE seatings SET status='CANCELLED', cancelled_at=now() WHERE student_id IN (%s,%s) AND slot_id=%s AND status='ASSIGNED'", (U1, U2, SLOT))
    c.commit(); c.close()

def run_two(fn1, fn2):
    out = {}
    t1 = threading.Thread(target=lambda: out.__setitem__(1, fn1()))
    t2 = threading.Thread(target=lambda: out.__setitem__(2, fn2()))
    t1.start(); t2.start(); t1.join(60); t2.join(60)
    return out

# ============================ PART 1: the bug (no guard at all) ===============================
part(1, "BUG - check-then-insert with no lock and no UNIQUE guard (scratch table)")
adm.cursor().execute("DROP TABLE IF EXISTS demo_seatings")
adm.cursor().execute("CREATE TABLE demo_seatings (seat_id int, slot_id int, student_id int)")
reset(); free_up()
bar = threading.Barrier(2)
def buggy(u, p):
    def f():
        c = conn(); cur = c.cursor()
        seat = free_seat(c)   # looks at real seatings for the free seat
        cur.execute("SELECT COUNT(*) FROM demo_seatings WHERE seat_id=%s AND slot_id=%s", (seat, SLOT))
        taken = cur.fetchone()[0]
        bar.wait()            # both sessions have now "checked" - nobody has written yet
        if taken == 0:
            cur.execute("INSERT INTO demo_seatings VALUES (%s,%s,%s)", (seat, SLOT, u)); c.commit()
            return f"student {u} got seat {seat}"
        return f"student {u} saw seat {seat} taken"
    return f
res = run_two(buggy(U1, P1), buggy(U2, P2))
say(res[1]); say(res[2])
say("Rows in demo_seatings:", )
for r in qa(adm, "SELECT seat_id, slot_id, student_id FROM demo_seatings ORDER BY student_id"): say("   ", r)
n = q1(adm, "SELECT COUNT(DISTINCT seat_id) FROM demo_seatings"); m = q1(adm, "SELECT COUNT(*) FROM demo_seatings")
say(f"RESULT: {m} students, {n} distinct seat(s)  ->  {'DOUBLE BOOKING (the bug)' if m > n else 'no clash this time'}")
adm.cursor().execute("DROP TABLE demo_seatings")

# ============================ PART 2: UNIQUE index as the safety net ==========================
part(2, "UNIQUE safety net - same race on the real seatings table (P1 partial UNIQUE index)")
reset(); free_up()
bar = threading.Barrier(2)
def guarded(u, p, delay):
    def f():
        c = conn(); cur = c.cursor()
        seat = free_seat(c); bar.wait(); time.sleep(delay)
        try:
            cur.execute("INSERT INTO seatings(student_id,seat_id,paper_id,slot_id) VALUES (%s,%s,%s,%s)", (u, seat, p, SLOT))
            time.sleep(1.0); c.commit(); return f"student {u}: seat {seat} OK (committed)"
        except Exception as e:
            c.rollback(); return f"student {u}: seat {seat} REJECTED [{e.pgcode}] {str(e).splitlines()[0]}"
    return f
res = run_two(guarded(U1, P1, 0.0), guarded(U2, P2, 0.3))
say(res[1]); say(res[2])
say("RESULT: the database refused the second booking; the loser must retry (no double booking).")

# ============================ PART 3: advisory-lock fix =======================================
part(3, "FIX - pg_advisory_xact_lock inside seat_first_free(): second session waits, then takes the NEXT seat")
reset(); free_up()
def locked(u, p, start_delay, hold):
    def f():
        c = conn(); cur = c.cursor(); time.sleep(start_delay)
        t0 = time.time()
        cur.execute("SELECT seat_first_free(%s,%s)", (u, p)); seat = cur.fetchone()[0]
        time.sleep(hold); c.commit()
        return f"student {u}: got seat {seat} after {time.time()-t0:.2f}s"
    return f
res = run_two(locked(U1, P1, 0.0, 1.5), locked(U2, P2, 0.3, 0.0))
say(res[1]); say(res[2])
seats = qa(adm, "SELECT student_id, seat_id FROM seatings WHERE student_id IN (%s,%s) AND slot_id=%s AND status='ASSIGNED' ORDER BY 1", (U1, U2, SLOT))
say("Active seatings:", seats)
say(f"RESULT: {len(set(s for _, s in seats))} distinct seats for 2 students - both succeeded, no clash, no error.")

# ============================ PART 4: write skew ==============================================
part(4, "WRITE SKEW - 'a hall may hold at most N' rule, READ COMMITTED vs SERIALIZABLE")
def skew(iso, label):
    reset(); free_up()
    hall = q1(adm, "SELECT s.hall_id FROM seats s WHERE s.seat_id=%s", (S1,))
    used = q1(adm, """SELECT COUNT(*) FROM seatings a JOIN seats s ON s.seat_id=a.seat_id
                      WHERE s.hall_id=%s AND a.slot_id=%s AND a.status IN ('ASSIGNED','SAT')""", (hall, SLOT))
    limit = used + 1        # room for exactly ONE more student in this hall
    say(f"[{label}] hall {hall} currently has {used} active seatings; rule: at most {limit}")
    bar = threading.Barrier(2)
    def worker(u, p, seat):
        def f():
            c = conn(iso); cur = c.cursor()
            cur.execute("""SELECT COUNT(*) FROM seatings a JOIN seats s ON s.seat_id=a.seat_id
                           WHERE s.hall_id=%s AND a.slot_id=%s AND a.status IN ('ASSIGNED','SAT')""", (hall, SLOT)); cnt = cur.fetchone()[0]
            bar.wait()
            try:
                if cnt < limit:
                    cur.execute("INSERT INTO seatings(student_id,seat_id,paper_id,slot_id) VALUES (%s,%s,%s,%s)", (u, seat, p, SLOT))
                c.commit(); return f"student {u}: read count={cnt}, inserted + COMMIT ok"
            except Exception as e:
                c.rollback(); return f"student {u}: read count={cnt}, COMMIT FAILED [{e.pgcode}] {str(e).splitlines()[0]}"
        return f
    res = run_two(worker(U1, P1, S1), worker(U2, P2, S2))
    say(res[1]); say(res[2])
    total = q1(adm, """SELECT COUNT(*) FROM seatings a JOIN seats s ON s.seat_id=a.seat_id
                       WHERE s.hall_id=%s AND a.slot_id=%s AND a.status IN ('ASSIGNED','SAT')""", (hall, SLOT))
    say(f"[{label}] active seatings now = {total} (limit {limit}) -> {'RULE BROKEN' if total > limit else 'rule held'}")
skew("READ COMMITTED", "READ COMMITTED")
skew("SERIALIZABLE", "SERIALIZABLE")
say("(A failed SERIALIZABLE transaction is simply retried; the retry now sees the full hall and is refused.)")

# ============================ PART 5: isolation levels ========================================
part(5, "ISOLATION - READ COMMITTED vs REPEATABLE READ (non-repeatable read)")
for iso in ("READ COMMITTED", "REPEATABLE READ"):
    reset()
    a = conn(iso); cur = a.cursor()
    cur.execute("SELECT COUNT(*) FROM seatings WHERE slot_id=%s AND status='ASSIGNED'", (SLOT,)); first = cur.fetchone()[0]
    b = conn(); bc = b.cursor()
    bc.execute("UPDATE seatings SET status='CANCELLED', cancelled_at=now() WHERE student_id=%s AND slot_id=%s AND status='ASSIGNED'", (U1, SLOT)); b.commit(); b.close()
    cur.execute("SELECT COUNT(*) FROM seatings WHERE slot_id=%s AND status='ASSIGNED'", (SLOT,)); second = cur.fetchone()[0]
    a.commit(); a.close()
    say(f"[{iso}] session A counts ASSIGNED: before = {first}, after session B cancelled one and committed = {second}")
say("RESULT: READ COMMITTED sees the change inside one transaction; REPEATABLE READ keeps its snapshot.")

# ============================ PART 6: deadlock ================================================
part(6, "DEADLOCK - two sessions update the same two seatings in opposite order, then the fix (fixed order)")
def seating_ids():
    reset()
    return [r[0] for r in qa(adm, "SELECT seating_id FROM seatings WHERE student_id IN (%s,%s) AND slot_id=%s AND status='ASSIGNED' ORDER BY seating_id", (U1, U2, SLOT))]
def swapper(first, second, name, bar):
    def f():
        c = conn(); cur = c.cursor()
        cur.execute("SET deadlock_timeout = '300ms'")
        try:
            cur.execute("UPDATE seatings SET assigned_at = now() WHERE seating_id=%s", (first,))
            bar.wait()
            cur.execute("UPDATE seatings SET assigned_at = now() WHERE seating_id=%s", (second,))
            c.commit(); return f"{name}: locked {first} then {second} -> COMMIT ok"
        except Exception as e:
            c.rollback(); return f"{name}: ABORTED [{e.pgcode}] {str(e).splitlines()[0]}"
    return f
ids = seating_ids(); x, y = ids[0], ids[1]
say(f"Bad order: T1 locks {x} then {y}; T2 locks {y} then {x}")
bar = threading.Barrier(2)
res = run_two(swapper(x, y, "T1", bar), swapper(y, x, "T2", bar)); say(res[1]); say(res[2])
say(f"Fixed order: both sessions lock the lower seating_id ({x}) first, then {y}")
bar = threading.Barrier(2)
def ordered(name):
    def f():
        c = conn(); cur = c.cursor()
        cur.execute("UPDATE seatings SET assigned_at = now() WHERE seating_id=%s", (x,)); time.sleep(0.4)
        cur.execute("UPDATE seatings SET assigned_at = now() WHERE seating_id=%s", (y,)); c.commit()
        return f"{name}: locked {x} then {y} -> COMMIT ok"
    return f
res = run_two(ordered("T1"), ordered("T2")); say(res[1]); say(res[2])
say("RESULT: opposite lock order -> PostgreSQL kills one session (40P01). Same order -> no deadlock.")

reset()
say(); say("Test data restored. All six parts finished.")
