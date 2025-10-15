#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
本地知识库核心模块
使用 ChromaDB + Sentence Transformers + Ollama
"""

import os
import yaml
import logging
from typing import List, Dict, Tuple
from pathlib import Path
from datetime import datetime
import glob

from langchain.document_loaders import (
    TextLoader,
    PyPDFLoader,
    Docx2txtLoader,
    UnstructuredMarkdownLoader
)
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain.embeddings import HuggingFaceEmbeddings
from langchain.vectorstores import Chroma
from langchain.llms import Ollama
from langchain.chains import ConversationalRetrievalChain
from langchain.memory import ConversationBufferMemory
from langchain.prompts import PromptTemplate
from langchain_community.vectorstores.utils import filter_complex_metadata

from tqdm import tqdm
from colorama import Fore, Style, init

# 初始化彩色输出
init(autoreset=True)


class LocalKnowledgeBase:
    """本地知识库类"""
    
    def __init__(self, config_path: str = "config.yaml"):
        """初始化知识库"""
        self.config = self._load_config(config_path)
        self._setup_logging()
        self.embeddings = None
        self.vectorstore = None
        self.llm = None
        self.qa_chain = None
        self.memory = ConversationBufferMemory(
            memory_key="chat_history",
            return_messages=True,
            output_key="answer"
        )
        
        # 尝试加载现有知识库
        self._try_load_existing_knowledge_base()
        
        logging.info(f"{Fore.GREEN}本地知识库初始化完成")
    
    def _load_config(self, config_path: str) -> Dict:
        """加载配置文件"""
        with open(config_path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    
    def _try_load_existing_knowledge_base(self):
        """尝试加载现有知识库"""
        try:
            persist_dir = self.config['chroma']['persist_directory']
            if os.path.exists(persist_dir) and os.path.exists(os.path.join(persist_dir, 'chroma.sqlite3')):
                print(f"{Fore.CYAN}检测到现有知识库，正在加载...")
                
                # 初始化嵌入模型
                self._initialize_embeddings()
                
                # 加载现有向量存储
                os.environ["ANONYMIZED_TELEMETRY"] = "False"
                self.vectorstore = Chroma(
                    persist_directory=persist_dir,
                    embedding_function=self.embeddings,
                    collection_name=self.config['chroma']['collection_name']
                )
                print(f"{Fore.GREEN}✓ 现有知识库加载成功")
            else:
                print(f"{Fore.YELLOW}未检测到现有知识库，需要先构建")
        except Exception as e:
            print(f"{Fore.RED}加载现有知识库失败: {e}")
            self.vectorstore = None
    
    def _setup_logging(self):
        """设置日志"""
        log_level = getattr(logging, self.config['logging']['level'])
        logging.basicConfig(
            level=log_level,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.config['logging']['file'], encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
    
    def _initialize_embeddings(self):
        """初始化嵌入模型"""
        if self.embeddings is None:
            print(f"{Fore.CYAN}正在加载嵌入模型...")
            model_name = self.config['embeddings']['model_name']
            device = self.config['embeddings']['device']
            
            self.embeddings = HuggingFaceEmbeddings(
                model_name=model_name,
                model_kwargs={'device': device},
                encode_kwargs={'normalize_embeddings': True}
            )
            print(f"{Fore.GREEN}✓ 嵌入模型加载完成")
            logging.info(f"嵌入模型加载: {model_name}")
    
    def _initialize_llm(self):
        """初始化 Ollama LLM"""
        if self.llm is None:
            print(f"{Fore.CYAN}正在连接 Ollama...")
            self.llm = Ollama(
                base_url=self.config['ollama']['base_url'],
                model=self.config['ollama']['model'],
                temperature=self.config['ollama']['temperature'],
                top_p=self.config['ollama']['top_p']
            )
            print(f"{Fore.GREEN}✓ Ollama 连接成功")
            logging.info(f"Ollama 模型: {self.config['ollama']['model']}")
    
    def _load_document(self, file_path: str):
        """根据文件类型加载文档"""
        ext = Path(file_path).suffix.lower()
        
        try:
            if ext == '.txt':
                loader = TextLoader(file_path, encoding='utf-8')
            elif ext == '.pdf':
                loader = PyPDFLoader(file_path)
            elif ext == '.docx':
                loader = Docx2txtLoader(file_path)
            elif ext == '.md':
                loader = UnstructuredMarkdownLoader(file_path)
            elif ext == '.epub':
                # 使用 ebooklib 直接解析 EPUB 文件
                from ebooklib import epub
                import ebooklib
                from langchain.schema import Document
                
                book = epub.read_epub(file_path)
                documents = []
                
                for item in book.get_items():
                    if item.get_type() == ebooklib.ITEM_DOCUMENT:
                        # 提取文本内容
                        content = item.get_content().decode('utf-8')
                        if content.strip():
                            # 清理 HTML 标签
                            import re
                            clean_content = re.sub(r'<[^>]+>', '', content)
                            clean_content = re.sub(r'\s+', ' ', clean_content).strip()
                            
                            if clean_content:
                                # 安全获取元数据，确保返回字符串
                                title_meta = book.get_metadata('DC', 'title')
                                author_meta = book.get_metadata('DC', 'creator')
                                
                                title = 'Unknown'
                                author = 'Unknown'
                                
                                if title_meta and len(title_meta) > 0:
                                    title = str(title_meta[0]) if isinstance(title_meta[0], (str, int, float, bool)) else str(title_meta[0])
                                
                                if author_meta and len(author_meta) > 0:
                                    author = str(author_meta[0]) if isinstance(author_meta[0], (str, int, float, bool)) else str(author_meta[0])
                                
                                doc = Document(
                                    page_content=clean_content,
                                    metadata={
                                        'source': str(file_path),
                                        'title': title,
                                        'author': author
                                    }
                                )
                                documents.append(doc)
                
                return documents
            else:
                logging.warning(f"不支持的文件格式: {file_path}")
                return []
            
            return loader.load()
        except Exception as e:
            logging.error(f"加载文件失败 {file_path}: {e}")
            return []
    
    def build_knowledge_base(self, docs_dir: str, rebuild: bool = False):
        """构建知识库"""
        import os
        
        print(f"\n{Fore.YELLOW}{'='*60}")
        print(f"{Fore.YELLOW}开始构建本地知识库")
        print(f"{Fore.YELLOW}{'='*60}\n")
        
        # 初始化嵌入模型
        self._initialize_embeddings()
        
        persist_dir = self.config['chroma']['persist_directory']
        
        # 检查是否已存在
        if os.path.exists(persist_dir) and not rebuild:
            print(f"{Fore.GREEN}检测到现有知识库，正在加载...")
            os.environ["ANONYMIZED_TELEMETRY"] = "False"
            self.vectorstore = Chroma(
                persist_directory=persist_dir,
                embedding_function=self.embeddings,
                collection_name=self.config['chroma']['collection_name']
            )
            print(f"{Fore.GREEN}✓ 知识库加载完成")
            return
        
        # 加载文档
        print(f"{Fore.CYAN}正在扫描文档目录: {docs_dir}")
        documents = []
        # 支持的文件格式
        file_patterns = self.config.get('supported_formats', ['*.txt', '*.pdf', '*.docx', '*.md', '*.epub'])
        
        all_files = []
        for pattern in file_patterns:
            all_files.extend(glob.glob(os.path.join(docs_dir, '**', pattern), recursive=True))
        
        if not all_files:
            print(f"{Fore.RED}错误: 未找到任何文档文件")
            return
        
        print(f"{Fore.GREEN}找到 {len(all_files)} 个文件")
        
        for file_path in tqdm(all_files, desc="加载文档", colour="green"):
            docs = self._load_document(file_path)
            if docs:
                documents.extend(docs)
                print(f"{Fore.GREEN}  ✓ {os.path.basename(file_path)}")
        
        if not documents:
            print(f"{Fore.RED}错误: 没有成功加载任何文档")
            return
        
        print(f"\n{Fore.CYAN}正在分割文档...")
        # 文档分割
        text_splitter = RecursiveCharacterTextSplitter(
            chunk_size=self.config['document_processing']['chunk_size'],
            chunk_overlap=self.config['document_processing']['chunk_overlap'],
            separators=self.config['document_processing']['separators']
        )
        splits = text_splitter.split_documents(documents)
        print(f"{Fore.GREEN}✓ 文档分割完成，共 {len(splits)} 个文档块")
        
        # 过滤复杂元数据
        print(f"{Fore.CYAN}正在过滤元数据...")
        splits = filter_complex_metadata(splits)
        print(f"{Fore.GREEN}✓ 元数据过滤完成")
        
        # 创建向量存储
        print(f"{Fore.CYAN}正在创建向量数据库...")
        import os
        os.environ["ANONYMIZED_TELEMETRY"] = "False"
        self.vectorstore = Chroma.from_documents(
            documents=splits,
            embedding=self.embeddings,
            persist_directory=persist_dir,
            collection_name=self.config['chroma']['collection_name']
        )
        
        print(f"{Fore.GREEN}✓ 向量数据库创建完成")
        print(f"\n{Fore.YELLOW}{'='*60}")
        print(f"{Fore.GREEN}知识库构建成功！")
        print(f"{Fore.YELLOW}{'='*60}\n")
        
        logging.info(f"知识库构建完成: {len(splits)} 个文档块")
    
    def _create_qa_chain(self):
        """创建问答链"""
        if self.qa_chain is None:
            self._initialize_llm()
            
            # 自定义提示模板
            prompt_template = """你是一个专业的中文知识助手。你必须使用中文回答所有问题。

请仔细阅读以下上下文信息，并用中文详细回答用户的问题。

重要规则：
1. 必须使用中文回答，不要使用英文
2. 基于上下文信息提供准确、详细的答案
3. 如果上下文中没有相关信息，请用中文说"根据提供的信息，我无法回答这个问题"
4. 保持专业和友好的语气
5. 可以引用具体的段落和示例
6. 使用清晰的 Markdown 格式，包括：
   - 使用 ## 作为二级标题（不要使用 ###）
   - 使用 - 作为列表项
   - 使用 **粗体** 强调重要内容
   - 代码块使用 ```语言 格式
7. 确保所有中文字符正确显示，不要出现乱码
8. 输出要稳定，避免字符错误

上下文信息:
{context}

历史对话:
{chat_history}

用户问题: {question}

请用中文详细回答，确保字符正确显示，并使用清晰的 Markdown 格式:"""
            
            PROMPT = PromptTemplate(
                template=prompt_template,
                input_variables=["context", "chat_history", "question"]
            )
            
            retriever = self.vectorstore.as_retriever(
                search_type=self.config['retrieval']['search_type'],
                search_kwargs={"k": self.config['retrieval']['k']}
            )
            
            self.qa_chain = ConversationalRetrievalChain.from_llm(
                llm=self.llm,
                retriever=retriever,
                memory=self.memory,
                return_source_documents=True,
                combine_docs_chain_kwargs={"prompt": PROMPT}
            )
    
    def query(self, question: str, show_sources: bool = True) -> Tuple[str, List]:
        """查询知识库"""
        if self.vectorstore is None:
            return "错误: 知识库未初始化，请先构建知识库", []
        
        self._create_qa_chain()
        
        # 记录开始时间
        start_time = datetime.now()
        
        print(f"\n{Fore.CYAN}正在思考...")
        
        try:
            result = self.qa_chain({"question": question})
            answer = result['answer']
            sources = result.get('source_documents', [])
            
            # 计算生成时间
            end_time = datetime.now()
            generation_time = (end_time - start_time).total_seconds()
            
            # 添加时间信息到答案
            time_info = f"\n\n⏱️ **生成时间**: {generation_time:.2f}秒"
            answer_with_time = answer + time_info
            
            print(f"\n{Fore.GREEN}回答:")
            print(f"{Fore.WHITE}{answer}")
            print(f"{Fore.CYAN}⏱️ 生成时间: {generation_time:.2f}秒")
            
            if show_sources and sources:
                print(f"\n{Fore.YELLOW}参考来源:")
                for i, doc in enumerate(sources[:3], 1):
                    source = doc.metadata.get('source', '未知来源')
                    print(f"{Fore.YELLOW}  [{i}] {source}")
                    print(f"{Fore.WHITE}      {doc.page_content[:100]}...")
            
            return answer_with_time, sources
            
        except Exception as e:
            error_msg = f"查询失败: {str(e)}"
            logging.error(error_msg)
            return error_msg, []
    
    def query_stream(self, question: str, show_sources: bool = True):
        """流式查询知识库"""
        if self.vectorstore is None:
            yield "错误: 知识库未初始化，请先构建知识库", []
            return
        
        self._create_qa_chain()
        
        # 记录开始时间
        start_time = datetime.now()
        
        try:
            # 获取相关文档
            retriever = self.vectorstore.as_retriever(
                search_type=self.config['retrieval']['search_type'],
                search_kwargs={"k": self.config['retrieval']['k']}
            )
            docs = retriever.get_relevant_documents(question)
            
            # 构建上下文
            context = "\n\n".join([doc.page_content for doc in docs])
            
            # 获取历史对话
            chat_history = self.memory.chat_memory.messages
            chat_history_str = "\n".join([f"{msg.type}: {msg.content}" for msg in chat_history[-6:]])
            
            # 构建提示
            prompt_template = """你是一个专业的中文知识助手。你必须使用中文回答所有问题。

请仔细阅读以下上下文信息，并用中文详细回答用户的问题。

重要规则：
1. 必须使用中文回答，不要使用英文
2. 基于上下文信息提供准确、详细的答案
3. 如果上下文中没有相关信息，请用中文说"根据提供的信息，我无法回答这个问题"
4. 保持专业和友好的语气
5. 可以引用具体的段落和示例
6. 使用清晰的 Markdown 格式，包括：
   - 使用 ## 作为二级标题（不要使用 ###）
   - 使用 - 作为列表项
   - 使用 **粗体** 强调重要内容
   - 代码块使用 ```语言 格式
7. 确保所有中文字符正确显示，不要出现乱码
8. 输出要稳定，避免字符错误

上下文信息:
{context}

历史对话:
{chat_history}

用户问题: {question}

请用中文详细回答，确保字符正确显示，并使用清晰的 Markdown 格式:"""

            prompt = prompt_template.format(
                context=context,
                chat_history=chat_history_str,
                question=question
            )
            
            # 使用真正的流式输出
            response = self.llm.stream(prompt)
            
            # 流式输出每个chunk，同时收集完整答案
            answer_chunks = []
            for chunk in response:
                if hasattr(chunk, 'content') and chunk.content:
                    # 保留原始内容，不要strip，以保持格式
                    content = str(chunk.content)
                    if content:
                        answer_chunks.append(content)
                        yield content, docs
                elif isinstance(chunk, str):
                    # 保留原始字符串，不要strip，以保持格式
                    content = str(chunk)
                    if content:
                        answer_chunks.append(content)
                        yield content, docs
            
            # 计算生成时间
            end_time = datetime.now()
            generation_time = (end_time - start_time).total_seconds()
            
            # 更新记忆
            full_answer = "".join(answer_chunks)
            self.memory.chat_memory.add_user_message(question)
            self.memory.chat_memory.add_ai_message(full_answer)
            
            # 输出时间信息
            time_info = f"\n\n⏱️ **生成时间**: {generation_time:.2f}秒"
            yield time_info, docs
            
        except Exception as e:
            error_msg = f"查询失败: {str(e)}"
            logging.error(error_msg)
            yield error_msg, []
    
    def chat(self):
        """交互式对话"""
        print(f"\n{Fore.CYAN}{'='*60}")
        print(f"{Fore.CYAN}  本地知识库对话系统")
        print(f"{Fore.CYAN}{'='*60}")
        print(f"{Fore.YELLOW}提示: 输入 'exit' 或 'quit' 退出")
        print(f"{Fore.YELLOW}      输入 'clear' 清除对话历史\n")
        
        while True:
            try:
                question = input(f"{Fore.GREEN}你: {Style.RESET_ALL}")
                
                if question.lower() in ['exit', 'quit', '退出']:
                    print(f"{Fore.CYAN}再见！")
                    break
                
                if question.lower() in ['clear', '清除']:
                    self.memory.clear()
                    print(f"{Fore.YELLOW}对话历史已清除")
                    continue
                
                if not question.strip():
                    continue
                
                self.query(question)
                
            except KeyboardInterrupt:
                print(f"\n{Fore.CYAN}再见！")
                break
            except Exception as e:
                print(f"{Fore.RED}错误: {e}")
                logging.error(f"对话错误: {e}")


def main():
    """主函数"""
    import argparse
    
    parser = argparse.ArgumentParser(description='本地知识库系统')
    parser.add_argument('--build', type=str, help='构建知识库，指定文档目录路径')
    parser.add_argument('--rebuild', action='store_true', help='重新构建知识库')
    parser.add_argument('--query', type=str, help='单次查询')
    parser.add_argument('--chat', action='store_true', help='启动对话模式')
    parser.add_argument('--config', type=str, default='config.yaml', help='配置文件路径')
    
    args = parser.parse_args()
    
    kb = LocalKnowledgeBase(config_path=args.config)
    
    if args.build:
        kb.build_knowledge_base(args.build, rebuild=args.rebuild)
    
    if args.query:
        kb.query(args.query)
    
    if args.chat:
        kb.chat()
    
    if not any([args.build, args.query, args.chat]):
        parser.print_help()


if __name__ == "__main__":
    main()

