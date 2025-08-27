

param([string[]]$InputArgs)

# Compatibility: if script was invoked and param didn't receive args, fall back to automatic $args
if ((-not $InputArgs) -or ($InputArgs.Count -eq 0)) {
    try { $InputArgs = $args } catch { }
}

# Tokenize input: some invocations pass the full argument string as a single element
$Tokens = @()
if ($InputArgs) {
    foreach ($it in $InputArgs) {
        if ($it -match '\s') { $Tokens += ($it -split '\s+') } else { $Tokens += $it }
    }
}
$InputArgs = $Tokens

function Write-Log { param($m) Write-Host $m }

function ParseInventory {
    param($path)
    $hosts = @()
    foreach ($line in Get-Content -Path $path -ErrorAction Stop -Encoding UTF8) {
        $l = $line -replace '#.*','' -replace ';.*',''
        $l = $l.Trim()
        if ([string]::IsNullOrWhiteSpace($l)) { continue }
        if ($l -match '^\[.*\]$') { continue }
        $first = ($l -split '\s+')[0]
        if ($first -like '*=*') { continue }
        if ($first -notmatch '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' -and $first -notmatch '^[A-Za-z0-9._-]+$') { continue }
        $user = $null
        if ($l -match 'ansible_user=([^\s]+)') { $user = $matches[1] }
        $hosts += [pscustomobject]@{ Host = $first; User = $user }
    }
    return $hosts
}

# MAIN - robust token parser
$TARGET_USER = $null
$KEY_PATH = $null
$inventory = $null
$hostsFromArgs = @()

# Build token list from both InputArgs and automatic $args
$all = @()
if ($InputArgs) { $all += $InputArgs }
if ($args) { $all += $args }

$tokens = @()
foreach ($it in $all) {
    if ($it -match '\s') { $tokens += ($it -split '\s+') } else { $tokens += $it }
}

$i = 0
while ($i -lt $tokens.Count) {
    $t = $tokens[$i]
    switch -Wildcard ($t) {
        '--user' {
            if (($i + 1) -lt $tokens.Count) { $TARGET_USER = $tokens[$i + 1]; $i += 2; continue }
            else { break }
        }
        '--key-path' {
            if (($i + 1) -lt $tokens.Count) { $KEY_PATH = $tokens[$i + 1]; $i += 2; continue }
            else { break }
        }
        default {
            # if it's a file path, assume inventory; else treat as host
            if (Test-Path -Path $t -PathType Leaf) { $inventory = $t } else { $hostsFromArgs += $t }
            $i += 1
        }
    }
}

$HOSTS = @()
if ($inventory) {
    $HOSTS = ParseInventory -path $inventory
} else {
    foreach ($h in $hostsFromArgs) { $HOSTS += [pscustomobject]@{ Host = $h; User = $null } }
}

if ($HOSTS.Count -eq 0) { Write-Log "Usage: trust_ssh_hosts.ps1 <hosts_inventory.ini> [--key-path <pubkey>] OR trust_ssh_hosts.ps1 [--user <user>] <host1> [host2 ...]"; exit 1 }

# Ensure ssh-keygen exists (OpenSSH client)
function EnsureKey {
    param($KeyPath)
    $sshDir = Join-Path $env:USERPROFILE '.ssh'
    if (-not (Test-Path $sshDir)) { New-Item -ItemType Directory -Path $sshDir | Out-Null }
    if ($KeyPath) { return $KeyPath }
    $candidates = @('id_ed25519.pub','id_rsa.pub','id_ecdsa.pub')
    foreach ($c in $candidates) {
        $p = Join-Path $sshDir $c
        if (Test-Path $p) { return $p }
    }
    # generate
    $priv = Join-Path $sshDir 'id_ed25519'
    $pub = "$priv.pub"
    Write-Log "No SSH key found; generating ed25519 keypair at $priv"
    & ssh-keygen -t ed25519 -N '' -f $priv | Out-Null
    return $pub
}

$finalKey = EnsureKey -KeyPath $KEY_PATH
Write-Log "Using public key: $finalKey"

# Prompt for passwords per unique user if inventory used
$userMap = @{}
if ($inventory) {
    foreach ($entry in $HOSTS) {
        if (-not $entry.User) { $entry.User = 'root' }
        $userMap[$entry.User] = $true
    }
    $passwords = @{}
    foreach ($u in $userMap.Keys) {
        $pw = Read-Host -AsSecureString "Enter SSH password for user $u"
        $pwdPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pw))
        $passwords[$u] = $pwdPlain
    }
}

foreach ($entry in $HOSTS) {
    $targetHost = $entry.Host
    $user = $entry.User
    if (-not $user) { $user = $TARGET_USER }
    if (-not $user) { $user = 'root' }
    $pw = $null
    if ($inventory) { $pw = $passwords[$user] } else { if (-not $TARGET_USER) { $TARGET_USER='adm4n' } $pw = Read-Host -AsSecureString "Enter SSH password for user $user on $targetHost"; $pw=[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($pw)) }

    Write-Log "Trusting host: $targetHost (user: $user)"
    # add host key
    if (Get-Command ssh-keyscan -ErrorAction SilentlyContinue) {
        try { & ssh-keyscan -H $targetHost >> (Join-Path $env:USERPROFILE '.ssh\\known_hosts') 2>$null } catch {}
    }
    # push public key by piping it into ssh (user will be asked password interactively)
    $pubContent = Get-Content -Raw -Path $finalKey
    $attempt=0
    $ok = $false
    while ($attempt -lt 3 -and -not $ok) {
        try {
            $attempt++
            # Use PowerShell's ssh which will prompt for password; pipe pubkey to remote append
            $cmd = "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"
            $pubContent | ssh -o PreferredAuthentications=password,keyboard-interactive -o PubkeyAuthentication=no -o StrictHostKeyChecking=no $user@$targetHost $cmd
            $ok = $true
        } catch {
            Write-Log "Attempt $attempt/3 failed to push key to $targetHost; retrying..."
            Start-Sleep -Seconds 1
        }
    }
    if (-not $ok) { Write-Log "Failed to push key to $targetHost after 3 attempts." }
    else {
        try { ssh -o StrictHostKeyChecking=no $user@$targetHost "echo 'SSH OK on $(hostname)'" }
        catch { Write-Log "Connectivity check failed for $targetHost" }
    }
}
