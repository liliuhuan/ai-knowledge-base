#!/usr/bin/env bash
# 内网穿透工具：
    # https://dashboard.cpolar.com/get-started 地址配置
    #https://dashboard.ngrok.com/legacy/usage ：
    #ngrok http 8080 --host-header="localhost:8080"

cd open-webui
./setup-ollama-cloud.sh

cd open-webui
./start-openwebui.sh

cd open-webui
./stop-openwebui.sh


//卸载模型
ollama rm <模型名称>

# 卸载本地模型（有 SIZE 显示的）
ollama rm qwen3:latest
ollama rm deepseek-r1:8b


//查看模型列表
ollama list

//查看模型详情
ollama show <模型名称>
