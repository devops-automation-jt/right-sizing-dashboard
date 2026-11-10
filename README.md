# K8s 资源右调可视化看板 RightSizing Dashboard

## 项目介绍
RightSizing Dashboard 是面向 Kubernetes 集群的容器资源优化运维效能平台，针对 Deployment 资源申请不合理导致的算力浪费、业务OOM风险等问题，对接 Prometheus 采集容器历史运行指标，基于 P95 分位数结合安全系数自动生成科学的资源推荐值，同时持久化全量优化记录用于审计追溯。
平台采用前后端分离架构，与执行层 Operator 解耦设计，负责推荐计算、可视化展示与历史审计，资源变更执行由独立的 RightSizing Operator 承接，符合云原生职责分离最佳实践。

---

## 核心能力运行实证
### 优化记录全量查询
```bash
# 调用查询接口
curl http://127.0.0.1:8080/api/records

# 返回结果
{
  "code": 0,
  "msg": "success",
  "data": [
    {
      "id": 1,
      "namespace": "default",
      "deployment_name": "demo-web",
      "old_cpu": "1000m",
      "old_memory": "512Mi",
      "new_cpu": "400m",
      "new_memory": "256Mi",
      "p95_cpu_usage": 0.21,
      "status": "success",
      "fail_reason": null,
      "created_at": "2026-11-10T10:23:12Z"
    }
  ]
}
```

### 资源推荐智能计算
```bash
# 传入命名空间与应用名，触发资源分析
curl "http://127.0.0.1:8080/api/recommendation?ns=default&deploymentName=demo-web"

# 返回分析结果
{
  "code": 0,
  "msg": "success",
  "data": {
    "current_cpu": "1000m",
    "current_memory": "512Mi",
    "p95_cpu_usage": 0.23,
    "p95_memory_usage": 0.31,
    "recommend_cpu": "500m",
    "recommend_memory": "384Mi",
    "optimization_ratio": "50%",
    "suggestion": "当前资源冗余度较高，建议下调CPU至500m，可显著降低算力浪费"
  }
}
```

### 优化记录持久化审计
```sql
-- 查询指定应用历史优化记录
mysql> select id,deployment_name,old_cpu,new_cpu,status from optimization_records where deployment_name='demo-web';
+----+-----------------+---------+---------+---------+
| id | deployment_name | old_cpu | new_cpu | status  |
+----+-----------------+---------+---------+---------+
|  1 | demo-web        | 1000m   | 400m    | success |
|  2 | demo-web        | 1000m   | 500m    | pending |
+----+-----------------+---------+---------+---------+
2 rows in set (0.00 sec)
```

---

## 设计亮点

- **数据驱动的科学推荐**：基于 Prometheus 采集的容器历史指标，以 P95 分位数为基准结合安全系数计算推荐值，避免平均值掩盖峰值的问题，兼顾成本与业务稳定性。
- **全生命周期审计留存**：MySQL 持久化全量优化记录，包含优化前后配置、计算依据、执行状态与失败原因，支持追溯、回滚与成本核算。
- **前后端分离分层架构**：Go + Gin 负责后端接口与指标计算，Vue3 + Element Plus 负责前端交互，职责清晰，易于扩展与维护。
- **执行层与展示层解耦**：平台仅负责计算、展示与审计，不直接操作集群资源，资源变更由独立 Operator 负责，避免展示层故障影响集群稳定性。

---

## 目录结构
```plaintext
right-sizing-dashboard/
├── README.md                       # 项目总览、功能说明、快速开始指引
├── .gitignore                      # Git 忽略文件配置
├── sql/
│   └── init.sql                    # 数据库初始化脚本，optimization_records 建表语句
├── backend/                        # Go + Gin 后端服务
│   ├── go.mod
│   ├── go.sum
│   ├── main.go                     # 服务入口，路由注册、中间件初始化
│   ├── config/
│   │   └── config.go               # MySQL、Prometheus 连接配置
│   ├── internal/
│   │   ├── model/
│   │   │   └── record.go           # GORM 模型，与 optimization_records 表映射
│   │   ├── controller/
│   │   │   ├── record_controller.go    # 优化记录 CRUD 接口
│   │   │   └── recommend_controller.go # 资源推荐计算接口
│   │   ├── service/
│   │   │   ├── record_service.go
│   │   │   └── prom_service.go     # Prometheus 指标查询、P95 计算逻辑
│   │   └── response/
│   │       └── response.go         # 统一返回格式封装
│   └── pkg/
│       └── util.go                 # 公共工具函数
├── frontend/                       # Vue3 + Element Plus 前端
│   ├── package.json
│   ├── vite.config.js
│   ├── src/
│   │   ├── main.js
│   │   ├── axios/
│   │   │   └── request.js          # Axios 请求封装
│   │   └── views/
│   │       └── Index.vue           # 主页面：优化记录列表 + 资源推荐查询
│   └── public/
└── docs/
    ├── requirement.md              # 需求规格文档
    ├── architecture.md             # 架构设计与数据流转说明
    ├── interview-notes.md          # 面试口述稿与题库
    └── problem-record.md           # 开发踩坑记录与解决方案
```

---

## 技术栈与实现

| 技术选型 | 工程落地应用 |
|---------|--------------|
| Go 1.22+ | 后端服务开发，基于 Gin 框架实现 RESTful 接口，GORM 完成数据库 ORM 映射，代码分层解耦 |
| MySQL 8.0 | 优化记录持久化存储，采用 utf8mb4 字符集，支持全量审计追溯 |
| Vue3 + Vite | 前端页面开发，Element Plus 组件库实现表格、表单交互，前后端分离架构 |
| Prometheus | 容器运行指标数据源，通过 HTTP API 查询 CPU/内存利用率，计算 P95 分位数 |
| Axios | 前端 HTTP 请求封装，统一错误处理与响应解析 |
| Postman | 接口调试与验证，保障接口参数与返回格式规范 |

---

## 快速开始

### 环境依赖
- MySQL 8.0+
- Go 1.22+
- Node.js 16+
- Prometheus（已接入 K8s 集群指标）

### 启动步骤
1. **初始化数据库**
```bash
mysql -uroot -p < sql/init.sql
```

2. **启动后端服务**
```bash
cd backend
go mod tidy
go run main.go
# 服务地址：http://127.0.0.1:8080
```

3. **启动前端页面**
```bash
cd frontend
npm install
npm run dev
# 页面地址：http://127.0.0.1:5173
```

### 接口清单
| 接口名称 | 请求方法 | 路径 | 功能说明 |
|----------|----------|------|----------|
| 优化记录列表 | GET | /api/records | 查询全量优化历史记录 |
| 新增优化记录 | POST | /api/records | 新增一条优化记录 |
| 更新优化记录 | PUT | /api/records/:id | 更新记录状态与失败原因 |
| 删除优化记录 | DELETE | /api/records/:id | 删除指定记录 |
| 资源推荐查询 | GET | /api/recommendation | 查询指定应用的资源优化推荐 |

---

## 核心分支说明
| 分支名 | 功能说明 |
|-------|---------|
| feature/sql-init | 数据库设计与建表脚本、测试数据初始化 |
| feature/gin-backend | Gin 项目骨架搭建、GORM 集成、优化记录查询接口 |
| feature/recommend-mock | 全量 CRUD 接口完善、统一返回格式、跨域中间件、模拟推荐接口 |
| feature/prom-integration | 对接 Prometheus HTTP API、P95 指标计算、真实推荐逻辑落地 |
| feature/vue-list | Vue3 项目初始化、优化记录列表页开发、接口对接 |
| feature/recommend-page | 资源推荐查询页开发、表单交互、异常处理 |
| docs/architecture | 项目文档补充、架构图、面试稿、踩坑记录整理 |

---

## 文档入口
- 需求规格：[requirement.md](docs/requirement.md)
- 架构设计：[architecture.md](docs/architecture.md)
- 面试题库：[interview-notes.md](docs/interview-notes.md)
- 踩坑记录：[problem-record.md](docs/problem-record.md)