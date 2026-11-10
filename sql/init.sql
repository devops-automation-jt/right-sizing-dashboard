-- 创建数据库
create database if not exists right_sizing_dashboard default character set utf8mb4 collate utf8mb4_unicode_ci;

use right_sizing_dashboard;

-- 优化记录表
create table if not exists optimization_records (
    id bigint primary key auto_increment comment '主键ID',
    namespace varchar(128) not null comment 'k8s 命名空间',
    deployment_name varchar(128) not null comment '目标 deployment 名称',
    old_cpu varchar(64) comment '优化前 cpu 请求，例如 1000m',
    old_memory varchar(64) comment '优化前 memory 请求，例如 512Mi',
    new_cpu varchar(64) comment '推荐 cpu',
    new_memory varchar(64) comment '推荐 memory',
    p95_cpu_usage decimal(6,4) comment 'cpu p95 利用率，0~1',
    p95_memory_usage decimal(6,4) comment '内存 p95 利用率，0~1',
    status enum('pending','success','failed') not null default 'pending' comment '状态：pending待生效 / success成功 / failed失败',
    fail_reason text comment '失败原因，例如 prometheus timeout',
    created_at datetime default current_timestamp comment '记录创建时间',
    updated_at datetime default current_timestamp on update current_timestamp comment '更新时间'
) engine = innodb default character set utf8mb4 comment '资源优化审计记录表';

-- 建立索引，按应用+命名空间查询
create index idx_ns_deploy on optimization_records(namespace, deployment_name);

-- 插入一条测试数据,便于调试接口
insert into optimization_records (
    namespace,
    deployment_name,
    old_cpu,
    old_memory,
    new_cpu,
    new_memory,
    p95_cpu_usage,
    p95_memory_usage,
    status,
    fail_reason
) values (
    'default',
    'demo-web',
    '1000m',
    '512Mi',
    '400m',
    '256Mi',
    0.21,
    0.28,
    'success',
    null
);