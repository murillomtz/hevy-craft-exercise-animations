$lista = 'C:\Users\Murillo\.codex\attachments\314d771b-bdd3-4e3e-993a-49e24438d62c\Texto colado.txt'
$pastaDestino = 'C:\MTZ\DESENVOLVIMENTO\Hevy clone\Animacoes Execicios'

New-Item -ItemType Directory -Path $pastaDestino -Force | Out-Null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$linhas = Get-Content -LiteralPath $lista -Encoding UTF8
$total = $linhas.Count
$baixados = 0
$existentes = 0
$falhas = 0
$nomesUsados = @{}

$cliente = New-Object System.Net.WebClient

try {
    for ($i = 0; $i -lt $total; $i++) {
        $linha = $linhas[$i]
        $numero = $i + 1

        if ([string]::IsNullOrWhiteSpace($linha)) {
            continue
        }

        if ($linha -notmatch '^\s*(.+?)\s*:\s*(https?://\S+)\s*$') {
            Write-Warning "Linha $numero ignorada: formato inválido."
            $falhas++
            continue
        }

        $nome = $Matches[1].Trim()
        $url = $Matches[2]

        $nomeSeguro = $nome -replace '[<>:"/\\|?*\x00-\x1F]', '_'
        $nomeSeguro = $nomeSeguro.TrimEnd(' ', '.')

        if ([string]::IsNullOrWhiteSpace($nomeSeguro)) {
            $nomeSeguro = "exercicio_$numero"
        }

        if ($nomeSeguro.Length -gt 150) {
            $nomeSeguro = $nomeSeguro.Substring(0, 150).TrimEnd(' ', '.')
        }

        # Nomes repetidos na lista recebem sufixos estáveis.
        if ($nomesUsados.ContainsKey($nomeSeguro)) {
            $nomesUsados[$nomeSeguro]++
            $nomeArquivo = "$nomeSeguro ($($nomesUsados[$nomeSeguro])).mp4"
        }
        else {
            $nomesUsados[$nomeSeguro] = 1
            $nomeArquivo = "$nomeSeguro.mp4"
        }

        $arquivo = Join-Path $pastaDestino $nomeArquivo

        if (Test-Path -LiteralPath $arquivo) {
            Write-Host "[$numero/$total] Já existe: $nomeArquivo"
            $existentes++
            continue
        }

        $temporario = Join-Path $pastaDestino ("download-" + [guid]::NewGuid().ToString() + ".tmp")

        try {
            Write-Host "[$numero/$total] Baixando: $nome"
            $cliente.DownloadFile($url, $temporario)

            # Não substitui um arquivo criado enquanto o download ocorria.
            [System.IO.File]::Move($temporario, $arquivo)
            $baixados++
        }
        catch {
            $falhas++
            Write-Warning "Falha ao baixar '$nome': $($_.Exception.Message)"
        }
        finally {
            if (Test-Path -LiteralPath $temporario) {
                Remove-Item -LiteralPath $temporario -Force
            }
        }
    }
}
finally {
    $cliente.Dispose()
}

Write-Host ""
Write-Host "Baixados nesta execução: $baixados"
Write-Host "Já existentes: $existentes"
Write-Host "Falhas ou linhas inválidas: $falhas"
Write-Host "Destino: $pastaDestino"