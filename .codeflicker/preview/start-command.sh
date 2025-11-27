#!/usr/bin/env bash
cd open-webui
./setup-ollama-cloud.sh

cd open-webui
./start-openwebui.sh

cd open-webui
./stop-openwebui.sh