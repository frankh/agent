Param(
    [string]$installDir = "C:\buildkite",
    [string]$arch = "amd64",
    [switch]$beta = ($env:buildkiteAgentBeta -eq 'true'),
    [switch]$path = $true,
    [string]$token = $env:buildkiteAgentToken,
    [string]$tags = $env:builkiteAgentTags
)   

$ErrorActionPreference = "Stop"

Write-Host "
  _           _ _     _ _    _ _                                _
 | |         (_) |   | | |  (_) |                              | |
 | |__  _   _ _| | __| | | ___| |_ ___    __ _  __ _  ___ _ __ | |_
 | '_ \| | | | | |/ _\` | |/ / | __/ _ \  / _\` |/ _\` |/ _ \ '_ \| __|
 | |_) | |_| | | | (_| |   <| | ||  __/ | (_| | (_| |  __/ | | | |_
 |_.__/ \__,_|_|_|\__,_|_|\_\_|\__\___|  \__,_|\__, |\___|_| |_|\__|
                                                __/ |
                                               |___/"

## Verify we are elevated
## https://superuser.com/questions/749243/detect-if-powershell-is-running-as-administrator

$elevated = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
if($elevated -eq $false)
{
    throw "In order to install services, please run this script elevated."
}

$releaseInfoUrl = "https://buildkite.com/agent/releases/latest?platform=windows&arch=$arch"
if($beta -eq $true) 
{
    $releaseInfoUrl = $releaseInfoUrl + "&prerelease=true"
}

Write-Host "Finding latest release"

$resp = Invoke-WebRequest -Uri "$releaseInfoUrl" -UseBasicParsing -Method GET

$releaseInfo = @{}
foreach ($line in $resp.Content.Split("`n")) 
{
    $info = $line -split "="
    $releaseInfo.add($info[0],$info[1])
}

# Github requires TLS1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "Downloading $($releaseInfo.url)"
Invoke-WebRequest -Uri $releaseInfo.url -OutFile 'buildkite-agent.zip'

Write-Host 'Expanding buildkite-agent.zip'
Expand-Archive -Force -Path buildkite-agent.zip -DestinationPath $installDir
Remove-Item buildkite-agent.zip -Force

if ($path -eq $true) {
    Write-Host 'Updating PATH'
    $env:PATH = "${installDir};" + $env:PATH
    [Environment]::SetEnvironmentVariable('PATH', $env:PATH, [EnvironmentVariableTarget]::Machine)
}   

# Verify it worked
buildkite-agent --version

Write-Host "Updating configuration in ${installDir}\buildkite-agent.cfg"
$buildkiteAgentCfgTemplate = type "${installDir}\buildkite-agent.cfg"
$buildkiteAgentCfgTemplate = $buildkiteAgentCfgTemplate -replace 'token="xxx"', ('token="{0}"' -f $token.Trim())
$buildkiteAgentCfgTemplate = $buildkiteAgentCfgTemplate -replace '# tags="key1=val2,key2=val2"', ('tags="{0}"' -f $tags)
[System.IO.File]::WriteAllLines("${installDir}\buildkite-agent.cfg", $buildkiteAgentCfgTemplate);

Write-Host "Successfully installed to $installDir

You can now start the agent!

  ${installDir}\buildkite-agent.exe start

For docs, help and support:

  https://buildkite.com/docs/agent/v3

Happy building! <3
"