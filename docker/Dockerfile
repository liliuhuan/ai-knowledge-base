FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY scripts/requirements.txt /app/requirements.txt

# 安装 Python 依赖
RUN pip install --no-cache-dir -r /app/requirements.txt && \
    pip install --no-cache-dir unstructured

# 复制应用代码
COPY scripts/knowledge_base.py /app/
COPY scripts/web_ui.py /app/
COPY scripts/config.yaml /app/
COPY docs/ /app/docs/

# 创建数据目录
RUN mkdir -p /app/data

# 设置环境变量
ENV PYTHONUNBUFFERED=1

# 暴露端口
EXPOSE 7860

# 启动应用
CMD ["python", "web_ui.py"]
