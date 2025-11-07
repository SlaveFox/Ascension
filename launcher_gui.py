"""
Launcher com Interface Gráfica - NTO Ascension
Versão com interface gráfica usando tkinter (biblioteca padrão)
"""

import urllib.request
import urllib.parse
import json
import os
import subprocess
import sys
import platform
import threading
import time
import hashlib

try:
    import tkinter as tk
    from tkinter import ttk, messagebox, scrolledtext
except ImportError:
    print("❌ tkinter não está disponível!")
    print("   No Windows, tkinter geralmente vem com Python.")
    print("   Se não estiver disponível, instale: python-tk")
    sys.exit(1)

# Configurações
APP_NAME = "NTO Ascension"
APP_VERSION = "1.0.0"  # Versão atual do cliente
GITHUB_REPO = "SlaveFox/Ascension"  # Repositório no GitHub
GITHUB_API = "https://api.github.com"
CLIENT_EXE = "otclient_dx.exe"

# Modo de atualização: "github" ou "custom"
UPDATE_MODE = "github"  # Mude para "custom" se quiser usar a API antiga

# Mudar para o diretório do script
# IMPORTANTE: O launcher sempre deve estar na mesma pasta do executável do cliente
# Isso garante que ele encontre o otclient_dx.exe corretamente
if getattr(sys, 'frozen', False):
    # Se executado como executável compilado
    script_dir = os.path.dirname(sys.executable)
else:
    # Se executado como script Python
    script_dir = os.path.dirname(os.path.abspath(__file__))

os.chdir(script_dir)

class LauncherGUI:
    def __init__(self, root):
        self.root = root
        self.root.title(f"{APP_NAME} - Launcher")
        self.root.geometry("600x500")
        self.root.resizable(False, False)
        
        # Variáveis
        self.app_version = APP_VERSION
        self.github_repo = GITHUB_REPO
        self.github_api = GITHUB_API
        self.update_mode = UPDATE_MODE
        self.client_exe = CLIENT_EXE
        self.is_checking = False
        self.is_downloading = False
        self.update_data = None
        self.client_exists = False
        self.current_dir = os.getcwd()
        self.files_to_download = []
        self.download_url = ""
        self.latest_release = None
        
        # Configurar estilo
        self.setup_style()
        
        # Criar interface
        self.setup_ui()
        
        # Centralizar janela
        self.center_window()
        
    def setup_style(self):
        """Configura estilo da interface"""
        style = ttk.Style()
        style.theme_use('clam')
        
        # Cores personalizadas
        self.root.configure(bg='#2b2b2b')
        
    def center_window(self):
        """Centraliza a janela na tela"""
        self.root.update_idletasks()
        width = self.root.winfo_width()
        height = self.root.winfo_height()
        x = (self.root.winfo_screenwidth() // 2) - (width // 2)
        y = (self.root.winfo_screenheight() // 2) - (height // 2)
        self.root.geometry(f'{width}x{height}+{x}+{y}')
        
    def setup_ui(self):
        """Configura a interface do usuário"""
        # Frame principal
        main_frame = tk.Frame(self.root, bg='#2b2b2b', padx=20, pady=20)
        main_frame.pack(fill=tk.BOTH, expand=True)
        
        # Título
        title_label = tk.Label(
            main_frame,
            text=APP_NAME,
            font=("Arial", 18, "bold"),
            bg='#2b2b2b',
            fg='#ffffff'
        )
        title_label.pack(pady=(0, 5))
        
        subtitle_label = tk.Label(
            main_frame,
            text="Launcher",
            font=("Arial", 10),
            bg='#2b2b2b',
            fg='#aaaaaa'
        )
        subtitle_label.pack(pady=(0, 20))
        
        # Status
        status_frame = tk.Frame(main_frame, bg='#2b2b2b')
        status_frame.pack(fill=tk.X, pady=(0, 10))
        
        self.status_label = tk.Label(
            status_frame,
            text="Pronto para verificar atualizações",
            font=("Arial", 10),
            bg='#2b2b2b',
            fg='#ffffff',
            anchor='w'
        )
        self.status_label.pack(fill=tk.X)
        
        # Label para mostrar diretório atual
        self.dir_label = tk.Label(
            status_frame,
            text=f"Diretório: {self.current_dir}",
            font=("Arial", 8),
            bg='#2b2b2b',
            fg='#888888',
            anchor='w'
        )
        self.dir_label.pack(fill=tk.X, pady=(5, 0))
        
        # Progress bar principal
        self.main_progress = ttk.Progressbar(
            main_frame,
            mode='determinate',
            length=560,
            maximum=100
        )
        self.main_progress.pack(fill=tk.X, pady=(0, 10))
        
        # Frame para download progress (inicialmente escondido)
        self.download_frame = tk.Frame(main_frame, bg='#2b2b2b')
        
        self.download_status_label = tk.Label(
            self.download_frame,
            text="",
            font=("Arial", 9),
            bg='#2b2b2b',
            fg='#aaaaaa',
            anchor='w'
        )
        self.download_status_label.pack(fill=tk.X, pady=(0, 5))
        
        self.download_progress = ttk.Progressbar(
            self.download_frame,
            mode='determinate',
            length=560,
            maximum=100
        )
        self.download_progress.pack(fill=tk.X)
        
        # Log/Console
        log_frame = tk.LabelFrame(
            main_frame,
            text="Log",
            font=("Arial", 9),
            bg='#2b2b2b',
            fg='#ffffff',
            padx=10,
            pady=10
        )
        log_frame.pack(fill=tk.BOTH, expand=True, pady=(0, 10))
        
        self.log_text = scrolledtext.ScrolledText(
            log_frame,
            height=10,
            width=70,
            wrap=tk.WORD,
            bg='#1e1e1e',
            fg='#ffffff',
            insertbackground='#ffffff',
            font=("Consolas", 9),
            state=tk.DISABLED
        )
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # Botões
        button_frame = tk.Frame(main_frame, bg='#2b2b2b')
        button_frame.pack(fill=tk.X, pady=(10, 0))
        
        self.check_button = tk.Button(
            button_frame,
            text="Verificar Atualizações",
            command=self.start_check,
            font=("Arial", 10),
            bg='#4a9eff',
            fg='#ffffff',
            activebackground='#3a8eef',
            activeforeground='#ffffff',
            relief=tk.FLAT,
            padx=20,
            pady=8,
            cursor='hand2'
        )
        self.check_button.pack(side=tk.LEFT, padx=(0, 10))
        
        self.launch_button = tk.Button(
            button_frame,
            text="Iniciar Jogo",
            command=self.launch_client,
            font=("Arial", 10),
            bg='#4caf50',
            fg='#ffffff',
            activebackground='#3c9f40',
            activeforeground='#ffffff',
            relief=tk.FLAT,
            padx=20,
            pady=8,
            state=tk.DISABLED,
            cursor='hand2'
        )
        self.launch_button.pack(side=tk.LEFT, padx=(0, 10))
        
        self.cancel_button = tk.Button(
            button_frame,
            text="Cancelar",
            command=self.cancel_check,
            font=("Arial", 10),
            bg='#f44336',
            fg='#ffffff',
            activebackground='#e43326',
            activeforeground='#ffffff',
            relief=tk.FLAT,
            padx=20,
            pady=8,
            state=tk.DISABLED,
            cursor='hand2'
        )
        self.cancel_button.pack(side=tk.LEFT)
        
        # Botão de atualizar (inicialmente escondido)
        self.update_button = tk.Button(
            button_frame,
            text="Atualizar Arquivos",
            command=self.start_download,
            font=("Arial", 10),
            bg='#ff9800',
            fg='#ffffff',
            activebackground='#e68900',
            activeforeground='#ffffff',
            relief=tk.FLAT,
            padx=20,
            pady=8,
            state=tk.DISABLED,
            cursor='hand2'
        )
        # Não empacota ainda, será mostrado quando necessário
        
    def log(self, message, level="info"):
        """Adiciona mensagem ao log"""
        colors = {
            "info": "#ffffff",
            "success": "#4caf50",
            "error": "#f44336",
            "warning": "#ff9800"
        }
        
        self.log_text.config(state=tk.NORMAL)
        
        # Adiciona timestamp
        timestamp = time.strftime("%H:%M:%S")
        prefix = f"[{timestamp}] "
        
        # Adiciona cor baseada no nível
        tag = f"color_{level}"
        self.log_text.tag_config(tag, foreground=colors.get(level, "#ffffff"))
        
        self.log_text.insert(tk.END, prefix, "timestamp")
        self.log_text.insert(tk.END, message + "\n", tag)
        self.log_text.see(tk.END)
        self.log_text.config(state=tk.DISABLED)
        
        self.root.update()
        
    def update_status(self, message, color="#ffffff"):
        """Atualiza a mensagem de status"""
        self.status_label.config(text=message, fg=color)
        self.log(message, "info")
        self.root.update()
        
    def update_main_progress(self, value):
        """Atualiza a barra de progresso principal"""
        self.main_progress['value'] = value
        self.root.update()
        
    def show_download_progress(self, show=True):
        """Mostra/esconde a barra de progresso de download"""
        if show:
            self.download_frame.pack(fill=tk.X, pady=(0, 10))
        else:
            self.download_frame.pack_forget()
            
    def update_download_progress(self, value, file="", speed=""):
        """Atualiza a barra de progresso de download"""
        self.download_progress['value'] = value
        if file:
            self.download_status_label.config(text=f"Baixando: {file} {speed}")
        self.root.update()
        
    def check_updates(self):
        """Verifica atualizações (GitHub ou API custom)"""
        if self.update_mode == "github":
            return self.check_updates_github()
        else:
            # Mantém código antigo para API custom
            return self.check_updates_custom()
    
    def check_updates_github(self):
        """Verifica atualizações usando GitHub API"""
        self.update_status("Verificando atualizações no GitHub...", "#4a9eff")
        self.update_main_progress(10)
        
        # URL da API do GitHub para releases
        api_url = f"{self.github_api}/repos/{self.github_repo}/releases/latest"
        
        self.log(f"Verificando releases em: {self.github_repo}", "info")
        self.log(f"URL da API: {api_url}", "info")
        
        try:
            # Cria requisição
            req = urllib.request.Request(
                api_url,
                headers={
                    'Accept': 'application/vnd.github.v3+json',
                    'User-Agent': 'NTO-Ascension-Launcher/1.0'
                }
            )
            
            # Faz requisição com timeout
            self.update_main_progress(30)
            response = urllib.request.urlopen(req, timeout=10)
            
            status_code = response.getcode()
            response_data = response.read().decode('utf-8')
            response.close()
            
            self.update_main_progress(60)
            self.log(f"Resposta recebida! Status: {status_code}", "success")
            
            # Verifica status
            if status_code != 200:
                self.update_status(f"Erro: Status {status_code}", "#f44336")
                self.log(f"Erro: {response_data[:200]}", "error")
                return None
            
            # Tenta parsear JSON
            try:
                release_data = json.loads(response_data)
                self.update_main_progress(80)
                self.log("Release encontrada!", "success")
                
                # Salva release
                self.latest_release = release_data
                
                # Extrai informações
                latest_version = release_data.get("tag_name", "").lstrip("v")
                release_name = release_data.get("name", "")
                
                self.log(f"Versão mais recente: {latest_version}", "info")
                self.log(f"Nome do release: {release_name}", "info")
                
                # Compara versões
                if self.compare_versions(self.app_version, latest_version) < 0:
                    self.log(f"⚠️  Nova versão disponível: {latest_version}", "warning")
                    self.log(f"Versão atual: {self.app_version}", "info")
                    
                    # Prepara dados de atualização
                    assets = release_data.get("assets", [])
                    self.log(f"Arquivos disponíveis: {len(assets)}", "info")
                    
                    # Cria estrutura similar à API antiga
                    update_data = {
                        "version": latest_version,
                        "release": release_data,
                        "assets": assets,
                        "url": release_data.get("zipball_url", ""),  # URL do ZIP do release
                        "files": {}  # Será preenchido se houver manifest
                    }
                    
                    # Lista assets disponíveis
                    for asset in assets:
                        self.log(f"  - {asset.get('name')} ({asset.get('size', 0) // 1024} KB)", "info")
                    
                    self.update_main_progress(100)
                    self.update_status(f"Nova versão disponível: {latest_version}", "#ff9800")
                    
                    return update_data
                else:
                    self.log("✅ Cliente está na versão mais recente!", "success")
                    self.update_main_progress(100)
                    self.update_status("Cliente está atualizado!", "#4caf50")
                    return None
                
            except json.JSONDecodeError as e:
                self.update_status("Erro ao parsear JSON", "#f44336")
                self.log(f"Erro ao parsear JSON: {e}", "error")
                self.log(f"Resposta: {response_data[:500]}", "error")
                return None
                    
        except urllib.error.HTTPError as e:
            if e.code == 404:
                self.update_status("Repositório não encontrado ou sem releases", "#f44336")
                self.log(f"Erro 404: Repositório '{self.github_repo}' não encontrado ou não tem releases", "error")
                self.log("Verifique se:", "warning")
                self.log("  1. O repositório existe e está público", "warning")
                self.log("  2. O nome está correto (formato: usuario/repositorio)", "warning")
                self.log("  3. Existe pelo menos um release no repositório", "warning")
            elif e.code == 403:
                self.update_status("Acesso negado ao repositório", "#f44336")
                self.log(f"Erro 403: Acesso negado ao repositório '{self.github_repo}'", "error")
                self.log("O repositório pode ser privado ou a API atingiu o limite de requisições", "warning")
            else:
                self.update_status(f"Erro HTTP {e.code}", "#f44336")
                self.log(f"Erro HTTP {e.code}: {e.reason}", "error")
            return None
        except urllib.error.URLError as e:
            if isinstance(e.reason, TimeoutError):
                self.update_status("Timeout: Servidor não respondeu", "#f44336")
                self.log("Timeout: Servidor não respondeu em 10 segundos", "error")
            else:
                self.update_status("Erro de conexão", "#f44336")
                self.log(f"Erro de conexão: {e}", "error")
                self.log("Verifique sua conexão com a internet", "warning")
            return None
        except Exception as e:
            self.update_status(f"Erro: {e}", "#f44336")
            self.log(f"Erro inesperado: {e}", "error")
            import traceback
            self.log(traceback.format_exc(), "error")
            return None
    
    def compare_versions(self, v1, v2):
        """Compara duas versões. Retorna -1 se v1 < v2, 0 se v1 == v2, 1 se v1 > v2"""
        def normalize_version(v):
            # Remove 'v' prefix e divide em partes
            v = str(v).lstrip('v').strip()
            parts = []
            for part in v.split('.'):
                try:
                    parts.append(int(part))
                except ValueError:
                    parts.append(0)
            # Preenche com zeros se necessário
            while len(parts) < 3:
                parts.append(0)
            return parts
        
        v1_parts = normalize_version(v1)
        v2_parts = normalize_version(v2)
        
        for i in range(max(len(v1_parts), len(v2_parts))):
            v1_part = v1_parts[i] if i < len(v1_parts) else 0
            v2_part = v2_parts[i] if i < len(v2_parts) else 0
            
            if v1_part < v2_part:
                return -1
            elif v1_part > v2_part:
                return 1
        
        return 0
    
    def check_updates_custom(self):
        """Verifica atualizações na API custom (código antigo)"""
        # Este método mantém a lógica antiga caso precise
        self.update_status("Verificando atualizações...", "#4a9eff")
        self.log("Modo custom não implementado. Use modo GitHub.", "warning")
        return None
            
    def get_checksum(self, filepath):
        """Calcula o checksum MD5 de um arquivo"""
        try:
            hash_md5 = hashlib.md5()
            with open(filepath, "rb") as f:
                for chunk in iter(lambda: f.read(4096), b""):
                    hash_md5.update(chunk)
            return hash_md5.hexdigest()
        except FileNotFoundError:
            return None
        except Exception as e:
            self.log(f"Erro ao calcular checksum de {filepath}: {e}", "error")
            return None
            
    def check_client(self):
        """Verifica se o cliente existe"""
        client_path = os.path.join(self.current_dir, self.client_exe)
        if os.path.exists(client_path):
            self.log(f"Cliente encontrado: {client_path}", "success")
            self.client_exists = True
            return True
        else:
            self.log(f"Cliente não encontrado: {self.client_exe}", "error")
            self.log(f"Caminho atual: {self.current_dir}", "warning")
            self.log(f"Procurando em: {client_path}", "warning")
            self.client_exists = False
            return False
            
    def compare_files(self, update_data):
        """Compara arquivos locais com os do servidor e retorna lista de arquivos para baixar"""
        if not update_data or "files" not in update_data or "url" not in update_data:
            return []
        
        self.download_url = update_data["url"]
        server_files = update_data.get("files", {})
        files_to_download = []
        
        self.log("Comparando arquivos locais com servidor...", "info")
        
        for filepath, server_checksum in server_files.items():
            # Remove barra inicial se houver
            local_path = filepath.lstrip('/')
            full_path = os.path.join(self.current_dir, local_path)
            
            # Calcula checksum local
            local_checksum = self.get_checksum(full_path)
            
            # Se arquivo não existe ou checksum é diferente, precisa baixar
            if local_checksum is None or local_checksum != server_checksum:
                files_to_download.append((filepath, server_checksum, local_path))
        
        # Verifica executável se necessário
        if "binary" in update_data and update_data["binary"]:
            binary_info = update_data["binary"]
            if binary_info.get("file"):
                binary_file = binary_info["file"]
                binary_checksum = binary_info.get("checksum")
                binary_path = os.path.join(self.current_dir, binary_file)
                
                local_binary_checksum = self.get_checksum(binary_path)
                if local_binary_checksum != binary_checksum:
                    files_to_download.append((binary_file, binary_checksum, binary_file))
        
        return files_to_download
        
    def download_file(self, url, filepath, expected_checksum, retries=5):
        """Baixa um arquivo com validação de checksum"""
        for attempt in range(retries):
            try:
                # Verifica se foi cancelado
                if not self.is_downloading:
                    return False
                
                if attempt > 0:
                    self.log(f"Tentativa {attempt + 1}/{retries}: {filepath}", "warning")
                
                # Cria diretório se não existir
                full_path = os.path.join(self.current_dir, filepath)
                os.makedirs(os.path.dirname(full_path), exist_ok=True)
                
                # Baixa arquivo
                req = urllib.request.Request(url)
                req.add_header('User-Agent', 'NTO-Ascension-Launcher/1.0')
                
                with urllib.request.urlopen(req, timeout=30) as response:
                    # Verifica status code
                    if response.getcode() != 200:
                        raise Exception(f"HTTP {response.getcode()}: {response.reason}")
                    
                    total_size = int(response.headers.get('content-length', 0))
                    downloaded = 0
                    
                    with open(full_path, 'wb') as f:
                        while True:
                            if not self.is_downloading:
                                if os.path.exists(full_path):
                                    os.remove(full_path)
                                return False
                            
                            chunk = response.read(8192)
                            if not chunk:
                                break
                            f.write(chunk)
                            downloaded += len(chunk)
                            
                            # Atualiza progresso
                            if total_size > 0:
                                progress = (downloaded / total_size) * 100
                                speed = f"({downloaded // 1024} KB)"
                                self.update_download_progress(progress, os.path.basename(filepath), speed)
                
                # Valida checksum
                if expected_checksum:
                    actual_checksum = self.get_checksum(full_path)
                    if actual_checksum != expected_checksum:
                        # Verifica se o arquivo baixado é HTML (pode ser página de erro)
                        try:
                            with open(full_path, 'rb') as f:
                                first_bytes = f.read(100)
                                if b'<html' in first_bytes.lower() or b'<!doctype' in first_bytes.lower():
                                    self.log(f"Arquivo baixado parece ser HTML (página de erro?)", "error")
                                    # Lê um pouco mais para ver o erro
                                    f.seek(0)
                                    content = f.read(500).decode('utf-8', errors='ignore')
                                    self.log(f"Conteúdo: {content[:200]}...", "error")
                        except:
                            pass
                        
                        self.log(f"Checksum inválido! Esperado: {expected_checksum}, Obtido: {actual_checksum if actual_checksum else 'None'}", "error")
                        self.log(f"Tamanho do arquivo: {os.path.getsize(full_path) if os.path.exists(full_path) else 0} bytes", "error")
                        if os.path.exists(full_path):
                            os.remove(full_path)
                        if attempt < retries - 1:
                            time.sleep(1)
                            continue
                        return False
                
                self.log(f"Arquivo baixado: {filepath}", "success")
                return True
                
            except urllib.error.URLError as e:
                self.log(f"Erro ao baixar {filepath}: {e}", "error")
                full_path = os.path.join(self.current_dir, filepath)
                if os.path.exists(full_path):
                    os.remove(full_path)
                if attempt < retries - 1:
                    time.sleep(1)
                    continue
                return False
            except Exception as e:
                self.log(f"Erro inesperado ao baixar {filepath}: {e}", "error")
                full_path = os.path.join(self.current_dir, filepath)
                if os.path.exists(full_path):
                    os.remove(full_path)
                if attempt < retries - 1:
                    time.sleep(1)
                    continue
                return False
        
        return False
        
    def download_files(self, files_to_download):
        """Baixa múltiplos arquivos com progresso"""
        if not files_to_download:
            return True
        
        total_files = len(files_to_download)
        self.log(f"Iniciando download de {total_files} arquivos...", "info")
        self.show_download_progress(True)
        
        if self.update_mode == "github":
            # Modo GitHub: baixa assets do release
            for i, asset in enumerate(files_to_download, 1):
                # Verifica se foi cancelado
                if not self.is_downloading:
                    self.log("Download cancelado pelo usuário", "warning")
                    return False
                
                # Atualiza progresso principal
                main_progress = (i / total_files) * 100
                self.update_main_progress(main_progress)
                
                # Extrai informações do asset
                asset_name = asset.get("name", "")
                download_url = asset.get("browser_download_url", "")
                asset_size = asset.get("size", 0)
                
                self.log(f"[{i}/{total_files}] Baixando: {asset_name} ({asset_size // 1024} KB)", "info")
                self.log(f"URL: {download_url}", "info")
                
                # Baixa arquivo
                if not self.download_file_github(download_url, asset_name):
                    self.log(f"Falha ao baixar: {asset_name}", "error")
                    return False
        else:
            # Modo custom: baixa arquivos individuais
            for i, (filepath, checksum, local_path) in enumerate(files_to_download, 1):
                # Verifica se foi cancelado
                if not self.is_downloading:
                    self.log("Download cancelado pelo usuário", "warning")
                    return False
                
                # Atualiza progresso principal
                main_progress = (i / total_files) * 100
                self.update_main_progress(main_progress)
                
                # Monta URL completa
                url = self.download_url.rstrip('/') + filepath
                
                # Log para debug
                self.log(f"[{i}/{total_files}] Baixando: {filepath}", "info")
                self.log(f"URL: {url}", "info")
                
                # Baixa arquivo
                if not self.download_file(url, local_path, checksum):
                    self.log(f"Falha ao baixar: {filepath}", "error")
                    return False
        
        self.show_download_progress(False)
        self.update_main_progress(100)
        self.log(f"Todos os {total_files} arquivo(s) foram baixados com sucesso!", "success")
        return True
    
    def download_file_github(self, url, filename):
        """Baixa um arquivo do GitHub (sem validação de checksum)"""
        try:
            # Cria diretório se não existir
            full_path = os.path.join(self.current_dir, filename)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)
            
            # Baixa arquivo
            req = urllib.request.Request(url)
            req.add_header('User-Agent', 'NTO-Ascension-Launcher/1.0')
            req.add_header('Accept', 'application/octet-stream')
            
            with urllib.request.urlopen(req, timeout=60) as response:
                if response.getcode() != 200:
                    raise Exception(f"HTTP {response.getcode()}: {response.reason}")
                
                total_size = int(response.headers.get('content-length', 0))
                downloaded = 0
                
                with open(full_path, 'wb') as f:
                    while True:
                        if not self.is_downloading:
                            if os.path.exists(full_path):
                                os.remove(full_path)
                            return False
                        
                        chunk = response.read(8192)
                        if not chunk:
                            break
                        f.write(chunk)
                        downloaded += len(chunk)
                        
                        # Atualiza progresso
                        if total_size > 0:
                            progress = (downloaded / total_size) * 100
                            speed = f"({downloaded // 1024} KB)"
                            self.update_download_progress(progress, filename, speed)
                
                self.log(f"Arquivo baixado: {filename}", "success")
                return True
                
        except Exception as e:
            self.log(f"Erro ao baixar {filename}: {e}", "error")
            full_path = os.path.join(self.current_dir, filename)
            if os.path.exists(full_path):
                os.remove(full_path)
            return False
            
    def launch_client(self):
        """Executa o cliente"""
        client_path = os.path.join(self.current_dir, self.client_exe)
        
        if not os.path.exists(client_path):
            messagebox.showerror("Erro", f"{self.client_exe} não encontrado!\n\nCaminho: {client_path}")
            self.log(f"Tentativa de executar cliente que não existe: {client_path}", "error")
            return False
        
        self.update_status("Iniciando cliente...", "#4caf50")
        self.log(f"Executando: {client_path}", "info")
        
        try:
            # Configura para não mostrar janela de console no Windows
            startupinfo = None
            if sys.platform == 'win32':
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startupinfo.wShowWindow = subprocess.SW_HIDE
            
            # Muda para o diretório do cliente antes de executar
            subprocess.Popen(
                [client_path],
                cwd=self.current_dir,
                startupinfo=startupinfo,
                creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == 'win32' else 0
            )
            self.update_status("Cliente iniciado com sucesso!", "#4caf50")
            self.log("Cliente iniciado!", "success")
            
            # Fecha após 2 segundos
            self.root.after(2000, self.root.destroy)
            return True
        except Exception as e:
            messagebox.showerror("Erro", f"Erro ao executar cliente: {e}")
            self.log(f"Erro ao executar cliente: {e}", "error")
            return False
            
    def start_check(self):
        """Inicia verificação de atualizações em thread separada"""
        if self.is_checking:
            return
            
        self.is_checking = True
        self.check_button.config(state=tk.DISABLED)
        self.launch_button.config(state=tk.DISABLED)
        self.cancel_button.config(state=tk.NORMAL)
        self.update_main_progress(0)
        self.show_download_progress(False)
        
        def check_thread():
            try:
                # Verifica se foi cancelado
                if not self.is_checking:
                    return
                
                # Verifica cliente primeiro
                client_exists = self.check_client()
                
                # Verifica se foi cancelado
                if not self.is_checking:
                    return
                
                # Verifica atualizações
                self.update_data = self.check_updates()
                
                # Verifica se foi cancelado
                if not self.is_checking:
                    return
                
                # Habilita botão de iniciar se cliente existe
                if client_exists:
                    self.launch_button.config(state=tk.NORMAL)
                    self.log("Cliente encontrado! Você pode iniciar o jogo.", "success")
                else:
                    self.log("Cliente não encontrado. Verifique se está no diretório correto.", "warning")
                
                # Prepara lista de downloads baseado no modo
                if self.update_data:
                    if self.update_mode == "github":
                        # Modo GitHub: prepara download de assets
                        assets = self.update_data.get("assets", [])
                        if assets:
                            self.files_to_download = assets
                            file_count = len(assets)
                            self.log(f"⚠️  {file_count} arquivo(s) disponível(is) para download!", "warning")
                            self.log("💡 Clique em 'Atualizar Arquivos' para baixar as atualizações.", "info")
                            
                            # Mostra botão de atualizar
                            self.update_button.pack(side=tk.LEFT, padx=(0, 10))
                            self.update_button.config(state=tk.NORMAL)
                        else:
                            self.log("✅ Cliente está atualizado!", "success")
                    else:
                        # Modo custom: compara arquivos
                        self.files_to_download = self.compare_files(self.update_data)
                        
                        if self.files_to_download:
                            file_count = len(self.files_to_download)
                            self.log(f"⚠️  ATENÇÃO: {file_count} arquivos precisam ser atualizados!", "warning")
                            self.log("💡 Clique em 'Atualizar Arquivos' para baixar as atualizações.", "info")
                            
                            # Mostra botão de atualizar
                            self.update_button.pack(side=tk.LEFT, padx=(0, 10))
                            self.update_button.config(state=tk.NORMAL)
                        else:
                            self.log("✅ Cliente está atualizado!", "success")
                        
            except Exception as e:
                if self.is_checking:  # Só mostra erro se não foi cancelado
                    self.log(f"Erro durante verificação: {e}", "error")
                    messagebox.showerror("Erro", f"Erro durante verificação: {e}")
            finally:
                self.is_checking = False
                self.check_button.config(state=tk.NORMAL)
                self.cancel_button.config(state=tk.DISABLED)
                
        threading.Thread(target=check_thread, daemon=True).start()
        
    def start_download(self):
        """Inicia download de arquivos"""
        if self.is_downloading:
            return
        
        if not self.files_to_download:
            messagebox.showinfo("Info", "Não há arquivos para atualizar!")
            return
        
        # Pergunta confirmação
        file_count = len(self.files_to_download)
        if not messagebox.askyesno("Confirmar", f"Deseja baixar {file_count} arquivos?"):
            return
        
        self.is_downloading = True
        self.is_checking = False
        self.check_button.config(state=tk.DISABLED)
        self.launch_button.config(state=tk.DISABLED)
        self.update_button.config(state=tk.DISABLED)
        self.cancel_button.config(state=tk.NORMAL)
        self.update_main_progress(0)
        
        def download_thread():
            try:
                success = self.download_files(self.files_to_download)
                
                if success:
                    self.update_status("Todos os arquivos foram atualizados!", "#4caf50")
                    messagebox.showinfo("Sucesso", f"Todos os {file_count} arquivos foram atualizados com sucesso!")
                    # Limpa lista de arquivos para download
                    self.files_to_download = []
                    self.update_button.pack_forget()
                else:
                    self.update_status("Erro ao atualizar arquivos", "#f44336")
                    messagebox.showerror("Erro", "Erro ao atualizar arquivos. Verifique o log para mais detalhes.")
                    
            except Exception as e:
                self.log(f"Erro durante download: {e}", "error")
                messagebox.showerror("Erro", f"Erro durante download: {e}")
            finally:
                self.is_downloading = False
                self.check_button.config(state=tk.NORMAL)
                self.cancel_button.config(state=tk.DISABLED)
                if self.client_exists:
                    self.launch_button.config(state=tk.NORMAL)
                if self.files_to_download:
                    self.update_button.config(state=tk.NORMAL)
        
        threading.Thread(target=download_thread, daemon=True).start()
        
    def cancel_check(self):
        """Cancela a verificação ou download"""
        if self.is_downloading:
            self.is_downloading = False
            self.update_status("Download cancelado", "#ff9800")
            self.log("Download cancelado pelo usuário", "warning")
        elif self.is_checking:
            self.is_checking = False
            self.update_status("Verificação cancelada", "#ff9800")
            self.log("Verificação cancelada pelo usuário", "warning")
        else:
            return
        
        self.check_button.config(state=tk.NORMAL)
        self.cancel_button.config(state=tk.DISABLED)
        self.update_main_progress(0)
        self.show_download_progress(False)
        
        # Habilita botão de iniciar se cliente existe
        if self.client_exists:
            self.launch_button.config(state=tk.NORMAL)
        if self.files_to_download:
            self.update_button.config(state=tk.NORMAL)

def main():
    """Função principal"""
    root = tk.Tk()
    app = LauncherGUI(root)
    
    # Fechar corretamente
    def on_closing():
        if app.is_checking or app.is_downloading:
            if messagebox.askokcancel("Sair", "Operação em andamento. Deseja realmente sair?"):
                root.destroy()
        else:
            root.destroy()
    
    root.protocol("WM_DELETE_WINDOW", on_closing)
    root.mainloop()

if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Erro: {e}")
        import traceback
        traceback.print_exc()

