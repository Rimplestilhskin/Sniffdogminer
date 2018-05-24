using module ..\Include.psm1

param(
    [alias("Wallet")]
    [String]$BTC, 
    [alias("WorkerName")]
    [String]$Worker, 
    [TimeSpan]$StatSpan
)

$Name = Get-Item $MyInvocation.MyCommand.Path | Select-Object -ExpandProperty BaseName

$NiceHash_Request = [PSCustomObject]@{}

try {
    $NiceHash_Request = Invoke-RestMethod "http://api.nicehash.com/api" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
    #$NiceHashCoins_Request = Invoke-RestMethod "http://api.NiceHash.com:8080/api/currencies" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
}
catch {
    Write-Log -Level Warn "Pool API ($Name) has failed. "
    return
}

if (($NiceHash_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Measure-Object Name).Count -le 1) {
    Write-Log -Level Warn "Pool API ($Name) returned nothing. "
    return
}

$NiceHash_Regions = "us", "europe"
$NiceHash_Currencies = @("BTC", "LTC") | Select-Object -Unique | Where-Object {Get-Variable $_ -ValueOnly -ErrorAction SilentlyContinue}
$NiceHash_MiningCurrencies = ($NiceHashCoins_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name) | Select-Object -Unique

$NiceHash_Request | Get-Member -MemberType NoteProperty -ErrorAction Ignore | Select-Object -ExpandProperty Name | Where-Object {$NiceHash_Request.$_.hashrate -gt 0} |ForEach-Object {
    $NiceHash_Host = "mine.NiceHash.com"
    $NiceHash_Port = $NiceHash_Request.$_.port
    $NiceHash_Algorithm = $NiceHash_Request.$_.name
    $NiceHash_Algorithm_Norm = Get-Algorithm $NiceHash_Algorithm
    $NiceHash_Coin = ""

    $Divisor = 1000000

    switch ($NiceHash_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "keccak" {$Divisor *= 1000}
        "keccakc" {$Divisor *= 1000}
        "phi" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    if ((Get-Stat -Name "$($Name)_$($NiceHash_Algorithm_Norm)_Profit") -eq $null) {$Stat = Set-Stat -Name "$($Name)_$($NiceHash_Algorithm_Norm)_Profit" -Value ([Double]$NiceHash_Request.$_.estimate_last24h / $Divisor) -Duration (New-TimeSpan -Days 1)}
    else {$Stat = Set-Stat -Name "$($Name)_$($NiceHash_Algorithm_Norm)_Profit" -Value ([Double]$NiceHash_Request.$_.estimate_current / $Divisor) -Duration $StatSpan -ChangeDetection $true}

    $NiceHash_Regions | ForEach-Object {
        $NiceHash_Region = $_
        $NiceHash_Region_Norm = Get-Region $NiceHash_Region

        $NiceHash_Currencies | ForEach-Object {
            #Option 1
            [PSCustomObject]@{
                Algorithm     = $NiceHash_Algorithm_Norm
                Info          = $NiceHash_Coin
                Price         = $Stat.Live
                StablePrice   = $Stat.Week
                MarginOfError = $Stat.Week_Fluctuation
                Protocol      = "stratum+tcp"
                Host          = if ($NiceHash_Region -eq "us") {$NiceHash_Host}else {"$NiceHash_Region.$NiceHash_Host"}
                Port          = $NiceHash_Port
                User          = Get-Variable $_ -ValueOnly
                Pass          = "$Worker,c=$_"
                Region        = $NiceHash_Region_Norm
                SSL           = $false
                Updated       = $Stat.Updated
            }
        }
    }
}

$NiceHash_MiningCurrencies | Where-Object {$NiceHashCoins_Request.$_.hashrate -gt 0} | ForEach-Object {
    $NiceHash_Host = "NiceHash.com"
    $NiceHash_Port = $NiceHashCoins_Request.$_.port
    $NiceHash_Algorithm = $NiceHashCoins_Request.$_.algo
    $NiceHash_Algorithm_Norm = Get-Algorithm $NiceHash_Algorithm
    $NiceHash_Coin = $NiceHashCoins_Request.$_.name
    $NiceHash_Currency = $_

    $Divisor = 1000000000

    switch ($NiceHash_Algorithm_Norm) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "keccak" {$Divisor *= 1000}
        "keccakc" {$Divisor *= 1000}
        "phi" {$Divisor *= 1000}
        "quark" {$Divisor *= 1000}
        "qubit" {$Divisor *= 1000}
        "scrypt" {$Divisor *= 1000}
        "x11" {$Divisor *= 1000}
    }

    $Stat = Set-Stat -Name "$($Name)_$($_)_Profit" -Value ([Double]$NiceHashCoins_Request.$_.estimate / $Divisor) -Duration $StatSpan -ChangeDetection $true

    $NiceHash_Regions | ForEach-Object {
        $NiceHash_Region = $_
        $NiceHash_Region_Norm = Get-Region $NiceHash_Region

        if (Get-Variable $NiceHash_Currency -ValueOnly -ErrorAction SilentlyContinue) {
            $NiceHash_Currency | ForEach-Object {
                #Option 3
                [PSCustomObject]@{
                    Algorithm     = $NiceHash_Algorithm_Norm
                    Info          = $NiceHash_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = if ($NiceHash_Region -eq "us") {$NiceHash_Host}else {"$NiceHash_Region.$NiceHash_Host"}
                    Port          = $NiceHash_Port
                    User          = Get-Variable $_ -ValueOnly
                    Pass          = "$Worker,c=$_,mc=$NiceHash_Currency"
                    Region        = $NiceHash_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                }
            }
        }
        else {
            $NiceHash_Currencies | ForEach-Object {
                #Option 2
                [PSCustomObject]@{
                    Algorithm     = $NiceHash_Algorithm_Norm
                    Info          = $NiceHash_Coin
                    Price         = $Stat.Live
                    StablePrice   = $Stat.Week
                    MarginOfError = $Stat.Week_Fluctuation
                    Protocol      = "stratum+tcp"
                    Host          = if ($NiceHash_Region -eq "us") {$NiceHash_Host}else {"$NiceHash_Region.$NiceHash_Host"}
                    Port          = $NiceHash_Port
                    User          = Get-Variable $_ -ValueOnly
                    Pass          = "$Worker,c=$_,mc=$NiceHash_Currency"
                    Region        = $NiceHash_Region_Norm
                    SSL           = $false
                    Updated       = $Stat.Updated
                }
            }
        }
    }
}
