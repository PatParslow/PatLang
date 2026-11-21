"""The crash-safe worker of showcase/p14_crash_safe_worker.patlang, in Python.

Python's standard library has a good durable store for this: sqlite3, a
table of jobs with a status, committed after each change. A job's failure is
an exception, caught around the job. That keeps a failing job from stopping
the worker, but the job still runs in the worker's process, with its memory
and files; a PatLang world gives the job facts, files and output of its own.
A job that must not touch the worker at all is, in Python, a subprocess.

Where the PatLang program says a job failed in its world, this one names the
exception; its expected output is
showcase/compare/expected/p14_crash_safe_worker.txt.
"""
import os
import sqlite3
import tempfile
from fractions import Fraction

PATH = os.path.join(tempfile.gettempdir(), "showcase_p14_jobs.sqlite")


def connect():
    db = sqlite3.connect(PATH)
    db.execute("create table if not exists jobs (id integer primary key, topic text, payload text, status text)")
    return db


def show(x):
    return str(x.numerator) if isinstance(x, Fraction) and x.denominator == 1 else str(x)


def run_job(job):
    kind, _, arg = job.partition(" ")
    if kind == "sum":
        n = int(arg)
        return Fraction(n * (n + 1), 2)
    if kind == "divide":
        d = int(arg)
        assert d != 0
        return Fraction(100, d)
    if kind == "shout":
        return arg + "!"
    raise ValueError(job)


def pending(db, topic):
    return db.execute("select id, payload from jobs where topic = ? and status = 'pending' order by id", (topic,)).fetchall()


def work(db, topic, crash_at, label):
    done = 0
    while True:
        rows = pending(db, topic)
        if not rows:
            return done
        job_id, job = rows[0]
        if done == crash_at:
            print(f"  {label}: took job {job_id - 1} ({job}) and stopped before finishing it")
            return done
        try:
            result = run_job(job)
        except AssertionError:
            print(f"  {label}: job {job_id - 1} ({job}) failed (AssertionError)")
            db.execute("insert into jobs (topic, payload, status) values (?, ?, 'pending')", (topic + "_failed", job))
            db.execute("update jobs set status = 'done' where id = ?", (job_id,))
        else:
            print(f"  {label}: job {job_id - 1} ({job}) gave {show(result)}")
            db.execute("update jobs set status = 'done' where id = ?", (job_id,))
        db.commit()
        done += 1


if os.path.exists(PATH):
    os.remove(PATH)
topic = "showcase_p14_jobs"
db = connect()
for job in ["sum 100", "shout hello", "divide 0", "divide 8", "sum 10"]:
    db.execute("insert into jobs (topic, payload, status) values (?, ?, 'pending')", (topic, job))
db.commit()

print("== the first worker, which dies during its third job ==")
work(db, topic, 2, "first worker")
db.close()
db = connect()  # a new worker: only what was committed is there
print(f"  still pending on disk: {len(pending(db, topic))}")
print("== the next worker picks up where it stopped ==")
work(db, topic, -1, "next worker")
print(f"  still pending: {len(pending(db, topic))}")
print(f"  failed, kept for a person to look at: {len(pending(db, topic + '_failed'))}")
db.close()
os.remove(PATH)
