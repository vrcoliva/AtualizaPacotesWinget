# Força a saída em UTF-8 para evitar problemas com acentuação
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Verifica se o winget está instalado
function VerificarWinget {
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "❌ O comando winget não está instalado. Instale-o via Microsoft Store ou atualize o Windows.`n" -ForegroundColor Red
        Pause
        exit 1
    }
}

# Função para verificar atualizações via winget
function VerificarAtualizacoes {
    Write-Host "`n🔍 Verificando atualizações via winget..." -ForegroundColor Cyan
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
    Write-Host "`n🔍 Obtendo lista de aplicativos com atualização disponível..." -ForegroundColor Cyan
    
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
        Write-Host "❌ Nome do pacote inválido. Tente novamente." -ForegroundColor Red
        return
    }

    Write-Host "`n🔍 Buscando pacotes com '$packageName' no winget..." -ForegroundColor Cyan
    winget search $packageName --disable-interactivity --count 10

    $idEscolhido = Read-Host "`nDigite o ID do pacote que deseja instalar"

    if ([string]::IsNullOrWhiteSpace($idEscolhido)) {
        Write-Host "❌ ID inválido. Tente novamente." -ForegroundColor Red
        return
    }

    Write-Host "`n📥 Instalando pacote '$idEscolhido' via winget..." -ForegroundColor Cyan
    Start-Process winget -ArgumentList "install --id $idEscolhido --disable-interactivity --accept-package-agreements -h" -NoNewWindow -Wait
}

# Função para atualizar um ou mais pacotes via winget
function AtualizarPacote {
    Write-Host "`n🔍 Verificando aplicativos com atualização disponível..." -ForegroundColor Cyan
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
                Write-Host "⏭️ Pulando atualização de $id conforme solicitado." -ForegroundColor Yellow
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
        Write-Host "📦 GERENCIADOR DE APLICATIVOS (winget)" -ForegroundColor Cyan
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
                Write-Host "`n👋 Encerrando script...`n" -ForegroundColor Magenta
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
VerificarWinget
ExibirMenu
