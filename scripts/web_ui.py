#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
本地知识库 Web UI
使用 Gradio 构建交互界面
"""

import gradio as gr
import os
from knowledge_base import LocalKnowledgeBase
from datetime import datetime


class KnowledgeBaseUI:
    """知识库 Web UI 类"""
    
    def __init__(self):
        self.kb = LocalKnowledgeBase('config.yaml')
        self.chat_history = []
    
    def build_kb_stream(self, docs_dir: str, rebuild: bool):
        """流式构建知识库的 UI 回调"""
        import os
        if not docs_dir or not os.path.exists(docs_dir):
            yield "❌ 错误: 请提供有效的文档目录路径"
            return
        
        try:
            # 开始构建
            yield "🚀 开始构建知识库...\n"
            
            # 扫描文档
            yield "📁 正在扫描文档目录...\n"
            import glob
            files = []
            for ext in ['*.txt', '*.md', '*.pdf', '*.docx', '*.epub']:
                files.extend(glob.glob(os.path.join(docs_dir, ext)))
            yield f"📄 找到 {len(files)} 个文档文件\n"
            
            # 加载嵌入模型
            yield "🧠 正在加载嵌入模型...\n"
            self.kb._initialize_embeddings()
            yield "✅ 嵌入模型加载完成\n"
            
            # 加载文档
            yield "📖 正在加载文档...\n"
            documents = []
            for i, file_path in enumerate(files):
                try:
                    doc = self.kb._load_document(file_path)
                    documents.extend(doc)
                    yield f"  ✓ {os.path.basename(file_path)}\n"
                except Exception as e:
                    yield f"  ❌ {os.path.basename(file_path)}: {str(e)}\n"
            
            # 分割文档
            yield f"✂️ 正在分割文档...\n"
            from langchain.text_splitter import RecursiveCharacterTextSplitter
            text_splitter = RecursiveCharacterTextSplitter(
                chunk_size=self.kb.config['document_processing']['chunk_size'],
                chunk_overlap=self.kb.config['document_processing']['chunk_overlap'],
                separators=self.kb.config['document_processing']['separators']
            )
            splits = text_splitter.split_documents(documents)
            yield f"✅ 文档分割完成，共 {len(splits)} 个文档块\n"
            
            # 创建向量数据库
            yield "🔍 正在创建向量数据库...\n"
            from langchain.vectorstores import Chroma
            import os
            os.environ["ANONYMIZED_TELEMETRY"] = "False"
            persist_dir = self.kb.config['chroma']['persist_directory']
            if rebuild and os.path.exists(persist_dir):
                import shutil
                shutil.rmtree(persist_dir)
                yield "🗑️ 已删除现有数据\n"
            
            self.kb.vectorstore = Chroma.from_documents(
                documents=splits,
                embedding=self.kb.embeddings,
                persist_directory=persist_dir,
                collection_name=self.kb.config['chroma']['collection_name']
            )
            yield "✅ 向量数据库创建完成\n"
            
            # 完成
            yield f"\n🎉 知识库构建成功！\n"
            yield f"📁 目录: {docs_dir}\n"
            yield f"📄 文档: {len(files)} 个文件\n"
            yield f"📝 块数: {len(splits)} 个文档块\n"
            yield f"⏰ 时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n"
            
        except Exception as e:
            yield f"❌ 构建失败: {str(e)}"
    
    def query_kb(self, question: str, history: list) -> tuple:
        """查询知识库的 UI 回调"""
        if not question.strip():
            return history, history
        
        try:
            # 添加用户问题到历史
            history.append((question, ""))
            
            # 获取答案
            answer, sources = self.kb.query(question, show_sources=False)
            
            # 直接使用答案，不显示参考来源
            full_answer = answer
            
            # 更新历史中的答案
            history[-1] = (question, full_answer)
            
            return history, history
            
        except Exception as e:
            error_msg = f"❌ 查询失败: {str(e)}"
            history.append((question, error_msg))
            return history, history
    
    def query_kb_stream(self, question: str, history: list):
        """流式查询知识库的 UI 回调"""
        if not question.strip():
            yield history, history
            return
        
        try:
            from datetime import datetime
            
            # 记录开始时间
            start_time = datetime.now()
            
            # 添加用户问题到历史，初始显示等待状态
            history.append((question, "🤔 正在检索知识库..."))
            yield history, history
            
            # 流式获取答案
            answer_parts = []
            sources = []
            chunk_count = 0
            
            for chunk, docs in self.kb.query_stream(question, show_sources=False):
                chunk_count += 1
                answer_parts.append(chunk)
                
                # 计算已经过的时间
                elapsed_time = (datetime.now() - start_time).total_seconds()
                
                # 显示答案内容和实时时间
                current_answer = "".join(answer_parts)
                
                # 检查是否是最终的时间信息（包含"生成时间"）
                if "**生成时间**" in current_answer:
                    # 这是最终结果，保持原样
                    history[-1] = (question, current_answer)
                else:
                    # 生成过程中，显示实时进度
                    display_answer = current_answer + f"\n\n⏱️ *生成中... {elapsed_time:.1f}秒*"
                    history[-1] = (question, display_answer)
                
                yield history, history
                
        except Exception as e:
            error_msg = f"❌ 查询失败: {str(e)}"
            history.append((question, error_msg))
            yield history, history
    
    def query_kb_with_file_stream(self, question: str, file_path: str, history: list):
        """带文件上传的流式查询"""
        from datetime import datetime
        
        # 如果没有问题也没有文件，直接返回
        if not question.strip() and not file_path:
            yield history, history
            return
        
        try:
            start_time = datetime.now()
            
            # 处理上传的文件
            if file_path:
                # 添加文件处理提示
                history.append((f"📎 已上传文件: {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", "📂 正在读取文件..."))
                yield history, history
                
                # 加载文件内容
                try:
                    history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", "📖 正在解析文件内容...")
                    yield history, history
                    
                    doc = self.kb._load_document(file_path)
                    if doc:
                        # 提取文件内容
                        file_content = "\n\n".join([d.page_content for d in doc])
                        
                        history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", "🧠 正在分析文件内容...")
                        yield history, history
                        
                        # 构建带文件内容的问题
                        if question.strip():
                            enhanced_question = f"基于以下文件内容回答问题：\n\n文件内容：\n{file_content[:3000]}\n\n问题：{question}"
                        else:
                            enhanced_question = f"请分析并总结以下文件的主要内容：\n\n{file_content[:3000]}"
                        
                        history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", "🤖 正在生成回答...")
                        yield history, history
                    else:
                        error_msg = "❌ 文件加载失败，格式可能不支持"
                        history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", error_msg)
                        yield history, history
                        return
                except Exception as e:
                    error_msg = f"❌ 文件处理失败: {str(e)}"
                    history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", error_msg)
                    yield history, history
                    return
            else:
                # 没有文件，直接使用问题
                enhanced_question = question
                history.append((question, "🤔 正在检索知识库..."))
                yield history, history
            
            # 流式获取答案
            answer_parts = []
            
            # 使用 LLM 直接回答（带文件内容）
            if file_path:
                from langchain.prompts import PromptTemplate
                
                prompt_template = """你是一个专业的中文助手。请根据用户的要求分析内容并回答。

{question}

请用中文详细回答，使用清晰的 Markdown 格式。"""
                
                prompt = prompt_template.format(question=enhanced_question)
                
                # 初始化 LLM（如果还没有）
                self.kb._initialize_llm()
                
                # 流式输出
                response = self.kb.llm.stream(prompt)
                
                for chunk in response:
                    if hasattr(chunk, 'content') and chunk.content:
                        content = str(chunk.content)
                        if content:
                            answer_parts.append(content)
                    elif isinstance(chunk, str):
                        content = str(chunk)
                        if content:
                            answer_parts.append(content)
                    
                    # 计算已经过的时间
                    elapsed_time = (datetime.now() - start_time).total_seconds()
                    
                    # 显示答案内容和实时时间
                    current_answer = "".join(answer_parts)
                    display_answer = current_answer + f"\n\n⏱️ *生成中... {elapsed_time:.1f}秒*"
                    history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", display_answer)
                    
                    yield history, history
            else:
                # 没有文件，使用知识库查询
                for chunk, docs in self.kb.query_stream(question, show_sources=False):
                    answer_parts.append(chunk)
                    
                    # 计算已经过的时间
                    elapsed_time = (datetime.now() - start_time).total_seconds()
                    
                    # 显示答案内容和实时时间
                    current_answer = "".join(answer_parts)
                    
                    # 检查是否是最终的时间信息（包含"生成时间"）
                    if "**生成时间**" in current_answer:
                        history[-1] = (question, current_answer)
                    else:
                        display_answer = current_answer + f"\n\n⏱️ *生成中... {elapsed_time:.1f}秒*"
                        history[-1] = (question, display_answer)
                    
                    yield history, history
            
            # 计算总时间
            end_time = datetime.now()
            generation_time = (end_time - start_time).total_seconds()
            
            # 如果是文件查询，添加时间信息
            if file_path and "**生成时间**" not in "".join(answer_parts):
                final_answer = "".join(answer_parts) + f"\n\n⏱️ **生成时间**: {generation_time:.2f}秒"
                history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", final_answer)
                yield history, history
                
        except Exception as e:
            error_msg = f"❌ 查询失败: {str(e)}"
            if file_path:
                history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question}", error_msg)
            else:
                history.append((question, error_msg))
            yield history, history
    
    def query_and_clear(self, question: str, file_path: str, history: list):
        """查询并清除输入（用于事件链）"""
        # 这个函数会被立即调用，返回清空的值和保存的输入
        return question, file_path, history, "", None
    
    def handle_submit(self, question: str, file_path: str, history: list):
        """处理提交（非流式版本）"""
        if not question.strip() and not file_path:
            return history, history
        
        try:
            from datetime import datetime
            start_time = datetime.now()
            
            # 处理上传的文件
            if file_path:
                # 添加文件处理提示
                history.append((f"📎 已上传文件: {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", "📂 正在处理文件..."))
                
                # 加载文件内容
                try:
                    doc = self.kb._load_document(file_path)
                    if doc:
                        # 提取文件内容
                        file_content = "\n\n".join([d.page_content for d in doc])
                        
                        # 构建带文件内容的问题
                        if question.strip():
                            enhanced_question = f"基于以下文件内容回答问题：\n\n文件内容：\n{file_content[:3000]}\n\n问题：{question}"
                        else:
                            enhanced_question = f"请分析并总结以下文件的主要内容：\n\n{file_content[:3000]}"
                        
                        # 使用 LLM 直接回答
                        self.kb._initialize_llm()
                        response = self.kb.llm.invoke(enhanced_question)
                        
                        # 计算时间
                        end_time = datetime.now()
                        generation_time = (end_time - start_time).total_seconds()
                        
                        # 添加时间信息
                        final_answer = str(response) + f"\n\n⏱️ **生成时间**: {generation_time:.2f}秒"
                        history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", final_answer)
                    else:
                        error_msg = "❌ 文件加载失败，格式可能不支持"
                        history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", error_msg)
                except Exception as e:
                    error_msg = f"❌ 文件处理失败: {str(e)}"
                    history[-1] = (f"📎 {file_path.split('/')[-1]}\n{question if question.strip() else '请分析这个文件'}", error_msg)
            else:
                # 没有文件，使用知识库查询
                answer, sources = self.kb.query(question, show_sources=False)
                history[-1] = (question, answer)
            
            return history, history
            
        except Exception as e:
            error_msg = f"❌ 查询失败: {str(e)}"
            history.append((question, error_msg))
            return history, history
    
    def clear_inputs(self):
        """清除输入框和文件"""
        print("🔄 清除输入框和文件...")  # 调试信息
        return "", None
    
    def clear_chat(self):
        """清除对话历史"""
        self.kb.memory.clear()
        self.chat_history = []
        return [], []
    
    def launch(self):
        """启动 Web UI"""
        
        # 自定义 CSS
        custom_css = """
        .gradio-container {
            font-family: 'Arial', sans-serif;
        }
        .chatbot {
            height: 500px;
        }
        .compact-file-upload {
            height: 120px !important;
            min-height: 120px !important;
        }
        .compact-file-upload .upload-button {
            height: 120px !important;
            min-height: 120px !important;
            padding: 8px !important;
        }
        .compact-file-upload .upload-text {
            font-size: 12px !important;
        }
        """
        
        with gr.Blocks(title="本地知识库系统", css=custom_css, theme=gr.themes.Soft()) as demo:
            
            gr.Markdown("""
            # 🧠 本地知识库系统
            
            基于 **Ollama + ChromaDB + Sentence Transformers** 构建的完全本地化知识库
            
            ### ✨ 特点
            - 🔒 **完全私有**: 所有数据在本地处理，不上传云端
            - 💰 **完全免费**: 无需任何 API 费用
            - 🚀 **即时响应**: 本地运行，响应快速
            - 🌏 **中文优化**: 支持中文文档和对话
            """)
            
            with gr.Tab("💬 对话查询"):
                with gr.Row():
                    with gr.Column(scale=1):
                        chatbot = gr.Chatbot(
                            label="对话历史",
                            height=500,
                            bubble_full_width=False,
                            render_markdown=True,
                            show_label=True,
                            container=True
                        )
                        
                        with gr.Row():
                            with gr.Column(scale=15):
                                question_input = gr.Textbox(
                                    label="输入你的问题",
                                    placeholder="请输入你的问题？",
                                    lines=1,
                                    max_lines=1
                                )
                            with gr.Column(scale=1):
                                file_upload = gr.File(
                                    label="📎文件上传",
                                    file_types=[".txt", ".md", ".pdf", ".docx", ".epub"],
                                    type="filepath",
                                    container=False,
                                    show_label=True,
                                    elem_classes=["compact-file-upload"]
                            )
                        
                        with gr.Row():
                            clear_btn = gr.Button("🗑️ 清除历史")
                            submit_btn = gr.Button("🚀 提问", variant="primary")

                
                # 聊天状态
                chat_state = gr.State([])
                
                # 点击按钮发送 - 使用流式输出
                def clear_all():
                    """清除所有输入"""
                    return gr.update(value=""), gr.update(value=None)
                
                submit_event = submit_btn.click(
                    fn=self.query_kb_with_file_stream,
                    inputs=[question_input, file_upload, chat_state],
                    outputs=[chatbot, chat_state]
                )
                submit_event.then(
                    fn=clear_all,  # 发送后清除
                    inputs=None,
                    outputs=[question_input, file_upload]
                )
                
                # 按回车键发送 - 使用流式输出
                submit_event2 = question_input.submit(
                    fn=self.query_kb_with_file_stream,
                    inputs=[question_input, file_upload, chat_state],
                    outputs=[chatbot, chat_state]
                )
                submit_event2.then(
                    fn=clear_all,  # 发送后清除
                    inputs=None,
                    outputs=[question_input, file_upload]
                )
                
                clear_btn.click(
                    fn=self.clear_chat,
                    outputs=[chatbot, chat_state]
                )
            
            with gr.Tab("🔨 构建知识库"):
                gr.Markdown("""
                ## 构建或更新知识库
                
                将你的文档放入指定目录，然后点击构建按钮。
                
                **支持的文档格式**: TXT, PDF, DOCX, Markdown, EPUB
                """)
                
                with gr.Row():
                    docs_dir_input = gr.Textbox(
                        label="文档目录路径",
                        placeholder="例如: docs 或 /Users/username/Documents/my_docs",
                        value="../docs"
                    )
                
                with gr.Row():
                    rebuild_checkbox = gr.Checkbox(
                        label="重新构建（删除现有数据）",
                        value=False
                    )
                
                build_btn = gr.Button("🔨 开始构建", variant="primary", size="lg")
                build_output = gr.Textbox(
                    label="构建进度",
                    lines=2,
                    interactive=False,
                    show_copy_button=True
                )
                
                build_btn.click(
                    fn=self.build_kb_stream,
                    inputs=[docs_dir_input, rebuild_checkbox],
                    outputs=build_output
                )
                
                gr.Markdown("""
                ### 📋 构建步骤
                
                1. 准备文档文件（支持 txt、pdf、docx、md、epub 格式）
                2. 将文档放入 `docs` 目录（或自定义目录）
                3. 点击"开始构建"按钮
                4. 等待构建完成（首次可能需要下载嵌入模型）
                5. 切换到"对话查询"标签页开始提问
                
                ### ⚙️ 配置说明
                
                可以在 `config.yaml` 中修改：
                - Ollama 模型选择
                - 嵌入模型选择
                - 文档分块大小
                - 检索参数等
                """)
            
            with gr.Tab("ℹ️ 系统信息"):
                gr.Markdown("""
                ## 系统配置
                
                ### 当前模型
                - **LLM**: qwen3 (中文优化)
                - **嵌入**: Sentence Transformers (多语言)
                - **向量库**: ChromaDB
                
                ### 硬件要求
                   - 最低: 8GB RAM
                   - 推荐: 16GB RAM + GPU
                
                ### 故障排查
                - **Ollama 连接失败**: 运行 `ollama serve`
                - **内存不足**: 减小 chunk_size 值
                - **查询缓慢**: 减少检索文档数量
                """)
        
        # 启动服务
            demo.launch(
                server_name="0.0.0.0",
                server_port=7873,
                share=False,
                show_error=True,
                inbrowser=True
            )


def main():
    """主函数"""
    print("🚀 正在启动本地知识库 Web UI...")
    print("📝 请确保已经安装 Ollama 并下载了模型")
    print("💡 访问地址: http://localhost:7860\n")
    
    ui = KnowledgeBaseUI()
    ui.launch()


if __name__ == "__main__":
    main()

