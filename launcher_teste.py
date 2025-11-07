"""
Launcher Simples para Teste - NTO Ascension
Versão básica apenas para testar conexão com API
Usa apenas bibliotecas padrão do Python (sem dependências externas)
"""

import urllib.request
import urllib.parse
import json
import os
import subprocess
import sys
import platform

# Configurações
APP_NAME = "NTO Ascension"
APP_VERSION = 1337
UPDATER_API = "https://ntoascension.com/api/updatermobile.php"
CLIENT_EXE = "otclient_dx.exe"

def print_header():
    """Imprime cabeçalho"""
    print("=" * 50)
    print(f"  {APP_NAME} - Launcher de Teste")
    print("=" * 50)
    print()

def check_updates():
    """Verifica atualizações na API"""
    print("📡 Verificando atualizações...")
    print(f"   API: {UPDATER_API}")
    print(f"   Versão: {APP_VERSION}")
    print()
    
    # Prepara payload
    payload = {
        "version": APP_VERSION,
        "build": "1.0.0",
        "os": platform.system().lower(),
        "platform": platform.platform(),
        "args": {}
    }
    
    print("📤 Enviando requisição...")
    print(f"   Payload: {json.dumps(payload, indent=2)}")
    print()
    
    try:
        # Converte payload para JSON
        json_data = json.dumps(payload).encode('utf-8')
        
        # Cria requisição
        req = urllib.request.Request(
            UPDATER_API,
            data=json_data,
            headers={
                'Content-Type': 'application/json',
                'User-Agent': 'NTO-Ascension-Launcher/1.0'
            }
        )
        
        # Faz requisição com timeout
        print("⏳ Aguardando resposta...")
        with urllib.request.urlopen(req, timeout=10) as response:
            status_code = response.getcode()
            response_data = response.read().decode('utf-8')
            
            print(f"📥 Resposta recebida!")
            print(f"   Status Code: {status_code}")
            print()
            
            # Verifica status
            if status_code != 200:
                print(f"❌ Erro: Status {status_code}")
                print(f"   Resposta: {response_data[:200]}")
                return None
            
            # Tenta parsear JSON
            try:
                data = json.loads(response_data)
                print("✅ JSON válido recebido!")
                print()
                print("📋 Conteúdo da resposta:")
                print(json.dumps(data, indent=2, ensure_ascii=False))
                print()
                
                # Analisa resposta
                if "error" in data and data["error"]:
                    print(f"⚠️  Erro do servidor: {data['error']}")
                    return data
                
                if "files" in data:
                    file_count = len(data["files"])
                    print(f"📁 Arquivos na resposta: {file_count}")
                    
                    if file_count > 0:
                        print("\n   Primeiros arquivos:")
                        for i, (filepath, checksum) in enumerate(list(data["files"].items())[:5]):
                            print(f"   - {filepath} ({checksum[:8]}...)")
                        if file_count > 5:
                            print(f"   ... e mais {file_count - 5} arquivos")
                
                if "url" in data:
                    print(f"\n🌐 URL de download: {data['url']}")
                
                if "binary" in data:
                    print(f"\n💻 Executável: {data['binary']}")
                
                return data
                
            except json.JSONDecodeError as e:
                print(f"❌ Erro ao parsear JSON: {e}")
                print(f"   Resposta recebida: {response_data[:500]}")
                return None
                
    except urllib.error.URLError as e:
        if isinstance(e.reason, TimeoutError):
            print("❌ Timeout: Servidor não respondeu em 10 segundos")
        else:
            print(f"❌ Erro de conexão: {e}")
            print("   Verifique sua conexão com a internet")
        return None
    except Exception as e:
        print(f"❌ Erro na requisição: {e}")
        import traceback
        traceback.print_exc()
        return None

def check_client():
    """Verifica se o cliente existe"""
    print("🔍 Verificando cliente...")
    
    if os.path.exists(CLIENT_EXE):
        print(f"✅ Cliente encontrado: {CLIENT_EXE}")
        return True
    else:
        print(f"❌ Cliente não encontrado: {CLIENT_EXE}")
        print(f"   Caminho atual: {os.getcwd()}")
        return False

def run_client():
    """Executa o cliente"""
    print()
    print("🚀 Iniciando cliente...")
    
    try:
        subprocess.Popen([CLIENT_EXE])
        print(f"✅ Cliente iniciado: {CLIENT_EXE}")
        return True
    except Exception as e:
        print(f"❌ Erro ao executar cliente: {e}")
        return False

def main():
    """Função principal"""
    print_header()
    
    # 1. Verifica atualizações
    update_data = check_updates()
    
    print()
    print("-" * 50)
    print()
    
    # 2. Verifica cliente
    client_exists = check_client()
    
    print()
    print("-" * 50)
    print()
    
    # 3. Pergunta se quer executar
    if client_exists:
        print("❓ Deseja executar o cliente? (s/n): ", end="")
        try:
            resposta = input().strip().lower()
            if resposta in ['s', 'sim', 'y', 'yes']:
                run_client()
            else:
                print("⏭️  Cliente não será executado")
        except KeyboardInterrupt:
            print("\n\n⏹️  Cancelado pelo usuário")
    else:
        print("⚠️  Cliente não encontrado, não é possível executar")
    
    print()
    print("=" * 50)
    print("  Teste concluído!")
    print("=" * 50)
    
    # Aguarda antes de fechar
    try:
        input("\nPressione Enter para sair...")
    except KeyboardInterrupt:
        pass

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⏹️  Interrompido pelo usuário")
        sys.exit(0)
    except Exception as e:
        print(f"\n❌ Erro inesperado: {e}")
        import traceback
        traceback.print_exc()
        input("\nPressione Enter para sair...")
