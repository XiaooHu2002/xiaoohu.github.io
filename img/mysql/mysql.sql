--
-- 创建数据库stuInfo
--
CREATE DATABASE stuInfo
DEFAULT CHARACTER SET utf8mb4
DEFAULT COLLATE utf8mb4_general_ci;
USE stuInfo;

--
-- 表的结构 student		/*学生表*/
--
CREATE TABLE student (
id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '学生ID',
sNo CHAR(10) NOT NULL COMMENT '学号',
sName VARCHAR(20) NOT NULL COMMENT '姓名',
sex CHAR(1) NOT NULL DEFAULT '男' COMMENT '性别',
birthday DATE NOT NULL COMMENT '出生日期',
deptName VARCHAR(30) NOT NULL COMMENT '班级名称',
remark VARCHAR(80) COMMENT '备注',
PRIMARY KEY (id), 	/*设置id为主键*/
UNIQUE (sNo), 		/*设置sNo为唯一性索引*/
INDEX (sName) 		/*设置sName为普通索引*/
) ENGINE=InnoDB;

--
-- 转存表中的数据 student
--
INSERT INTO student (id, sNo, sName, sex, birthday, deptName, remark) VALUES
(1, '1308013101', '陈斌', '男', '1993-03-20', '软件131', NULL),
(2, '1308013102', '张洁', '女', '1996-02-08', '软件131', NULL),
(3, '1308013103', '郑先超', '男', '1994-04-25', '软件131', NULL),
(4, '1308013104', '徐孝兵', '男', '1994-08-06', '软件131', NULL),
(5, '1308013105', '王群', '女', '1995-03-27', '软件131', NULL),
(6, '1309122501', '刘威', '男', '1994-07-13', '网络131', NULL),
(7, '1309122502', '沈雁斌', '男', '1994-05-28', '网络131', NULL),
(8, '1309122503', '杨群', '女', '1995-10-18', '网络131', NULL),
(9, '1309122504', '蒋维维', '男', '1994-10-19', '网络131', NULL),
(10, '1309122505', '杨璐', '女', '1995-09-26', '网络131', NULL),
(11, '1312054901', '王林林', '男', '1994-04-16', '机电131', NULL),
(12, '1312054902', '杨一超', '男', '1994-08-27', '机电131', NULL),
(13, '1312054903', '张伟', '男', '1995-01-03', '机电131', NULL),
(14, '1312054904', '田翠萍', '女', '1994-10-20', '机电131', NULL),
(15, '1312054905', '周伟', '男', '1995-09-10', '机电131', NULL);

--
-- 表的结构 course		/*课程表*/
--
CREATE TABLE course (
id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '课程ID',
cNo CHAR(5) NOT NULL COMMENT '课程编号',
cName VARCHAR(30) NOT NULL COMMENT '课程名称',
credit TINYINT UNSIGNED COMMENT '学分',
remark VARCHAR(100) COMMENT '备注',
PRIMARY KEY (id), 	/*设置id为主键*/
UNIQUE (cNo), 		/*设置cNo为唯一性索引*/
UNIQUE (cName) 		/*设置cName为唯一性索引*/
) ENGINE=InnoDB;

--
-- 转存表中的数据 course
--
INSERT INTO course (id, cNo, cName, credit, remark) VALUES
(1, '01001', 'C语言程序设计', 5, '计算机类专业课程'),
(2, '01002', '数据结构', 4, '计算机类专业课程'),
(3, '01003', 'Java程序设计', 4, '计算机类专业课程'),
(4, '02001', '网络基础', 3, '计算机类专业课程'),
(5, '02002', '数据库原理及应用', 4, '计算机类专业课程'),
(6, '02003', '操作系统', 4, '计算机类专业课程'),
(7, '09001', '机械设计基础', 5, NULL),
(8, '09002', '机械制造基础', 4, NULL),
(9, '09003', '机械制图', 4, NULL);

--
-- 表的结构 score		/*成绩表*/
--
CREATE TABLE score (
id INT UNSIGNED NOT NULL AUTO_INCREMENT COMMENT '成绩ID',
sId INT UNSIGNED NOT NULL COMMENT '学生ID',
cId INT UNSIGNED NOT NULL COMMENT '课程ID',
grade TINYINT UNSIGNED NOT NULL COMMENT '成绩',
PRIMARY KEY (id), 	/*设置id为主键*/
UNIQUE (sId, cId), 	/*设置sId和cId为唯一性索引（复合索引）*/
FOREIGN KEY (sId) REFERENCES student(id)
ON UPDATE RESTRICT ON DELETE RESTRICT,
FOREIGN KEY (cId) REFERENCES course(id)
ON UPDATE RESTRICT ON DELETE RESTRICT
) ENGINE=InnoDB;

--
-- 转存表中的数据 score
--
INSERT INTO score (id, sId, cId, grade) VALUES
(1, 1, 1, 72),
(2, 1, 2, 56),
(3, 1, 3, 77),
(4, 2, 1, 85),
(5, 2, 2, 73),
(6, 2, 3, 90),
(7, 3, 1, 79),
(8, 4, 1, 82),
(9, 5, 1, 63),
(10, 6, 4, 84),
(11, 6, 5, 92),
(12, 6, 6, 71),
(13, 11, 7, 87),
(14, 11, 8, 90),
(15, 11, 9, 95);
