# --------------------------------------------
# Nome do Script: AtualizaPacotesWinget.ps1
# Versao: 1.0
# Autor: Vitor Colivati
# Descricao: Este script atualiza pacotes usando o winget, com opcoes de exclusao de determinados pacotes.
# --------------------------------------------

# Funcao para verificar privilegios administrativos
function Check-Admin {
    <#
    .SYNOPSIS
    Verifica se o script esta sendo executado com privilegios administrativos.

    .DESCRIPTION
    Verifica se o script esta sendo executado com privilegios administrativos. Se nao estiver,
    exibe uma mensagem informando que o script precisa de privilegios elevados.

    .NOTES
    Autor: Vitor Colivati
    Versao: 1.0
    #>
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

    if ($isAdmin) {
        Write-InfoMessage "O script esta sendo executado com privilegios administrativos."
    } else {
        Write-InfoMessage "O script nao esta sendo executado com privilegios administrativos."
        Write-InfoMessage "Por favor, reinicie o script como administrador para executar todas as operacoes."
    }
}

# Defina a lista de excecoes
$excecoes = @("OpenVPNTechnologies.OpenVPN", "Microsoft.Edge")

# Funcao para exibir mensagens verbose
function Write-VerboseMessage {
    <#
    .SYNOPSIS
    Exibe uma mensagem verbose.

    .DESCRIPTION
    Exibe uma mensagem verbose no console. Usado para fornecer informacoes detalhadas sobre a execucao do script.

    .PARAMETER message
    A mensagem a ser exibida no console.
    
    .NOTES
    Autor: Vitor Colivati
    Versao: 1.0
    #>
    param (
        [string]$message
    )
    Write-Host "[INFO] $message"
}

# Funcao para exibir mensagens de erro
function Write-ErrorMessage {
    <#
    .SYNOPSIS
    Exibe uma mensagem de erro.

    .DESCRIPTION
    Exibe uma mensagem de erro no console. Usado para informar problemas ou falhas na execucao do script.

    .PARAMETER message
    A mensagem de erro a ser exibida no console.
    
    .NOTES
    Autor: Vitor Colivati
    Versao: 1.0
    #>
    param (
        [string]$message
    )
    Write-Host "[ERROR] $message" -ForegroundColor Red
}

# Funcao para exibir mensagens de informacao
function Write-InfoMessage {
    <#
    .SYNOPSIS
    Exibe uma mensagem de informacao.

    .DESCRIPTION
    Exibe uma mensagem de informacao no console. Usado para fornecer informacoes gerais durante a execucao do script.

    .PARAMETER message
    A mensagem de informacao a ser exibida no console.
    
    .NOTES
    Autor: Vitor Colivati
    Versao: 1.0
    #>
    param (
        [string]$message
    )
    Write-Host "[INFO] $message" -ForegroundColor Yellow
}

# Funcao para executar a atualizacao
function Atualizar-Pacotes {
    <#
    .SYNOPSIS
    Atualiza pacotes usando o winget.

    .DESCRIPTION
    Executa o comando winget upgrade, extrai os IDs dos pacotes a serem atualizados,
    exclui os pacotes na lista de excecoes e executa o comando winget upgrade para cada pacote elegivel.

    .PARAMETER excecoes
    Uma lista de IDs de pacotes que nao devem ser atualizados.
    
    .NOTES
    Autor: Vitor Colivati
    Versao: 1.0
    #>
    param (
        [string[]]$excecoes
    )

    # Verifique se o comando winget esta instalado
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-ErrorMessage "O comando winget nao esta instalado."
        return
    }

    # Execute o comando winget upgrade
    Write-VerboseMessage "Executando winget upgrade..."
    $resultados = winget upgrade

    # Extrai os IDs dos pacotes, excluindo o cabecalho e a lista de excecoes
    Write-VerboseMessage "Extraindo IDs dos pacotes..."
    $ids = ($resultados | Select-String -Pattern '^(?!Nome).*?\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$').Matches |
        ForEach-Object { $_.Groups[1].Value } | Where-Object { -not ($excecoes -contains $_) }

    if ($ids.Count -eq 0) {
        Write-InfoMessage "Nenhum pacote elegivel para atualizacao foi encontrado."
        return
    }

    # Inicializa contador de pacotes atualizados
    $count = 0

    # Execute o comando winget upgrade para cada ID que nao esteja na lista de excecoes
    foreach ($id in $ids) {
        try {
            Write-VerboseMessage "Atualizando pacote com ID: $id"
            winget upgrade --id $id --accept-package-agreements
            $count++
        }
        catch {
            Write-ErrorMessage "Falha ao atualizar pacote com ID: $id. Erro: $_"
        }
    }

    # Retorne o contador
    return $count
}

# Verifique se o script esta sendo executado com privilegios administrativos
Check-Admin

# Execute a funcao principal e obtenha o numero de pacotes atualizados
$pacotesAtualizados = Atualizar-Pacotes -excecoes $excecoes

# Mensagem final
Write-VerboseMessage "Todas as atualizacoes concluidas. $pacotesAtualizados pacotes foram atualizados."
Write-InfoMessage "Pacotes excluidos da atualizacao: $($excecoes -join ', '). Pressione qualquer tecla para sair."
Pause
