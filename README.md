# AI 知识库

基于 Ollama + ChromaDB + Sentence Transformers 的本地化知识库系统

## ✨ 特点

- 🔒 **完全私有**: 所有数据在本地处理
- 💰 **完全免费**: 无需任何 API 费用  
- 🚀 **即时响应**: 本地运行，响应快速
- 🌏 **中文优化**: 支持中文文档和对话
- 📊 **流式输出**: 实时显示生成过程

## 🚀 快速开始

### 1. 安装依赖

```bash
# 安装 Ollama
brew install ollama

# 下载模型
ollama pull qwen3

# 安装 Python 依赖
cd scripts
python -m venv venv
source venv/bin/activate  # Linux/Mac
# 或 venv\Scripts\activate  # Windows
pip install -r requirements.txt
```

### 2. 启动服务

```bash
# 使用管理脚本
./scripts/kb-manager.sh start

# 或直接运行
cd scripts
python web_ui.py
```

### 3. 使用系统

1. 访问 http://localhost:7860
2. 在"构建知识库"标签页添加文档目录
3. 点击"开始构建"等待完成
4. 在"对话查询"标签页开始提问

## 📁 项目结构

```
ai-knowledge-base/
├── scripts/           # 核心代码
│   ├── web_ui.py     # Web 界面
│   ├── knowledge_base.py  # 知识库核心
│   ├── config.yaml   # 配置文件
│   └── requirements.txt
├── docs/             # 文档目录
├── data/             # 数据存储
└── README.md
```

## ⚙️ 配置

编辑 `scripts/config.yaml` 调整设置：

```yaml
# 模型配置
ollama:
  model: "qwen3"          # 可选: qwen3, qwen2.5, qwen2, qwen
  temperature: 0.5

# 文档处理
document_processing:
  chunk_size: 1000        # 文档块大小
  chunk_overlap: 200      # 重叠大小
```

## 🛠️ 管理命令

```bash
./scripts/kb-manager.sh start    # 启动服务
./scripts/kb-manager.sh stop     # 停止服务
./scripts/kb-manager.sh restart  # 重启服务
./scripts/kb-manager.sh status   # 查看状态
```

## 📝 支持格式

- **文本**: .txt, .md
- **文档**: .pdf, .docx
- **电子书**: .epub
- **编码**: UTF-8

## 🔧 故障排查

**Ollama 连接失败**
```bash
ollama serve
```

**内存不足**
- 减小 `chunk_size` 值
- 使用更小的模型

**查询缓慢**
- 减少检索文档数量 (k值)
- 考虑使用 GPU

## 📄 许可证

MIT License