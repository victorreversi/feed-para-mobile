<# :
@echo off
rem Arquivo unico: este bloco e o lancador (cmd); o resto e PowerShell.
set "GERAR_MOBILE_ARQ=%~f0"
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -Command "iex ([IO.File]::ReadAllText($env:GERAR_MOBILE_ARQ))"
exit /b
#>
# Gera versoes "mobile" (890x890, JPEG <= 400 KB) dos arquivos "feed" da pasta onde este .bat esta.
# Uso: copie gerar-mobile.bat para a pasta com as artes e de duplo clique.
# Requer apenas Windows PowerShell 5.1 (nativo no Windows 10/11): WinForms + System.Drawing.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# Sem console visivel: qualquer erro nao tratado vira janela, nunca some calado
trap {
    [System.Windows.Forms.MessageBox]::Show("Erro inesperado:`n$($_.Exception.Message)", 'Gerar mobile',
        'OK', 'Error') | Out-Null
    exit 1
}

# --- Parametros -------------------------------------------------------------
$Pasta       = Split-Path -Parent $env:GERAR_MOBILE_ARQ   # pasta onde o .bat esta
$LadoMaximo  = 890            # 1080 -> 890, proporcional (lado maior)
$PesoMaximo  = 400KB          # 409600 bytes
$QualidadeIni = 92
$QualidadeMin = 40
$PassoQualidade = 4

# --- Paleta (tons de areia e marrom; sem preto e branco puros na interface) ----
function Cor([string]$hex) { [System.Drawing.ColorTranslator]::FromHtml($hex) }
$T = @{
    Surface       = Cor '#fef8ed'   # areia-base
    SurfaceRaised = Cor '#fffaf2'   # areia-luz
    SurfaceMuted  = Cor '#fae9d4'   # pessego-33
    BorderSubtle  = Cor '#dbbba0'   # pessego-88
    TextPrimary   = Cor '#1c0e02'   # marrom-88
    TextSecondary = Cor '#4f2805'   # marrom-66
    TextTertiary  = Cor '#9c4e0b'   # marrom-33
    ActionPrimary = Cor '#e97510'   # laranja-base
    TextOnAccent  = Cor '#1c0e02'   # marrom-88
    Success       = Cor '#6e441c'   # marrom-couro
    Error         = Cor '#9c4e0b'   # marrom-33
}

function Fonte([string[]]$familias, [single]$px, [System.Drawing.FontStyle]$estilo = 'Regular') {
    $instaladas = (New-Object System.Drawing.Text.InstalledFontCollection).Families | ForEach-Object Name
    foreach ($f in $familias) {
        if ($instaladas -contains $f) {
            return New-Object System.Drawing.Font($f, $px, $estilo, [System.Drawing.GraphicsUnit]::Pixel)
        }
    }
    New-Object System.Drawing.Font('Segoe UI', $px, $estilo, [System.Drawing.GraphicsUnit]::Pixel)
}
$FonteTitulo  = Fonte @('Instrument Serif', 'Georgia') 35.58
$FonteCorpo   = Fonte @('Inter', 'Segoe UI') 17.29
$FonteLegenda = Fonte @('Inter', 'Segoe UI') 13.59
$FonteBotao   = Fonte @('Inter', 'Segoe UI') 17.29 ([System.Drawing.FontStyle]::Bold)

# --- Imagem -----------------------------------------------------------------
$CodecJpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
    Where-Object { $_.MimeType -eq 'image/jpeg' }

function NomeMobile([string]$nome) {
    $base = [System.IO.Path]::GetFileNameWithoutExtension($nome) -replace 'feed', 'mobile'
    "$base.jpg"
}

function Redimensionar([string]$origem) {
    $img = [System.Drawing.Image]::FromFile($origem)
    try {
        $escala = $LadoMaximo / [Math]::Max($img.Width, $img.Height)
        $w = [int][Math]::Round($img.Width * $escala)
        $h = [int][Math]::Round($img.Height * $escala)
        $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            # JPEG nao tem transparencia: PNG RGBA e achatado sobre fundo branco (conteudo, nao UI)
            $g.Clear([System.Drawing.Color]::White)
            $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
            $attr = New-Object System.Drawing.Imaging.ImageAttributes
            $attr.SetWrapMode([System.Drawing.Drawing2D.WrapMode]::TileFlipXY)   # evita borda escura
            $g.DrawImage($img, (New-Object System.Drawing.Rectangle(0, 0, $w, $h)),
                0, 0, $img.Width, $img.Height, [System.Drawing.GraphicsUnit]::Pixel, $attr)
            $attr.Dispose()
        } finally { $g.Dispose() }
        $bmp
    } finally { $img.Dispose() }
}

# Reduz a qualidade JPEG ate caber em $PesoMaximo. Retorna @{ Bytes; Qualidade } ou lanca erro.
function CodificarNoLimite([System.Drawing.Bitmap]$bmp) {
    for ($q = $QualidadeIni; $q -ge $QualidadeMin; $q -= $PassoQualidade) {
        $params = New-Object System.Drawing.Imaging.EncoderParameters(1)
        $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
            [System.Drawing.Imaging.Encoder]::Quality, [long]$q)
        $ms = New-Object System.IO.MemoryStream
        try {
            $bmp.Save($ms, $CodecJpeg, $params)
            if ($ms.Length -le $PesoMaximo) { return @{ Bytes = $ms.ToArray(); Qualidade = $q } }
        } finally { $ms.Dispose(); $params.Dispose() }
    }
    throw "nao coube em $([int]($PesoMaximo / 1KB)) KB nem com qualidade $QualidadeMin"
}

function Processar([string]$origem, [string]$destino) {
    $bmp = Redimensionar $origem
    try {
        $r = CodificarNoLimite $bmp
        [System.IO.File]::WriteAllBytes($destino, $r.Bytes)
        "{0} KB, qualidade {1}" -f [int][Math]::Ceiling($r.Bytes.Length / 1KB), $r.Qualidade
    } finally { $bmp.Dispose() }
}

# --- Entrada ----------------------------------------------------------------
$Arquivos = @(Get-ChildItem -LiteralPath $Pasta -File |
    Where-Object { $_.Name -like '*feed*' -and $_.Extension -match '^\.(png|jpe?g)$' } |
    Sort-Object Name)

# --- Interface --------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Gerar versões mobile'
$form.ClientSize = New-Object System.Drawing.Size(800, 640)
$form.MinimumSize = New-Object System.Drawing.Size(640, 480)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $T.Surface
$form.ForeColor = $T.TextPrimary
$form.Font = $FonteCorpo
$form.Padding = New-Object System.Windows.Forms.Padding(24)

$layout = New-Object System.Windows.Forms.TableLayoutPanel
$layout.Dock = 'Fill'
$layout.ColumnCount = 1
$layout.RowCount = 5
$layout.BackColor = $T.Surface
foreach ($s in @('AutoSize', 'AutoSize', 'AutoSize', 'Percent', 'AutoSize')) {
    $st = New-Object System.Windows.Forms.RowStyle([System.Windows.Forms.SizeType]::$s)
    if ($s -eq 'Percent') { $st.Height = 100 }
    $layout.RowStyles.Add($st) | Out-Null
}
$form.Controls.Add($layout)

$titulo = New-Object System.Windows.Forms.Label
$titulo.Text = 'Versões mobile'
$titulo.Font = $FonteTitulo
$titulo.AutoSize = $true
$titulo.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 8)
$layout.Controls.Add($titulo, 0, 0)

$sub = New-Object System.Windows.Forms.Label
$sub.Text = "$($Arquivos.Count) arquivos com ""feed"" nesta pasta ($Pasta).`n" +
    "Cada cópia sai em $LadoMaximo x $LadoMaximo px, JPEG até $([int]($PesoMaximo / 1KB)) KB, " +
    "com ""feed"" trocado por ""mobile"" no nome."
$sub.ForeColor = $T.TextSecondary
$sub.AutoSize = $true
$sub.MaximumSize = New-Object System.Drawing.Size(752, 0)
$sub.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 16)
$layout.Controls.Add($sub, 0, 1)

function BotaoSecundario([string]$texto) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $texto
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderColor = $T.BorderSubtle
    $b.FlatAppearance.MouseOverBackColor = $T.SurfaceMuted
    $b.BackColor = $T.SurfaceRaised
    $b.ForeColor = $T.TextSecondary
    $b.Font = $FonteLegenda
    $b.AutoSize = $true
    $b.Padding = New-Object System.Windows.Forms.Padding(8, 0, 8, 0)
    $b.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 8)
    $b.Cursor = 'Hand'
    $b
}
$barra = New-Object System.Windows.Forms.FlowLayoutPanel
$barra.AutoSize = $true
$barra.Margin = New-Object System.Windows.Forms.Padding(0)
$btnTodos = BotaoSecundario 'Marcar todos'
$btnNenhum = BotaoSecundario 'Desmarcar todos'
$barra.Controls.AddRange(@($btnTodos, $btnNenhum))
$layout.Controls.Add($barra, 0, 2)

$lista = New-Object System.Windows.Forms.ListView
$lista.View = 'Details'
$lista.CheckBoxes = $true
$lista.FullRowSelect = $true
$lista.GridLines = $false
$lista.HeaderStyle = 'Nonclickable'
$lista.Dock = 'Fill'
$lista.BackColor = $T.SurfaceRaised
$lista.ForeColor = $T.TextPrimary
$lista.BorderStyle = 'FixedSingle'
$lista.Margin = New-Object System.Windows.Forms.Padding(0, 0, 0, 16)
$lista.Columns.Add('Arquivo feed', 300) | Out-Null
$lista.Columns.Add('Peso', 88) | Out-Null
$lista.Columns.Add('Resultado', 340) | Out-Null
foreach ($a in $Arquivos) {
    $item = New-Object System.Windows.Forms.ListViewItem($a.Name)
    $item.SubItems.Add(('{0:N0} KB' -f ($a.Length / 1KB))) | Out-Null
    $existe = Test-Path -LiteralPath (Join-Path $Pasta (NomeMobile $a.Name))
    $item.SubItems.Add($(if ($existe) { 'mobile já existe: será substituído' } else { '' })) | Out-Null
    $item.Checked = $true
    $item.Tag = $a.FullName
    $lista.Items.Add($item) | Out-Null
}
$layout.Controls.Add($lista, 0, 3)

$rodape = New-Object System.Windows.Forms.TableLayoutPanel
$rodape.ColumnCount = 2
$rodape.RowCount = 1
$rodape.AutoSize = $true
$rodape.Dock = 'Fill'
$rodape.Margin = New-Object System.Windows.Forms.Padding(0)
$rodape.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::Percent, 100))) | Out-Null
$rodape.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle([System.Windows.Forms.SizeType]::AutoSize))) | Out-Null

$status = New-Object System.Windows.Forms.Label
$status.AutoSize = $true
$status.Anchor = 'Left'
$status.ForeColor = $T.TextSecondary
$status.Font = $FonteLegenda
$rodape.Controls.Add($status, 0, 0)

# Unico botao com cor de destaque solida na tela
$btnGerar = New-Object System.Windows.Forms.Button
$btnGerar.FlatStyle = 'Flat'
$btnGerar.FlatAppearance.BorderSize = 0
$btnGerar.BackColor = $T.ActionPrimary
$btnGerar.ForeColor = $T.TextOnAccent
$btnGerar.Font = $FonteBotao
$btnGerar.AutoSize = $true
$btnGerar.MinimumSize = New-Object System.Drawing.Size(0, 48)
$btnGerar.Padding = New-Object System.Windows.Forms.Padding(16, 0, 16, 0)
$btnGerar.Margin = New-Object System.Windows.Forms.Padding(0)
$btnGerar.Cursor = 'Hand'
$rodape.Controls.Add($btnGerar, 1, 0)
$layout.Controls.Add($rodape, 0, 4)

function AtualizarContagem {
    $n = $lista.CheckedItems.Count
    $btnGerar.Text = "Gerar $n de $($lista.Items.Count)"
    $btnGerar.Enabled = ($n -gt 0)
    $status.Text = $(if ($n -eq $lista.Items.Count) { 'Todos selecionados.' } else { "$n selecionados." })
}
$lista.Add_ItemChecked({ AtualizarContagem })
$btnTodos.Add_Click({ foreach ($i in $lista.Items) { $i.Checked = $true } })
$btnNenhum.Add_Click({ foreach ($i in $lista.Items) { $i.Checked = $false } })

$btnGerar.Add_Click({
    $marcados = @($lista.CheckedItems)
    $btnGerar.Enabled = $false; $btnTodos.Enabled = $false; $btnNenhum.Enabled = $false
    $ok = 0; $falhas = 0; $k = 0
    foreach ($item in $marcados) {
        $k++
        $status.Text = "Processando $k de $($marcados.Count): $($item.Text)"
        $item.SubItems[2].Text = 'processando...'
        [System.Windows.Forms.Application]::DoEvents()
        $destino = Join-Path $Pasta (NomeMobile $item.Text)
        try {
            $info = Processar $item.Tag $destino
            $item.SubItems[2].Text = "$(Split-Path $destino -Leaf)  ($info)"
            $item.ForeColor = $T.Success
            $ok++
        } catch {
            $item.SubItems[2].Text = "ERRO: $($_.Exception.Message)"
            $item.ForeColor = $T.Error
            Write-Warning "$($item.Text): $($_.Exception.Message)"
            $falhas++
        }
        [System.Windows.Forms.Application]::DoEvents()
    }
    $btnTodos.Enabled = $true; $btnNenhum.Enabled = $true
    AtualizarContagem
    $status.Text = "Concluído: $ok gerados" + $(if ($falhas) { ", $falhas com erro." } else { '.' })
})

if ($Arquivos.Count -eq 0) {
    $status.Text = 'Nenhum arquivo com "feed" encontrado.'
    $btnGerar.Text = 'Gerar'
    $btnGerar.Enabled = $false
    $btnTodos.Enabled = $false; $btnNenhum.Enabled = $false
} else {
    AtualizarContagem
}

[void]$form.ShowDialog()
