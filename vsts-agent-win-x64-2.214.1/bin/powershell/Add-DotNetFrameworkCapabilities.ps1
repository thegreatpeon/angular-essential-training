[CmdletBinding()]
param()

# See http://msdn.microsoft.com/en-us/library/hh925568(v=vs.110).aspx for details on how to detect framework versions
# Also see http://support.microsoft.com/kb/318785

function Add-Versions {
    [CmdletBinding()]
    param(
        [string]$NameFormat,

        [Parameter(Mandatory = $true)]
        [string]$View,

        [Parameter(Mandatory = $true)]
        [ref]$LatestValue)

    # Get the install root from the registry.
    $installRoot = Get-RegistryValue -Hive 'LocalMachine' -View $View -KeyName 'Software\Microsoft\.NETFramework' -ValueName 'InstallRoot'
    if (!$installRoot) {
        return
    }

    # Get the version sub key names.
    $ndpKeyName = 'Software\Microsoft\NET Framework Setup\NDP'
    $versionSubKeyNames =
        Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $View -KeyName $ndpKeyName |
        Where-Object { $_ -like 'v*' }
    foreach ($versionSubKeyName in $versionSubKeyNames) {
        # Get the version.
        $versionKeyName = "$ndpKeyName\$versionSubKeyName"
        $version = Get-RegistryValue -Hive 'LocalMachine' -View $View -KeyName $versionKeyName -ValueName 'Version'
        if ($version) {
            # Check if installed.
            $install = Get-RegistryValue -Hive 'LocalMachine' -View $View -KeyName $versionKeyName -ValueName 'Install'
            if ($install -ne 1) {
                continue
            }

            # Verify the expected install path.
            $version
            $installPath = [System.IO.Path]::Combine($installRoot, $versionSubKeyName)
            if (!(Test-Container -LiteralPath $installPath)) {
                continue
            }

            # Parse the version from the sub key name.
            $versionObject = [System.Version]::Parse($versionSubKeyName.Substring(1))
            $capabilityName = ($NameFormat -f "$($versionObject.Major).$($versionObject.Minor)")

            # Add the capability.
            Write-Capability -Name $capabilityName -Value $installPath
            $LatestValue.Value = $installPath
            continue
        }

        # Check if deprecated.
        $default = Get-RegistryValue -Hive 'LocalMachine' -View $View -KeyName $versionKeyName -ValueName ''
        if ($default -eq 'deprecated') {
            continue
        }

        # Get the profile key names.
        $profileKeyNames =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $View -KeyName $versionKeyName |
            ForEach-Object { "$versionKeyName\$_" }
        foreach ($profileKeyName in $profileKeyNames) {
            # Skip if version not found.
            $version = Get-RegistryValue -Hive 'LocalMachine' -View $View -KeyName $profileKeyName -ValueName 'Version'
            if (!$version) {
                continue
            }

            # Skip if not installed.
            $install = Get-RegistryValue -Hive 'LocalMachine' -View $View -KeyName $profileKeyName -ValueName 'Install'
            if ($install -ne 1) {
                continue
            }

            # Skip if install path value not found.
            $installPath = Get-RegistryValue -Hive 'LocalMachine' -View $View -KeyName $profileKeyName -ValueName 'InstallPath'
            $installPath = "$installPath".TrimEnd([System.IO.Path]::DirectorySeparatorChar)
            if (!$installPath) {
                continue
            }

            # Determine the version string.
            $release = Get-RegistryValue -Hive 'LocalMachine' -View $View -KeyName $profileKeyName -ValueName 'Release'
            $versionString = switch ($release) {
                # We put the releaseVersion into version range, since customer might install beta/preview version .NET Framework.
                # These magic values come from: https://docs.microsoft.com/en-us/dotnet/framework/migration-guide/how-to-determine-which-versions-are-installed
                378389 { "4.5.0" }
                { $_ -gt 378389 -and $_ -le 378758 } { "4.5.1" }
                { $_ -gt 378758 -and $_ -le 379893 } { "4.5.2" }
                { $_ -gt 379893 -and $_ -le 380995 } { "4.5.3" }
                { $_ -gt 380995 -and $_ -le 393297 } { "4.6.0" }
                { $_ -gt 393297 -and $_ -le 394271 } { "4.6.1" }
                { $_ -gt 394271 -and $_ -le 394806 } { "4.6.2" }
                { $_ -gt 394806 -and $_ -le 460805 } { "4.7.0" }
                { $_ -gt 460805 -and $_ -le 461310 } { "4.7.1" }
                { $_ -gt 461310 -and $_ -le 461814 } { "4.7.2" }
                { $_ -gt 461814 } { "4.8.0"}
            }

            if (!$versionString) {
                continue
            }

            Write-Capability -Name ($NameFormat -f $versionString) -Value $installPath
            $LatestValue.Value = $installPath
        }
    }
}

$latest = $null
Add-Versions -NameFormat 'DotNetFramework_{0}' -View 'Registry32' -LatestValue ([ref]$latest)
Add-Versions -NameFormat 'DotNetFramework_{0}_x64' -View 'Registry64' -LatestValue ([ref]$latest)
if ($latest) {
    Write-Capability -Name 'DotNetFramework' -Value $latest
}

# SIG # Begin signature block
# MIInnQYJKoZIhvcNAQcCoIInjjCCJ4oCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDn0KHRYUXGam6W
# h5iXVyzaYZlqUGA5QThswdjEkartZqCCDYEwggX/MIID56ADAgECAhMzAAACzI61
# lqa90clOAAAAAALMMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMjIwNTEyMjA0NjAxWhcNMjMwNTExMjA0NjAxWjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCiTbHs68bADvNud97NzcdP0zh0mRr4VpDv68KobjQFybVAuVgiINf9aG2zQtWK
# No6+2X2Ix65KGcBXuZyEi0oBUAAGnIe5O5q/Y0Ij0WwDyMWaVad2Te4r1Eic3HWH
# UfiiNjF0ETHKg3qa7DCyUqwsR9q5SaXuHlYCwM+m59Nl3jKnYnKLLfzhl13wImV9
# DF8N76ANkRyK6BYoc9I6hHF2MCTQYWbQ4fXgzKhgzj4zeabWgfu+ZJCiFLkogvc0
# RVb0x3DtyxMbl/3e45Eu+sn/x6EVwbJZVvtQYcmdGF1yAYht+JnNmWwAxL8MgHMz
# xEcoY1Q1JtstiY3+u3ulGMvhAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUiLhHjTKWzIqVIp+sM2rOHH11rfQw
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDcwNTI5MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAeA8D
# sOAHS53MTIHYu8bbXrO6yQtRD6JfyMWeXaLu3Nc8PDnFc1efYq/F3MGx/aiwNbcs
# J2MU7BKNWTP5JQVBA2GNIeR3mScXqnOsv1XqXPvZeISDVWLaBQzceItdIwgo6B13
# vxlkkSYMvB0Dr3Yw7/W9U4Wk5K/RDOnIGvmKqKi3AwyxlV1mpefy729FKaWT7edB
# d3I4+hldMY8sdfDPjWRtJzjMjXZs41OUOwtHccPazjjC7KndzvZHx/0VWL8n0NT/
# 404vftnXKifMZkS4p2sB3oK+6kCcsyWsgS/3eYGw1Fe4MOnin1RhgrW1rHPODJTG
# AUOmW4wc3Q6KKr2zve7sMDZe9tfylonPwhk971rX8qGw6LkrGFv31IJeJSe/aUbG
# dUDPkbrABbVvPElgoj5eP3REqx5jdfkQw7tOdWkhn0jDUh2uQen9Atj3RkJyHuR0
# GUsJVMWFJdkIO/gFwzoOGlHNsmxvpANV86/1qgb1oZXdrURpzJp53MsDaBY/pxOc
# J0Cvg6uWs3kQWgKk5aBzvsX95BzdItHTpVMtVPW4q41XEvbFmUP1n6oL5rdNdrTM
# j/HXMRk1KCksax1Vxo3qv+13cCsZAaQNaIAvt5LvkshZkDZIP//0Hnq7NnWeYR3z
# 4oFiw9N2n3bb9baQWuWPswG0Dq9YT9kb+Cs4qIIwggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIZcjCCGW4CAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAsyOtZamvdHJTgAAAAACzDAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgre6PhYbI
# TrfAZI0m51CilHEa6nooWmnmbJ5QSnEjasswQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQCBfWmglj+uViFMzgCIvUvEqxPyfsEo25TW4VJN2Dsi
# zuRqrCvLQG2rbEjBPDXjrP8DKNz3ACRSl7wV4W2sBhScYpXDM9O+D5GeGPPP50Va
# OB7Tqd95WWvFb7GIGBluO4abHln6gWZL+GNpaWeMSIeUwkT/aG3WQj0I21pI1aMq
# 2nadLcizK40dhD++Hrdufyraul+Xkmi4oTIujdm47UcyJADosy8fVAzQnDfjdHYq
# UiEQYaNv7CG3aBsMO/iR3uZiKQBBO+Dh8mAwaYpbx9paU2i+YXpb8RFmXlwiX8rA
# M6ldZcKWxPdq31LSO3GrWW6gxILuQSYmUJrBM9Dq/rJFoYIW/DCCFvgGCisGAQQB
# gjcDAwExghboMIIW5AYJKoZIhvcNAQcCoIIW1TCCFtECAQMxDzANBglghkgBZQME
# AgEFADCCAVAGCyqGSIb3DQEJEAEEoIIBPwSCATswggE3AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIJsAhz0jNBUPe1D08N7bbK5Icb5ycahVajHPgnnW
# OQZ/AgZjbVauomQYEjIwMjIxMjEyMTUzNzQ5LjMyWjAEgAIB9KCB0KSBzTCByjEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBF
# U046RUFDRS1FMzE2LUM5MUQxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1w
# IFNlcnZpY2WgghFUMIIHDDCCBPSgAwIBAgITMwAAAcOLb9NIvw6RXQABAAABwzAN
# BgkqhkiG9w0BAQsFADB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3Rv
# bjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0
# aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAeFw0y
# MjExMDQxOTAxMjlaFw0yNDAyMDIxOTAxMjlaMIHKMQswCQYDVQQGEwJVUzETMBEG
# A1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWlj
# cm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBP
# cGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpFQUNFLUUzMTYtQzkx
# RDElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZTCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBALvrvOrN0f6vopKLPNGg+NmJttTQzmbZ
# XTUcTBVMZuKPZFVpEodnPIzgsSV8FdihaHQk8aRkLPY8uZ1CPi6v27dB1rUmDzDz
# 7XreNtIM8DNRLEdupG6cJQR8RWOIZN8twB/tWCn/W4bz7O5D212x+4HWnIrXgfhe
# xaDkbfXtA/3bAXhvNBmQBdsui1gI+gtpjKpWn15MG308kGp7l+uWLvsTKcidXwER
# Kbke+uq3j66pRNCmmng9J6joBq05EmXgjAzx+jrSdNI1zMGyA8h+5eH2EXiLE38z
# eRn91Goq7I3mvihcttpVPHpZyF46Hssd6XHrB/quWq2NXOhz33kp5HjKJP4MZwez
# 9TI7eyPRCPbYULTL8v9UlJixtdqwUfw34XhP1SaXJv02HqFddTX0EJ5f4wWz20kQ
# adBxqkyHFg6WOjIEnQaEBE9Q76ROD1+LJ3TRnNcBsoOOaR+tmTH1Bfwsxme4let+
# 0bZ0BVw808aEhBJHVzHVgyRvo48aAtepUZNcRZ35AOLqJmuJirKO6rxOndu/iuss
# yElkO047rWCyiZ0szb34jYrsr/9McQgEkgEbzkN7/XHoLzP6Z7lPXOrPuIJit/uY
# 4XL51hkKiRNLaWB5pN25pgS9YB5vU4wSc+Zv/K7xzN0cNzlIVeP8JgC99ipj0eVG
# 2+MMORzRormNAgMBAAGjggE2MIIBMjAdBgNVHQ4EFgQUHBi+zdjXbwGivE3C68TE
# 7GvGgdYwHwYDVR0jBBgwFoAUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXwYDVR0fBFgw
# VjBUoFKgUIZOaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraW9wcy9jcmwvTWlj
# cm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAoMSkuY3JsMGwGCCsGAQUF
# BwEBBGAwXjBcBggrBgEFBQcwAoZQaHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aW9wcy9jZXJ0cy9NaWNyb3NvZnQlMjBUaW1lLVN0YW1wJTIwUENBJTIwMjAxMCgx
# KS5jcnQwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG
# 9w0BAQsFAAOCAgEA3fKmWxwanQRUQ8RhsA6JZZ0cndFplJ46qD/uUAh+LzDwbeLp
# h1YSbsnkZAxC5E1mblqit1Nc9h5xmrW5xE3B1JcsJR/tyO0e31NMymMNjywPlWsA
# nK57CAoBN9uNhLBAv2dGFO+NDSf8W7s6xrUxLVCIkL69gAjycobD6LXvCLU3+LjV
# uDG6NUD9LY3ASgoBHsyAuA2FDNAWAlgpnmZjcAJcX6U5YjhRCgfVGkqh0rOdXB/C
# WNIKi9y8CPS2H4xDu+/vh2P5zKlwjIvYoVCqCKdk34383ZuTYOVfssPPsF5dvUXF
# uEOArx57TXysU/aENye2AUEBB1iT4PEzUfcOAfNhc5qw3fLC+hE7xrseYRXMJhfk
# Nq0+TGvHWFEnQkoP4oaBGFBiWZ2S/Z8g6dbJ35UlV+xaS8gC8ww5RwVtQiYWFX3y
# UaKs9Q+JEaKKkQTUWjBTD4p4MsMGxIITIXiSjaHWuwBoKvtRx9Wn0ZRPvamFvRSj
# Hs8XkJn/IHLgLoa/SAF8mhfQxdDyeX+LoczkryAtQZCbcxeqKeOVGGiO1fvV/HXM
# F22SZyCAB9XI1TvChAocSiJKZOEIMtD6HIFMGhlqpi1kbtYUNViVp0F77wWHmAxl
# m4/z7UpcsL+pvJroy3qXzLyXFNuSlpJUj9hbjcemjlX3o3vqYG8CECFUNZ0wggdx
# MIIFWaADAgECAhMzAAAAFcXna54Cm0mZAAAAAAAVMA0GCSqGSIb3DQEBCwUAMIGI
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMTIwMAYDVQQDEylN
# aWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkgMjAxMDAeFw0yMTA5
# MzAxODIyMjVaFw0zMDA5MzAxODMyMjVaMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA5OGmTOe0ciEL
# eaLL1yR5vQ7VgtP97pwHB9KpbE51yMo1V/YBf2xK4OK9uT4XYDP/XE/HZveVU3Fa
# 4n5KWv64NmeFRiMMtY0Tz3cywBAY6GB9alKDRLemjkZrBxTzxXb1hlDcwUTIcVxR
# MTegCjhuje3XD9gmU3w5YQJ6xKr9cmmvHaus9ja+NSZk2pg7uhp7M62AW36MEByd
# Uv626GIl3GoPz130/o5Tz9bshVZN7928jaTjkY+yOSxRnOlwaQ3KNi1wjjHINSi9
# 47SHJMPgyY9+tVSP3PoFVZhtaDuaRr3tpK56KTesy+uDRedGbsoy1cCGMFxPLOJi
# ss254o2I5JasAUq7vnGpF1tnYN74kpEeHT39IM9zfUGaRnXNxF803RKJ1v2lIH1+
# /NmeRd+2ci/bfV+AutuqfjbsNkz2K26oElHovwUDo9Fzpk03dJQcNIIP8BDyt0cY
# 7afomXw/TNuvXsLz1dhzPUNOwTM5TI4CvEJoLhDqhFFG4tG9ahhaYQFzymeiXtco
# dgLiMxhy16cg8ML6EgrXY28MyTZki1ugpoMhXV8wdJGUlNi5UPkLiWHzNgY1GIRH
# 29wb0f2y1BzFa/ZcUlFdEtsluq9QBXpsxREdcu+N+VLEhReTwDwV2xo3xwgVGD94
# q0W29R6HXtqPnhZyacaue7e3PmriLq0CAwEAAaOCAd0wggHZMBIGCSsGAQQBgjcV
# AQQFAgMBAAEwIwYJKwYBBAGCNxUCBBYEFCqnUv5kxJq+gpE8RjUpzxD/LwTuMB0G
# A1UdDgQWBBSfpxVdAF5iXYP05dJlpxtTNRnpcjBcBgNVHSAEVTBTMFEGDCsGAQQB
# gjdMg30BATBBMD8GCCsGAQUFBwIBFjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20v
# cGtpb3BzL0RvY3MvUmVwb3NpdG9yeS5odG0wEwYDVR0lBAwwCgYIKwYBBQUHAwgw
# GQYJKwYBBAGCNxQCBAweCgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB
# /wQFMAMBAf8wHwYDVR0jBBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0f
# BE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJv
# ZHVjdHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4w
# TDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0
# cy9NaWNSb29DZXJBdXRfMjAxMC0wNi0yMy5jcnQwDQYJKoZIhvcNAQELBQADggIB
# AJ1VffwqreEsH2cBMSRb4Z5yS/ypb+pcFLY+TkdkeLEGk5c9MTO1OdfCcTY/2mRs
# fNB1OW27DzHkwo/7bNGhlBgi7ulmZzpTTd2YurYeeNg2LpypglYAA7AFvonoaeC6
# Ce5732pvvinLbtg/SHUB2RjebYIM9W0jVOR4U3UkV7ndn/OOPcbzaN9l9qRWqveV
# tihVJ9AkvUCgvxm2EhIRXT0n4ECWOKz3+SmJw7wXsFSFQrP8DJ6LGYnn8AtqgcKB
# GUIZUnWKNsIdw2FzLixre24/LAl4FOmRsqlb30mjdAy87JGA0j3mSj5mO0+7hvoy
# GtmW9I/2kQH2zsZ0/fZMcm8Qq3UwxTSwethQ/gpY3UA8x1RtnWN0SCyxTkctwRQE
# cb9k+SS+c23Kjgm9swFXSVRk2XPXfx5bRAGOWhmRaw2fpCjcZxkoJLo4S5pu+yFU
# a2pFEUep8beuyOiJXk+d0tBMdrVXVAmxaQFEfnyhYWxz/gq77EFmPWn9y8FBSX5+
# k77L+DvktxW/tM4+pTFRhLy/AsGConsXHRWJjXD+57XQKBqJC4822rpM+Zv/Cuk0
# +CQ1ZyvgDbjmjJnW4SLq8CdCPSWU5nR0W2rRnj7tfqAxM328y+l7vzhwRNGQ8cir
# Ooo6CGJ/2XBjU02N7oJtpQUQwXEGahC0HVUzWLOhcGbyoYICyzCCAjQCAQEwgfih
# gdCkgc0wgcoxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYD
# VQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAj
# BgNVBAsTHE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRo
# YWxlcyBUU1MgRVNOOkVBQ0UtRTMxNi1DOTFEMSUwIwYDVQQDExxNaWNyb3NvZnQg
# VGltZS1TdGFtcCBTZXJ2aWNloiMKAQEwBwYFKw4DAhoDFQDxHS/j7PodN3vki13R
# s7mO7S7uzqCBgzCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5n
# dG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9y
# YXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwMA0G
# CSqGSIb3DQEBBQUAAgUA50FbyTAiGA8yMDIyMTIxMjE1NTAzM1oYDzIwMjIxMjEz
# MTU1MDMzWjB0MDoGCisGAQQBhFkKBAExLDAqMAoCBQDnQVvJAgEAMAcCAQACAhJ+
# MAcCAQACAhGoMAoCBQDnQq1JAgEAMDYGCisGAQQBhFkKBAIxKDAmMAwGCisGAQQB
# hFkKAwKgCjAIAgEAAgMHoSChCjAIAgEAAgMBhqAwDQYJKoZIhvcNAQEFBQADgYEA
# GOqsk71ehnDJWune5FdBcryz/RFsrw1vcMotkxkCOppK+hOsnvWGEfUcchFXORYd
# zy1kVmaWhgZz3cYd20aHr+bYqrtNkf218ZGk6mqqHrmRvVtrcoxEWycOcb+ysfB9
# B3x59eM8+dIbCH7hByQrNxSIadPbxRrfTHRvFG+DQoAxggQNMIIECQIBATCBkzB8
# MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVk
# bW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1N
# aWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAcOLb9NIvw6RXQABAAAB
# wzANBglghkgBZQMEAgEFAKCCAUowGgYJKoZIhvcNAQkDMQ0GCyqGSIb3DQEJEAEE
# MC8GCSqGSIb3DQEJBDEiBCAmfjXYNPsh/loM3P7Gs9ZghzCcRaNHyakeWLn5Nizn
# rjCB+gYLKoZIhvcNAQkQAi8xgeowgecwgeQwgb0EINL7U5tvkknq4dSogJMKyUwC
# 8U3yaLZT3A2dmUp+/CpJMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENB
# IDIwMTACEzMAAAHDi2/TSL8OkV0AAQAAAcMwIgQggymFMGrdUl53NuprqQcRimTY
# dss5OoH/+FFCPxbsAbwwDQYJKoZIhvcNAQELBQAEggIAAIu4z0wbPMbNYDsGBMev
# iegLUICCZcJcTo7qT8LeSk9auiPAHaSecxnv6eEp8tgSWl8nyefJvcebG4TmnnSL
# tTPbsnsf23xUDdYVMhUnG097j+Yon1SVT3cAY4HR7NY1pvnhVeOCc1IRmfn51oi/
# 0ez2/JyM2wqGujvRjeFMIU5/Ih/9zbFO2D1IS8GqdvI4j0PGhoGqR9Cd1tATa2hg
# KxxbPKRXt3MlNEFGE0kWg0L1YAPCxna4lDrcK6mvK9j/5jK3Es8gSxxWhcNSlGHK
# irRGhb/iHuhtBearyIhaEybKHtFs45Dn6uQccz8Qat0RV8GdArerLl+dbUzeFD3t
# xEFbMUmqfDvvQrExy1N9AptsO75jfBYyO/hkpTcP+TsZHYq57PDjvPx5hjQ+pcRO
# 2IxFkDl5HznmsXw5EXuQ7R3yCB/65FrelOCPJF70yXnxzt9W1voAOqpy0rNeZl29
# XOZzYp6VnUrGrDnXzjnO+80esvXudTRXDdDBUjI9f+i0tC9pr0m/9DQw0wLooKQH
# KAOYOLsIwFOfObo28mD4gfY51sTDnXc0I1yIrWv7PpPDtp+DY/Iv2svIBUt0PQYZ
# pJ04kFlcFNmq13yLI7EnxVyogXwNnCZcyET91AQ0sqT8YYqux0FFq8ceyjq4ItmH
# +a/QHGkpkdbtn5b5QWM/P2M=
# SIG # End signature block
