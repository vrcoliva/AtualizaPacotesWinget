# Força a saída em UTF-8 para evitar problemas com acentuação
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Funcao para verificar privilegios administrativos
function VerificarPrivilegios {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

	if (!$isAdmin) {
		Write-Warning "`n🔐 O script não está sendo executado com privilégios administrativos.`nPor favor, feche este terminal e abra-o novamente como administrador."
		Start-Sleep -Seconds 3
		Exit
	}
	
	Write-Host "🔓 O script esta sendo executado com privilegios administrativos."
}

# Funcao para verificar e ajustar a politica de execução
function VerificarPolitica {
    $currentPolicy = Get-ExecutionPolicy

    if ($currentPolicy -eq "RemoteSigned" -or $currentPolicy -eq "Unrestricted") {
        Write-Host "🛡️ A política de execução ja é adequada: $currentPolicy.`n"
        return
    }

	Write-Host "🛡️ Politica de execução atual: $currentPolicy. Alterando para RemoteSigned..."
	Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

	if (!$?) {
		Write-Error "`n❌ Falha ao alterar a política de execução. O script será encerrado.`n"
		Start-Sleep -Seconds 3
		Exit
	}

	Write-Host "`n🛡️ Política de execução alterada para RemoteSigned.`n"
}

# Verifica se o winget está instalado
$version = winget --version
function VerificarWinget {
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "`n❌ O comando winget não está instalado. Instale-o via Microsoft Store ou atualize o Windows.`n" -ForegroundColor Red
        Pause
        exit 1
    }
	Write-Host "🌎 O Winget se encontra na versão '$version'"
	Start-Sleep -Seconds 4
	Clear-Host
}

# Função para verificar atualizações via winget
function VerificarAtualizacoes {
    Write-Host "`n🔍 Verificando aplicativos com atualizações disponíveis...`n" -ForegroundColor Cyan
    try {
        winget upgrade --disable-interactivity
    }
    catch {
        Write-Host "❌ Ocorreu um erro ao verificar atualizações com o winget:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
    }
}

# Função para obter os IDs dos pacotes com atualização disponível
function ObterIds {
    try {
        $linhas = winget upgrade | findstr /v "^[-\\]" | findstr /v "^$"

        $regexId = '[\w\-\+\.]*[a-zA-Z][\w\-\+\.]*[.-]([\w\+]{3,}(?:[.-]\w+)*)'

        $ids = $linhas | ForEach-Object {
            if ($_ -match $regexId) {
                $matches[0]
            }
        }

        return $ids
    }
    catch {
        Write-Host "❌ Ocorreu um erro ao obter os IDs:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
        return @()
    }
}

# Função para instalar um novo pacote via winget
function InstalarPacote {
    $packageName = Read-Host "Digite o nome do pacote que deseja instalar (ex: Notepad++)"
    
    if ([string]::IsNullOrWhiteSpace($packageName)) {
        Write-Host "`n❌ Nenhum nome foi inforamdo. Tente novamente." -ForegroundColor Red
        return
    }

    Write-Host "`n🔍 Buscando pacotes com '$packageName' no winget..." -ForegroundColor Cyan
    winget search $packageName --disable-interactivity --count 10

    $idEscolhido = Read-Host "`nDigite o ID do pacote que deseja instalar"

    if ([string]::IsNullOrWhiteSpace($idEscolhido)) {
        Write-Host "`n❌ Nenhum ID foi informado. Tente novamente." -ForegroundColor Red
        return
    }

    Write-Host "`n📥 Instalando pacote '$idEscolhido' via winget..." -ForegroundColor Cyan
    Start-Process winget -ArgumentList "install --id $idEscolhido --disable-interactivity --accept-package-agreements -h" -NoNewWindow -Wait
}

# Função para atualizar um ou mais pacotes via winget
function AtualizarPacote {
    VerificarAtualizacoes

    $idsInput = Read-Host "`nDigite os IDs dos aplicativos que deseja atualizar (separados por ';')"

    if ([string]::IsNullOrWhiteSpace($idsInput)) {
        Write-Host "❌ Nenhum ID informado. Operação cancelada." -ForegroundColor Red
        return
    }

    $idsSelecionados = $idsInput -split ";" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    Write-Host "`n🔄 Atualizando pacotes via winget..." -ForegroundColor Cyan

    foreach ($id in $idsSelecionados) {
        Write-Host "`n🔄 Atualizando $id..." -ForegroundColor Cyan
        Start-Process winget -ArgumentList "upgrade --id $id --disable-interactivity --accept-package-agreements -h" -NoNewWindow -Wait -PassThru
    }
}

# Função para atualizar todos os pacotes, exceto os informados
function AtualizarTudoExceto {
    VerificarAtualizacoes

    $excecoesInput = Read-Host "Digite os IDs dos aplicativos que NÃO devem ser atualizados (separados por ';' ou deixe em branco para atualizar tudo)"
    
    $excecoes = @()
    if ($excecoesInput) {
        $excecoes = $excecoesInput -split ";" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    }

    Write-Host "`n🔄 Atualizando pacotes via winget..." -ForegroundColor Cyan
    try {
        $ids = ObterIds

        foreach ($id in $ids) {
            if ($excecoes -contains $id) {
                Write-Host "`n⏭️ Pulando atualização de $id conforme solicitado." -ForegroundColor Yellow
                continue
            }

            Write-Host "`n🔄 Atualizando $id..." -ForegroundColor Cyan
            Start-Process winget -ArgumentList "upgrade --id $id --disable-interactivity --accept-package-agreements -h" -NoNewWindow -Wait
        }
    }
    catch {
        Write-Host "❌ Ocorreu um erro durante a atualização:" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor DarkRed
    }
}

# Menu interativo
function ExibirMenu {
    do {
        Write-Host "📦 GERENCIADOR DE APLICATIVOS (winget '$version')" -ForegroundColor Cyan
        Write-Host "1. Verificar atualizações"
        Write-Host "2. Atualizar um ou mais pacotes"
        Write-Host "3. Instalar um novo pacote"
        Write-Host "4. Atualizar tudo exceto pacotes selecionados"
        Write-Host "0. Sair"
        $opcao = Read-Host "`nEscolha uma opção"

        switch ($opcao) {
            "1" { VerificarAtualizacoes }
            "2" { AtualizarPacote }
            "3" { InstalarPacote }
            "4" { AtualizarTudoExceto }
            "0" {
                Write-Host "`n👋 Encerrando o script...`n" -ForegroundColor Magenta
                break
            }
            default {
                Write-Host "❌ Opção inválida. Tente novamente." -ForegroundColor Red
            }
        }

        if ($opcao -ne "0") {
            Write-Host "`nPressione qualquer tecla para voltar ao menu...`n"
            $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            Clear-Host
        }
    } while ($opcao -ne "0")
}

# ----------- Ponto de entrada do script -----------
Clear-Host
VerificarPrivilegios
VerificarPolitica
VerificarWinget
ExibirMenu
