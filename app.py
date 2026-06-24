import os
from contextlib import contextmanager

import pymysql
from flask import Flask, flash, redirect, render_template, request, url_for
from pymysql.cursors import DictCursor


app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY", "course-design-dev-key")


DB_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "127.0.0.1"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "user": os.getenv("MYSQL_USER", "root"),
    "password": os.getenv("MYSQL_PASSWORD", "root"),
    "database": os.getenv("MYSQL_DATABASE", "course_selection"),
    "charset": "utf8mb4",
    "cursorclass": DictCursor,
    "autocommit": False,
}


@contextmanager
def db():
    conn = pymysql.connect(**DB_CONFIG)
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def fetch_all(sql, args=None):
    with db() as conn:
        with conn.cursor() as cur:
            cur.execute(sql, args or ())
            return cur.fetchall()


def call_proc(name, args):
    with db() as conn:
        with conn.cursor() as cur:
            cur.callproc(name, args)


@app.errorhandler(Exception)
def handle_error(error):
    return render_template("error.html", error=error), 500


@app.route("/")
def index():
    stats = {
        "students": fetch_all("select count(*) total from students")[0]["total"],
        "courses": fetch_all("select count(*) total from courses")[0]["total"],
        "tasks": fetch_all("select count(*) total from teaching_tasks")[0]["total"],
        "enrollments": fetch_all("select count(*) total from enrollments where status='已选'")[0]["total"],
    }
    recent = fetch_all(
        """
        select e.select_time, s.student_name, c.course_name, t.teacher_name, e.status
        from enrollments e
        join students s on s.student_id=e.student_id
        join teaching_tasks tt on tt.task_id=e.task_id
        join courses c on c.course_id=tt.course_id
        join teachers t on t.teacher_id=tt.teacher_id
        order by e.select_time desc
        limit 8
        """
    )
    return render_template("index.html", stats=stats, recent=recent)


@app.route("/students", methods=["GET", "POST"])
def students():
    if request.method == "POST":
        call_proc(
            "sp_add_student",
            (
                request.form["student_id"],
                request.form["student_name"],
                request.form["gender"],
                int(request.form["class_id"]),
                request.form.get("phone") or None,
                request.form.get("email") or None,
            ),
        )
        flash("学生信息已添加")
        return redirect(url_for("students"))

    rows = fetch_all(
        """
        select s.*, cl.class_name, m.major_name, d.dept_name
        from students s
        join classes cl on cl.class_id=s.class_id
        join majors m on m.major_id=cl.major_id
        join departments d on d.dept_id=m.dept_id
        order by s.student_id
        """
    )
    classes = fetch_all(
        """
        select cl.class_id, concat(d.dept_name, ' / ', m.major_name, ' / ', cl.class_name) label
        from classes cl
        join majors m on m.major_id=cl.major_id
        join departments d on d.dept_id=m.dept_id
        order by cl.class_id
        """
    )
    return render_template("students.html", rows=rows, classes=classes)


@app.route("/courses", methods=["GET", "POST"])
def courses():
    if request.method == "POST":
        call_proc(
            "sp_add_course",
            (
                request.form["course_id"],
                request.form["course_name"],
                int(request.form["dept_id"]),
                float(request.form["credit"]),
                int(request.form["hours"]),
            ),
        )
        flash("课程已添加")
        return redirect(url_for("courses"))

    rows = fetch_all(
        """
        select c.*, d.dept_name
        from courses c join departments d on d.dept_id=c.dept_id
        order by c.course_id
        """
    )
    departments = fetch_all("select dept_id, dept_name from departments order by dept_id")
    return render_template("courses.html", rows=rows, departments=departments)


@app.route("/tasks", methods=["GET", "POST"])
def tasks():
    if request.method == "POST":
        call_proc(
            "sp_open_course",
            (
                request.form["course_id"],
                request.form["teacher_id"],
                int(request.form["term_id"]),
                int(request.form["room_id"]),
                int(request.form["weekday"]),
                int(request.form["start_section"]),
                int(request.form["end_section"]),
                int(request.form["max_students"]),
            ),
        )
        flash("开课任务已创建")
        return redirect(url_for("tasks"))

    rows = fetch_all(
        """
        select tt.*, c.course_name, t.teacher_name, tm.term_name,
               concat(r.building, r.room_no) room_name
        from teaching_tasks tt
        join courses c on c.course_id=tt.course_id
        join teachers t on t.teacher_id=tt.teacher_id
        join terms tm on tm.term_id=tt.term_id
        join classrooms r on r.room_id=tt.room_id
        order by tt.task_id desc
        """
    )
    options = {
        "courses": fetch_all("select course_id, course_name from courses order by course_id"),
        "teachers": fetch_all("select teacher_id, teacher_name from teachers order by teacher_id"),
        "terms": fetch_all("select term_id, term_name from terms order by term_id desc"),
        "rooms": fetch_all("select room_id, concat(building, room_no, '(', capacity, '人)') label from classrooms"),
    }
    return render_template("tasks.html", rows=rows, options=options)


@app.route("/select", methods=["GET", "POST"])
def select_course():
    if request.method == "POST":
        call_proc("sp_select_course", (request.form["student_id"], int(request.form["task_id"])))
        flash("选课成功")
        return redirect(url_for("select_course"))

    students_list = fetch_all("select student_id, student_name from students where status='在读' order by student_id")
    tasks_list = fetch_all(
        """
        select tt.task_id, concat(c.course_name, ' - ', t.teacher_name, ' 周', tt.weekday,
               ' 第', tt.start_section, '-', tt.end_section, '节 ',
               tt.current_students, '/', tt.max_students) label
        from teaching_tasks tt
        join courses c on c.course_id=tt.course_id
        join teachers t on t.teacher_id=tt.teacher_id
        order by tt.task_id desc
        """
    )
    rows = fetch_all(
        """
        select e.enroll_id, e.status, e.select_time, s.student_name, c.course_name, t.teacher_name,
               tm.term_name, tt.weekday, tt.start_section, tt.end_section
        from enrollments e
        join students s on s.student_id=e.student_id
        join teaching_tasks tt on tt.task_id=e.task_id
        join courses c on c.course_id=tt.course_id
        join teachers t on t.teacher_id=tt.teacher_id
        join terms tm on tm.term_id=tt.term_id
        order by e.enroll_id desc
        """
    )
    return render_template("select.html", rows=rows, students=students_list, tasks=tasks_list)


@app.post("/drop/<int:enroll_id>")
def drop_course(enroll_id):
    call_proc("sp_drop_course", (enroll_id,))
    flash("退课成功")
    return redirect(url_for("select_course"))


@app.route("/scores", methods=["GET", "POST"])
def scores():
    if request.method == "POST":
        call_proc(
            "sp_record_score",
            (
                int(request.form["enroll_id"]),
                float(request.form["usual_score"]),
                float(request.form["exam_score"]),
            ),
        )
        flash("成绩已录入")
        return redirect(url_for("scores"))

    rows = fetch_all(
        """
        select e.enroll_id, s.student_name, c.course_name, t.teacher_name,
               sc.usual_score, sc.exam_score, sc.total_score, sc.grade_point, e.status
        from enrollments e
        join students s on s.student_id=e.student_id
        join teaching_tasks tt on tt.task_id=e.task_id
        join courses c on c.course_id=tt.course_id
        join teachers t on t.teacher_id=tt.teacher_id
        left join scores sc on sc.enroll_id=e.enroll_id
        order by e.enroll_id desc
        """
    )
    return render_template("scores.html", rows=rows)


@app.route("/notices", methods=["GET", "POST"])
def notices():
    if request.method == "POST":
        with db() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    "insert into notices(title, content, publisher) values(%s,%s,%s)",
                    (request.form["title"], request.form["content"], request.form.get("publisher") or "管理员"),
                )
        flash("通知已发布")
        return redirect(url_for("notices"))

    rows = fetch_all("select * from notices order by publish_time desc")
    return render_template("notices.html", rows=rows)


if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)
