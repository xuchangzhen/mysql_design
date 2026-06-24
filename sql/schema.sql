drop database if exists course_selection;
create database course_selection default charset utf8mb4 collate utf8mb4_unicode_ci;
use course_selection;

-- 徐昌真
-- 基础信息表创建
create table departments (
  dept_id int primary key auto_increment,
  dept_name varchar(80) not null unique
);

create table majors (
  major_id int primary key auto_increment,
  dept_id int not null,
  major_name varchar(80) not null,
  unique key uk_major(dept_id, major_name),
  constraint fk_major_dept foreign key (dept_id) references departments(dept_id)
);

create table classes (
  class_id int primary key auto_increment,
  major_id int not null,
  class_name varchar(80) not null,
  grade_year year not null,
  unique key uk_class(major_id, class_name),
  constraint fk_class_major foreign key (major_id) references majors(major_id)
);

create table students (
  student_id varchar(20) primary key,
  class_id int not null,
  student_name varchar(50) not null,
  gender enum('男','女') not null,
  phone varchar(20),
  email varchar(80),
  status enum('在读','休学','毕业') not null default '在读',
  created_at datetime not null default current_timestamp,
  constraint fk_student_class foreign key (class_id) references classes(class_id),
  constraint uk_student_email unique (email)
);

-- 李炜
-- 教学资源和课程表创建
create table teachers (
  teacher_id varchar(20) primary key,
  dept_id int not null,
  teacher_name varchar(50) not null,
  title varchar(40) not null default '讲师',
  phone varchar(20),
  email varchar(80),
  constraint fk_teacher_dept foreign key (dept_id) references departments(dept_id),
  constraint uk_teacher_email unique (email)
);

create table classrooms (
  room_id int primary key auto_increment,
  building varchar(40) not null,
  room_no varchar(20) not null,
  capacity int not null,
  unique key uk_room(building, room_no),
  constraint ck_room_capacity check (capacity > 0)
);

create table terms (
  term_id int primary key auto_increment,
  term_name varchar(50) not null unique,
  start_date date not null,
  end_date date not null,
  constraint ck_term_date check (start_date < end_date)
);

create table courses (
  course_id varchar(20) primary key,
  dept_id int not null,
  course_name varchar(100) not null,
  credit decimal(3,1) not null,
  hours int not null,
  constraint fk_course_dept foreign key (dept_id) references departments(dept_id),
  constraint ck_course_credit check (credit > 0),
  constraint ck_course_hours check (hours > 0)
);

create table teaching_tasks (
  task_id int primary key auto_increment,
  course_id varchar(20) not null,
  teacher_id varchar(20) not null,
  term_id int not null,
  room_id int not null,
  weekday tinyint not null,
  start_section tinyint not null,
  end_section tinyint not null,
  max_students int not null,
  current_students int not null default 0,
  constraint fk_task_course foreign key (course_id) references courses(course_id),
  constraint fk_task_teacher foreign key (teacher_id) references teachers(teacher_id),
  constraint fk_task_term foreign key (term_id) references terms(term_id),
  constraint fk_task_room foreign key (room_id) references classrooms(room_id),
  constraint ck_task_weekday check (weekday between 1 and 7),
  constraint ck_task_section check (start_section between 1 and 12 and end_section between start_section and 12),
  constraint ck_task_count check (max_students > 0 and current_students >= 0 and current_students <= max_students)
);

-- 解世轩
-- 选课和成绩表创建
create table enrollments (
  enroll_id int primary key auto_increment,
  student_id varchar(20) not null,
  task_id int not null,
  select_time datetime not null default current_timestamp,
  status enum('已选','退选','完成') not null default '已选',
  unique key uk_student_task(student_id, task_id),
  constraint fk_enroll_student foreign key (student_id) references students(student_id),
  constraint fk_enroll_task foreign key (task_id) references teaching_tasks(task_id)
);

create table scores (
  score_id int primary key auto_increment,
  enroll_id int not null unique,
  usual_score decimal(5,2),
  exam_score decimal(5,2),
  total_score decimal(5,2),
  grade_point decimal(3,2),
  constraint fk_score_enroll foreign key (enroll_id) references enrollments(enroll_id),
  constraint ck_score_usual check (usual_score is null or usual_score between 0 and 100),
  constraint ck_score_exam check (exam_score is null or exam_score between 0 and 100),
  constraint ck_score_total check (total_score is null or total_score between 0 and 100)
);

create table users (
  user_id int primary key auto_increment,
  username varchar(40) not null unique,
  password varchar(120) not null,
  role enum('管理员','教师','学生') not null,
  related_id varchar(20),
  created_at datetime not null default current_timestamp
);

create table notices (
  notice_id int primary key auto_increment,
  title varchar(100) not null,
  content text not null,
  publisher varchar(50) not null,
  publish_time datetime not null default current_timestamp
);

-- 解世轩
-- 操作日志表创建
create table operation_logs (
  log_id int primary key auto_increment,
  action_type varchar(40) not null,
  detail varchar(255) not null,
  created_at datetime not null default current_timestamp
);

delimiter //

-- 王泽湘
-- 开课检查触发器
create trigger trg_task_before_insert
before insert on teaching_tasks
for each row
begin
  declare room_cap int;
  select capacity into room_cap from classrooms where room_id = new.room_id;
  if new.max_students > room_cap then
    signal sqlstate '45000' set message_text = '开课人数不能超过教室容量';
  end if;
  if new.end_section < new.start_section then
    signal sqlstate '45000' set message_text = '结束节次不能小于开始节次';
  end if;
end//

-- 王泽湘
-- 开课修改触发器
create trigger trg_task_before_update
before update on teaching_tasks
for each row
begin
  declare room_cap int;
  select capacity into room_cap from classrooms where room_id = new.room_id;
  if new.max_students > room_cap then
    signal sqlstate '45000' set message_text = '开课人数不能超过教室容量';
  end if;
  if new.max_students < new.current_students then
    signal sqlstate '45000' set message_text = '容量不能小于已选人数';
  end if;
end//

-- 王泽湘
-- 选课前检查触发器
create trigger trg_enroll_before_insert
before insert on enrollments
for each row
begin
  declare stu_status varchar(10);
  declare cap int;
  declare selected_count int;
  declare conflict_count int;

  select status into stu_status from students where student_id = new.student_id;
  if stu_status <> '在读' then
    signal sqlstate '45000' set message_text = '只有在读学生可以选课';
  end if;

  select max_students - current_students into cap from teaching_tasks where task_id = new.task_id;
  if cap <= 0 then
    signal sqlstate '45000' set message_text = '课程人数已满';
  end if;

  select count(*) into selected_count
  from enrollments
  where student_id = new.student_id and status = '已选';
  if selected_count >= 8 then
    signal sqlstate '45000' set message_text = '每名学生最多选择8门课程';
  end if;

  select count(*) into conflict_count
  from enrollments e
  join teaching_tasks a on a.task_id = e.task_id
  join teaching_tasks b on b.task_id = new.task_id
  where e.student_id = new.student_id
    and e.status = '已选'
    and a.term_id = b.term_id
    and a.weekday = b.weekday
    and not (a.end_section < b.start_section or b.end_section < a.start_section);
  if conflict_count > 0 then
    signal sqlstate '45000' set message_text = '课程时间冲突';
  end if;
end//

-- 王泽湘
-- 选课后处理触发器
create trigger trg_enroll_after_insert
after insert on enrollments
for each row
begin
  if new.status = '已选' then
    update teaching_tasks set current_students = current_students + 1 where task_id = new.task_id;
  end if;
  insert into scores(enroll_id) values(new.enroll_id);
  insert into operation_logs(action_type, detail)
  values('选课', concat(new.student_id, ' 选择教学任务 ', new.task_id));
end//

-- 王泽湘
-- 退课后处理触发器
create trigger trg_enroll_after_update
after update on enrollments
for each row
begin
  if old.status = '已选' and new.status <> '已选' then
    update teaching_tasks set current_students = current_students - 1 where task_id = new.task_id;
  elseif old.status <> '已选' and new.status = '已选' then
    update teaching_tasks set current_students = current_students + 1 where task_id = new.task_id;
  end if;
  insert into operation_logs(action_type, detail)
  values('选课状态变更', concat(new.student_id, ' 的选课记录 ', new.enroll_id, ' 状态为 ', new.status));
end//

-- 王泽湘
-- 成绩计算触发器
create trigger trg_score_before_update
before update on scores
for each row
begin
  if new.usual_score is not null and new.exam_score is not null then
    set new.total_score = new.usual_score * 0.4 + new.exam_score * 0.6;
    set new.grade_point =
      case
        when new.total_score >= 90 then 4.0
        when new.total_score >= 80 then 3.0
        when new.total_score >= 70 then 2.0
        when new.total_score >= 60 then 1.0
        else 0
      end;
  end if;
end//

-- 徐昌真
-- 添加学生存储过程
create procedure sp_add_student(
  in p_student_id varchar(20),
  in p_student_name varchar(50),
  in p_gender varchar(2),
  in p_class_id int,
  in p_phone varchar(20),
  in p_email varchar(80)
)
begin
  insert into students(student_id, student_name, gender, class_id, phone, email)
  values(p_student_id, p_student_name, p_gender, p_class_id, p_phone, p_email);
end//

-- 徐昌真
-- 添加课程存储过程
create procedure sp_add_course(
  in p_course_id varchar(20),
  in p_course_name varchar(100),
  in p_dept_id int,
  in p_credit decimal(3,1),
  in p_hours int
)
begin
  insert into courses(course_id, course_name, dept_id, credit, hours)
  values(p_course_id, p_course_name, p_dept_id, p_credit, p_hours);
end//

-- 王泽湘
-- 开课存储过程
create procedure sp_open_course(
  in p_course_id varchar(20),
  in p_teacher_id varchar(20),
  in p_term_id int,
  in p_room_id int,
  in p_weekday tinyint,
  in p_start_section tinyint,
  in p_end_section tinyint,
  in p_max_students int
)
begin
  insert into teaching_tasks(course_id, teacher_id, term_id, room_id, weekday, start_section, end_section, max_students)
  values(p_course_id, p_teacher_id, p_term_id, p_room_id, p_weekday, p_start_section, p_end_section, p_max_students);
end//

-- 王泽湘
-- 学生选课存储过程
create procedure sp_select_course(
  in p_student_id varchar(20),
  in p_task_id int
)
begin
  insert into enrollments(student_id, task_id) values(p_student_id, p_task_id);
end//

-- 王泽湘
-- 学生退课存储过程
create procedure sp_drop_course(in p_enroll_id int)
begin
  update enrollments set status = '退选' where enroll_id = p_enroll_id and status = '已选';
end//

-- 徐昌真
-- 录入成绩存储过程
create procedure sp_record_score(
  in p_enroll_id int,
  in p_usual_score decimal(5,2),
  in p_exam_score decimal(5,2)
)
begin
  update scores
  set usual_score = p_usual_score, exam_score = p_exam_score
  where enroll_id = p_enroll_id;
  update enrollments set status = '完成' where enroll_id = p_enroll_id;
end//

delimiter ;

-- 解世轩
-- 学生选课查询视图
create view v_student_course as
select s.student_id, s.student_name, cl.class_name, c.course_id, c.course_name,
       t.teacher_name, tm.term_name, e.status, sc.total_score
from enrollments e
join students s on s.student_id=e.student_id
join classes cl on cl.class_id=s.class_id
join teaching_tasks tt on tt.task_id=e.task_id
join courses c on c.course_id=tt.course_id
join teachers t on t.teacher_id=tt.teacher_id
join terms tm on tm.term_id=tt.term_id
left join scores sc on sc.enroll_id=e.enroll_id;

-- 徐昌真
-- 基础信息测试数据
insert into departments(dept_name) values
('计算机与智能教育学院'), ('数学与统计学院'), ('外国语学院');

insert into majors(dept_id, major_name) values
(1, '软件工程'), (1, '计算机科学与技术'), (2, '数学与应用数学'), (3, '英语');

insert into classes(major_id, class_name, grade_year) values
(1, '软件工程2301班', 2023), (1, '软件工程2302班', 2023), (2, '计科2301班', 2023);

insert into students(student_id, class_id, student_name, gender, phone, email) values
('202301001', 1, '张三', '男', '13800000001', 'zhangsan@example.com'),
('202301002', 1, '李四', '女', '13800000002', 'lisi@example.com'),
('202301003', 2, '王五', '男', '13800000003', 'wangwu@example.com');

-- 李炜
-- 教学资源测试数据
insert into teachers(teacher_id, dept_id, teacher_name, title, phone, email) values
('T001', 1, '陈老师', '副教授', '13900000001', 'chen@example.com'),
('T002', 1, '刘老师', '讲师', '13900000002', 'liu@example.com'),
('T003', 2, '黄老师', '教授', '13900000003', 'huang@example.com');

insert into classrooms(building, room_no, capacity) values
('教学楼A', '301', 60), ('教学楼A', '302', 50), ('实验楼B', '205', 45);

insert into terms(term_name, start_date, end_date) values
('2025-2026学年第一学期', '2025-09-01', '2026-01-15'),
('2025-2026学年第二学期', '2026-02-24', '2026-07-05');

call sp_add_course('DB001', '数据库原理', 1, 3.0, 48);
call sp_add_course('PY001', 'Python程序设计', 1, 3.0, 48);
call sp_add_course('WEB001', 'Web前端基础', 1, 2.0, 32);
call sp_add_course('MATH001', '高等数学', 2, 4.0, 64);

call sp_open_course('DB001', 'T001', 1, 1, 2, 1, 2, 50);
call sp_open_course('PY001', 'T002', 1, 2, 3, 3, 4, 45);
call sp_open_course('WEB001', 'T002', 1, 3, 4, 1, 2, 40);
call sp_open_course('MATH001', 'T003', 1, 1, 5, 5, 6, 55);

-- 解世轩
-- 选课测试数据
call sp_select_course('202301001', 1);
call sp_select_course('202301001', 2);
call sp_select_course('202301002', 1);
call sp_select_course('202301003', 3);

-- 徐昌真
-- 账号和通知测试数据
insert into users(username, password, role, related_id) values
('admin', '123456', '管理员', null),
('202301001', '123456', '学生', '202301001'),
('T001', '123456', '教师', 'T001');

insert into notices(title, content, publisher) values
('选课通知', '本学期学生选课已经开始，请在规定时间内完成选课。', '教务管理员');
