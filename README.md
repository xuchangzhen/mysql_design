# 学生选课管理系统

本项目用于数据库技术课程设计，技术栈为 MySQL + Python Flask + HTML/CSS。系统功能保持简单，重点覆盖数据库设计要求：表、约束、外键、触发器、存储过程和基础 Web 应用。

## 功能

- 学生管理：新增学生、查看学生列表
- 课程管理：新增课程、查看课程列表
- 开课管理：课程、教师、学期、教室、上课时间和容量设置
- 选课管理：学生选课、退课，数据库触发器检查容量和时间冲突
- 成绩管理：录入平时分和考试分，触发器自动计算总评和绩点
- 通知管理：发布和查看教务通知

## 数据库要求对应情况

- 数据库表：13 张，满足不少于 10 张表
- 外键：学生、班级、专业、学院、课程、教师、开课、选课、成绩之间均设置外键
- 约束：主键、唯一约束、非空约束、检查约束、枚举状态
- 触发器：6 个，满足不少于 5 个
- 存储过程：6 个，满足不少于 5 个

## 目录结构

```text
mysql_design/
├─ app.py
├─ requirements.txt
├─ README.md
├─ sql/
│  └─ schema.sql
├─ templates/
│  ├─ base.html
│  ├─ index.html
│  ├─ students.html
│  ├─ courses.html
│  ├─ tasks.html
│  ├─ select.html
│  ├─ scores.html
│  ├─ notices.html
│  └─ error.html
├─ static/
│  └─ style.css
└─ docs/
   └─ course_design_report.md
```

## 运行方法

1. 安装依赖：

```bash
pip install -r requirements.txt
```

2. 导入数据库：

```bash
mysql -u root -p < sql/schema.sql
```

3. 设置数据库连接信息。默认使用 `root/root` 连接本机 MySQL，可按需修改环境变量：

```bash
set MYSQL_HOST=127.0.0.1
set MYSQL_PORT=3306
set MYSQL_USER=root
set MYSQL_PASSWORD=你的密码
set MYSQL_DATABASE=course_selection
```

PowerShell 写法：

```powershell
$env:MYSQL_PASSWORD="你的密码"
```

4. 启动项目：

```bash
python app.py
```

5. 浏览器访问：

```text
http://127.0.0.1:5000
```

## 示例账号

当前系统没有做登录限制，`users` 表中预置了示例账号，方便写报告时说明：

- 管理员：admin / 123456
- 学生：202301001 / 123456
- 教师：T001 / 123456

## 说明

本项目偏课程设计演示，重点是数据库设计和基本业务流程。实际生产系统还应增加登录鉴权、权限控制、密码加密、分页查询、日志审计和更完整的数据校验。
