[CmdletBinding()]
param()

function Get-MaxInfoFromSqlServer {
    [CmdletBinding()]
    param()

    $sqlServerKeyName = 'Software\Microsoft\Microsoft SQL Server'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $sqlServerKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $i = 0
                if (([int]::TryParse($_, [ref]$i))) {
                    $i
                }
            } |
            Sort-Object -Descending
        foreach ($version in $versions) {
            # Get the install directory.
            $verSpecificRootDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$sqlServerKeyName\$version" -Value 'VerSpecificRootDir'
            if (!$verSpecificRootDir) {
                continue
            }

            # Test for SqlPackage.exe.
            $file = [System.IO.Path]::Combine($verSpecificRootDir, 'Dac', 'bin', 'SqlPackage.exe')
            if (!(Test-Leaf -LiteralPath $file)) {
                continue
            }

            # Return the info as an object with properties (for sorting).
            return New-Object psobject -Property @{
                File = $file
                Version = $version
            }
        }
    }
}

function Get-MaxInfoFromSqlServerDtaf {
    [CmdletBinding()]
    param()

    $dtafKeyName = 'Software\Microsoft\Microsoft SQL Server\Data-Tier Application Framework'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $dtafKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $i = 0
                if (([int]::TryParse($_, [ref]$i))) {
                    $i
                }
            } |
            Sort-Object -Descending
       foreach ($version in $versions) {
            # Get the install directory.
            $installDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$dtafKeyName\$version" -Value 'InstallDir'
            if (!$installDir) {
                continue
            }

            # Test for SqlPackage.exe.
            $file = [System.IO.Path]::Combine($installDir, 'SqlPackage.exe')
            if (!(Test-Leaf -LiteralPath $file)) {
                continue
            }

            # Return the info as an object with properties (for sorting).
            return New-Object psobject -Property @{
                File = $file
                Version = $version
            }
        }
    }
}

function Get-MaxInfoFromVisualStudio_15_0 {
    [CmdletBinding()]
    param()

    $vs15 = Get-VisualStudio -MajorVersion 15
    if ($vs15 -and $vs15.installationPath) {
        # End with "\" for consistency with old ShellFolder values.
        $shellFolder15 = $vs15.installationPath.TrimEnd('\'[0]) + "\"

        # Test for the DAC directory.
        $dacDirectory = [System.IO.Path]::Combine($shellFolder15, 'Common7', 'IDE', 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
        $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

        if($sqlPacakgeInfo -and $sqlPacakgeInfo.File) {
            return $sqlPacakgeInfo
        }
    }
}

function Get-MaxInfoFromVisualStudio_16_0 {
    [CmdletBinding()]
    param()

    $vs16 = Get-VisualStudio -MajorVersion 16
    if ($vs16 -and $vs16.installationPath) {
        # End with "\" for consistency with old ShellFolder values.
        $shellFolder16 = $vs16.installationPath.TrimEnd('\'[0]) + "\"

        # Test for the DAC directory.
        $dacDirectory = [System.IO.Path]::Combine($shellFolder16, 'Common7', 'IDE', 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
        $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

        if($sqlPacakgeInfo -and $sqlPacakgeInfo.File) {
            return $sqlPacakgeInfo
        }
    }
}

function Get-MaxInfoFromVisualStudio {
    [CmdletBinding()]
    param()

    $visualStudioKeyName = 'Software\Microsoft\VisualStudio'
    foreach ($view in @( 'Registry32', 'Registry64' )) {
        $versions =
            Get-RegistrySubKeyNames -Hive 'LocalMachine' -View $view -KeyName $visualStudioKeyName |
            # Filter to include integer key names only.
            ForEach-Object {
                $d = 0
                if (([decimal]::TryParse($_, [ref]$d))) {
                    $d
                }
            } |
            Sort-Object -Descending
        foreach ($version in $versions) {
            # Get the install directory.
            $installDir = Get-RegistryValue -Hive 'LocalMachine' -View $view -KeyName "$visualStudioKeyName\$version" -Value 'InstallDir'
            if (!$installDir) {
                continue
            }

            # Test for the DAC directory.
            $dacDirectory = [System.IO.Path]::Combine($installDir, 'Extensions', 'Microsoft', 'SQLDB', 'DAC')
            $sqlPacakgeInfo = Get-SqlPacakgeFromDacDirectory -dacDirectory $dacDirectory

            if($sqlPacakgeInfo -and $sqlPacakgeInfo.File)
           {
                return $sqlPacakgeInfo
            }
        }
    }
}

function Get-SqlPacakgeFromDacDirectory {
    [CmdletBinding()]
    param([string] $dacDirectory)


    if (!(Test-Container -LiteralPath $dacDirectory)) {
        return
    }

    # Get the DAC version folders.
    $dacVersions =
        Get-ChildItem -LiteralPath $dacDirectory |
        Where-Object { $_ -is [System.IO.DirectoryInfo] }
        # Filter to include integer key names only.
        ForEach-Object {
            $i = 0
            if (([int]::TryParse($_.Name, [ref]$i))) {
                $i
            }
        } |
        Sort-Object -Descending
    foreach ($dacVersion in $dacVersions) {
        # Test for SqlPackage.exe.
        $file = [System.IO.Path]::Combine($dacDirectory, $dacVersion, 'SqlPackage.exe')
        if (!(Test-Leaf -LiteralPath $file)) {
            continue
        }

        # Return the info as an object with properties (for sorting).
        return New-Object psobject -Property @{
            File = $file
            Version = $dacVersion
        }
    }
}

$sqlPackageInfo = @( )
$sqlPackageInfo += (Get-MaxInfoFromSqlServer)
$sqlPackageInfo += (Get-MaxInfoFromSqlServerDtaf)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio_15_0)
$sqlPackageInfo += (Get-MaxInfoFromVisualStudio_16_0)
$sqlPackageInfo |
    Sort-Object -Property Version -Descending |
    Select -First 1 |
    ForEach-Object { Write-Capability -Name 'SqlPackage' -Value $_.File }

# SIG # Begin signature block
# MIInngYJKoZIhvcNAQcCoIInjzCCJ4sCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCOjTE62sJdoUmq
# k9HIKV1rPBftv+AAM5QuYfoYjKNCpKCCDYEwggX/MIID56ADAgECAhMzAAACzI61
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
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIZczCCGW8CAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAsyOtZamvdHJTgAAAAACzDAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgBwBhPUtN
# sBnHLEYspODWeb+9Hu6oIRGPJHhBotwB8p8wQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBmKyjbYsO5ifxbh+Z7Qz+xB0B2mXjBHGvXy4yl4+OK
# 32NVqJIbFpemKHehF8/wbZLJlZAsuvvGrRoQbgnu/+/XBRU4s4iYYS/qD1c3Rp/e
# qd5FF+cIe65F67w6M1UIumHqssXpMuyZ90cfh4acXR0GLKfzSxxQuaBY/tYg7NUe
# drNrmRScCHVgaa/owd69jichpnfLJlfCGvuTf2sGI5Ne5oYgJB6FKg7EsDyw15ur
# RVYFwRonQCe56WLaJbKKKtdegLeXBD5vPLnMJstm28YVO0U6SuhZcPh6/vuU70jO
# l0pTGWzYx/JGeo4zjtcm/5X13rAB/WQFrV1wGY/bRDRroYIW/TCCFvkGCisGAQQB
# gjcDAwExghbpMIIW5QYJKoZIhvcNAQcCoIIW1jCCFtICAQMxDzANBglghkgBZQME
# AgEFADCCAVEGCyqGSIb3DQEJEAEEoIIBQASCATwwggE4AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEILrcbknaFtDCLaJX40OMSD5nNDbLGX+HXB9CtSlp
# nn+eAgZjbUSlfSoYEzIwMjIxMjEyMTUzNzUwLjU1MlowBIACAfSggdCkgc0wgcox
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRt
# b25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsTHE1p
# Y3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBUU1Mg
# RVNOOjIyNjQtRTMzRS03ODBDMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFt
# cCBTZXJ2aWNloIIRVDCCBwwwggT0oAMCAQICEzMAAAHBPqCDnOAJr8UAAQAAAcEw
# DQYJKoZIhvcNAQELBQAwfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0
# b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3Jh
# dGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcN
# MjIxMTA0MTkwMTI3WhcNMjQwMjAyMTkwMTI3WjCByjELMAkGA1UEBhMCVVMxEzAR
# BgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1p
# Y3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWljcm9zb2Z0IEFtZXJpY2Eg
# T3BlcmF0aW9uczEmMCQGA1UECxMdVGhhbGVzIFRTUyBFU046MjI2NC1FMzNFLTc4
# MEMxJTAjBgNVBAMTHE1pY3Jvc29mdCBUaW1lLVN0YW1wIFNlcnZpY2UwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDksdczJ3DaFQLiklTQjm48mcx5Gbws
# oLjFogO7cXHHciln9Z7apcuPg06ajD9Y8V5ji9pPj9LhP3GgOwUaDnAQkzo4tlV9
# rsFQ27S0O3iuSXtAFg0fPPqlyv1vBqraqbvHo/3KLlbRjyyOiP5BOC2aZejEKg1e
# EnWgboZuoANBcNmRNwOMgCK14TpPGuEGkhvt7q6mJ9MZk19wKE9+7MerrUVIjAnR
# cLFxpHUHACVIqFv81Q65AY+v1nN3o6chwD5Fy3HAqB84oH1pYQQeW3SOEoqCkQG9
# wmcww/5ZpPCYyGhvV76GgIQXH+cjRge6mLrTzaQV00WtoTvaaw5hCvCtTJYJ5KY3
# bTYtkOlPPFlW3LpCsE6T5/4ESuxH4zl6+Qq5RNZUkcje+02Bvorn6CToS5DDShyw
# N2ymI+n6qXEFpbnTJRuvrCd/NiMmHtCQ9x8EhlskCFZAdpXS5LdPs6Q5t0KywJEx
# YftVZQB5Jt6a5So5cJHut2kVN9j9Jco72UIhAEBBKH7DPCHlm/Vv6NPbNbBWXzYH
# LdgeZJPxvwIqdFdIKMu2CjLLsREvCRvM8iQJ8FdzJWd4LXDb/BSeo+ICMrTBB/O1
# 9cV+gxCvxhRwsecC16Tw5U0+5EhXptwRFsXqu0VeaeOMPhnBXEhn8czhyN5UawTC
# QUD1dPOpf1bU/wIDAQABo4IBNjCCATIwHQYDVR0OBBYEFF+vYwnrHvIT6A/m5f3F
# YZPClEL6MB8GA1UdIwQYMBaAFJ+nFV0AXmJdg/Tl0mWnG1M1GelyMF8GA1UdHwRY
# MFYwVKBSoFCGTmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01p
# Y3Jvc29mdCUyMFRpbWUtU3RhbXAlMjBQQ0ElMjAyMDEwKDEpLmNybDBsBggrBgEF
# BQcBAQRgMF4wXAYIKwYBBQUHMAKGUGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9w
# a2lvcHMvY2VydHMvTWljcm9zb2Z0JTIwVGltZS1TdGFtcCUyMFBDQSUyMDIwMTAo
# MSkuY3J0MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQELBQADggIBAF+6JoGCx5we8z3RFmJMOV8duUvT2v1f7mr1yS4xHQGzVKvk
# HYwAuFPljRHeCAu59FfpFBBtJztbFFcgyvm0USAHnPL/tiDzUKfZ2FN/UbOMJvv+
# ffC0lIa2vZDAexrV6FhZ0x+L4RMugRfUbv1U8WuzS3oaLCmvvi2/4IsTezqbXRU7
# B7zTA/jK5Pd6IV+pFXymhQVJ0vbByWBAqhLBsKlsmU0L8RJoNBttAWWL247mPZ/8
# btLhMwb+DLLG8xDlAm6L0XDazuqSWajNChfYCHhoq5sp739Vm96IRM1iXUBk+PSS
# PWDnVU3JaO8fD4fPXFl6RYil8xdASLTCsZ1Z6JbiLyX3atjdlt0ewSsVirOHoVEU
# 55eBrM2x+QubDL5MrXuYDsJMRTNoBYyrn5/0rhj/eaEHivpSuKy2Ral2Q9YSjxv2
# 1uR0pJjTQT4VLkNS2OAB0JpEE1oG7xwVgJsSuH2uhYPFz4iy/zIxABQO4TBdLLQT
# GcgCVxUiuHMvjQ6wbZxrlHkGAB68Y/UeP16PiX/L5KHQdVw303ouY8OYj8xpTasR
# ntj6NF8JnV36XkMRJ0tcjENPKxheRP7dUz/XOHrLazRmxv/e89oaenbN6PB/ZiUZ
# aXVekKE1lN6UXl44IJ9LNRSfeod7sjLIMqFqGBucqmbBwSQxUGz5EdtWQ1aoMIIH
# cTCCBVmgAwIBAgITMwAAABXF52ueAptJmQAAAAAAFTANBgkqhkiG9w0BAQsFADCB
# iDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEyMDAGA1UEAxMp
# TWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5IDIwMTAwHhcNMjEw
# OTMwMTgyMjI1WhcNMzAwOTMwMTgzMjI1WjB8MQswCQYDVQQGEwJVUzETMBEGA1UE
# CBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9z
# b2Z0IENvcnBvcmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQ
# Q0EgMjAxMDCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAOThpkzntHIh
# C3miy9ckeb0O1YLT/e6cBwfSqWxOdcjKNVf2AX9sSuDivbk+F2Az/1xPx2b3lVNx
# WuJ+Slr+uDZnhUYjDLWNE893MsAQGOhgfWpSg0S3po5GawcU88V29YZQ3MFEyHFc
# UTE3oAo4bo3t1w/YJlN8OWECesSq/XJprx2rrPY2vjUmZNqYO7oaezOtgFt+jBAc
# nVL+tuhiJdxqD89d9P6OU8/W7IVWTe/dvI2k45GPsjksUZzpcGkNyjYtcI4xyDUo
# veO0hyTD4MmPfrVUj9z6BVWYbWg7mka97aSueik3rMvrg0XnRm7KMtXAhjBcTyzi
# YrLNueKNiOSWrAFKu75xqRdbZ2De+JKRHh09/SDPc31BmkZ1zcRfNN0Sidb9pSB9
# fvzZnkXftnIv231fgLrbqn427DZM9ituqBJR6L8FA6PRc6ZNN3SUHDSCD/AQ8rdH
# GO2n6Jl8P0zbr17C89XYcz1DTsEzOUyOArxCaC4Q6oRRRuLRvWoYWmEBc8pnol7X
# KHYC4jMYctenIPDC+hIK12NvDMk2ZItboKaDIV1fMHSRlJTYuVD5C4lh8zYGNRiE
# R9vcG9H9stQcxWv2XFJRXRLbJbqvUAV6bMURHXLvjflSxIUXk8A8FdsaN8cIFRg/
# eKtFtvUeh17aj54WcmnGrnu3tz5q4i6tAgMBAAGjggHdMIIB2TASBgkrBgEEAYI3
# FQEEBQIDAQABMCMGCSsGAQQBgjcVAgQWBBQqp1L+ZMSavoKRPEY1Kc8Q/y8E7jAd
# BgNVHQ4EFgQUn6cVXQBeYl2D9OXSZacbUzUZ6XIwXAYDVR0gBFUwUzBRBgwrBgEE
# AYI3TIN9AQEwQTA/BggrBgEFBQcCARYzaHR0cDovL3d3dy5taWNyb3NvZnQuY29t
# L3BraW9wcy9Eb2NzL1JlcG9zaXRvcnkuaHRtMBMGA1UdJQQMMAoGCCsGAQUFBwMI
# MBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1UdDwQEAwIBhjAPBgNVHRMB
# Af8EBTADAQH/MB8GA1UdIwQYMBaAFNX2VsuP6KJcYmjRPZSQW9fOmhjEMFYGA1Ud
# HwRPME0wS6BJoEeGRWh0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3By
# b2R1Y3RzL01pY1Jvb0NlckF1dF8yMDEwLTA2LTIzLmNybDBaBggrBgEFBQcBAQRO
# MEwwSgYIKwYBBQUHMAKGPmh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbS9wa2kvY2Vy
# dHMvTWljUm9vQ2VyQXV0XzIwMTAtMDYtMjMuY3J0MA0GCSqGSIb3DQEBCwUAA4IC
# AQCdVX38Kq3hLB9nATEkW+Geckv8qW/qXBS2Pk5HZHixBpOXPTEztTnXwnE2P9pk
# bHzQdTltuw8x5MKP+2zRoZQYIu7pZmc6U03dmLq2HnjYNi6cqYJWAAOwBb6J6Gng
# ugnue99qb74py27YP0h1AdkY3m2CDPVtI1TkeFN1JFe53Z/zjj3G82jfZfakVqr3
# lbYoVSfQJL1AoL8ZthISEV09J+BAljis9/kpicO8F7BUhUKz/AyeixmJ5/ALaoHC
# gRlCGVJ1ijbCHcNhcy4sa3tuPywJeBTpkbKpW99Jo3QMvOyRgNI95ko+ZjtPu4b6
# MhrZlvSP9pEB9s7GdP32THJvEKt1MMU0sHrYUP4KWN1APMdUbZ1jdEgssU5HLcEU
# BHG/ZPkkvnNtyo4JvbMBV0lUZNlz138eW0QBjloZkWsNn6Qo3GcZKCS6OEuabvsh
# VGtqRRFHqfG3rsjoiV5PndLQTHa1V1QJsWkBRH58oWFsc/4Ku+xBZj1p/cvBQUl+
# fpO+y/g75LcVv7TOPqUxUYS8vwLBgqJ7Fx0ViY1w/ue10CgaiQuPNtq6TPmb/wrp
# NPgkNWcr4A245oyZ1uEi6vAnQj0llOZ0dFtq0Z4+7X6gMTN9vMvpe784cETRkPHI
# qzqKOghif9lwY1NNje6CbaUFEMFxBmoQtB1VM1izoXBm8qGCAsswggI0AgEBMIH4
# oYHQpIHNMIHKMQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSUw
# IwYDVQQLExxNaWNyb3NvZnQgQW1lcmljYSBPcGVyYXRpb25zMSYwJAYDVQQLEx1U
# aGFsZXMgVFNTIEVTTjoyMjY0LUUzM0UtNzgwQzElMCMGA1UEAxMcTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgU2VydmljZaIjCgEBMAcGBSsOAwIaAxUARIo61IrtFVUr5KL5
# qoV3RhJj5U+ggYMwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMDAN
# BgkqhkiG9w0BAQUFAAIFAOdBSEAwIhgPMjAyMjEyMTIxNDI3MTJaGA8yMDIyMTIx
# MzE0MjcxMlowdDA6BgorBgEEAYRZCgQBMSwwKjAKAgUA50FIQAIBADAHAgEAAgIY
# PzAHAgEAAgIRvDAKAgUA50KZwAIBADA2BgorBgEEAYRZCgQCMSgwJjAMBgorBgEE
# AYRZCgMCoAowCAIBAAIDB6EgoQowCAIBAAIDAYagMA0GCSqGSIb3DQEBBQUAA4GB
# ACJjMNQodTZcMizcVitj9ODIvjOahGTlm0OUVZggv2VbIpJcyiP/DgVuDQicN31u
# TdCzaHxcMZx08u1tfk3hLYEUpS0ygpQvAd/VgsZTydhuQf06BMIARioxOkNkypsM
# x/8sH3bUa8JuWux/2F/92XI2+6ffWRXToxdVBV7Gcr1TMYIEDTCCBAkCAQEwgZMw
# fDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1Jl
# ZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMd
# TWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTACEzMAAAHBPqCDnOAJr8UAAQAA
# AcEwDQYJYIZIAWUDBAIBBQCgggFKMBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRAB
# BDAvBgkqhkiG9w0BCQQxIgQglEp9H0SzOrkt/zn5qX66dOtW4IkSvR6ufZhdwmtC
# TVgwgfoGCyqGSIb3DQEJEAIvMYHqMIHnMIHkMIG9BCAKuSDq2Bgd5KAiw3eilHbP
# sQTFYDRiSKuS9VhJMGB21DCBmDCBgKR+MHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQI
# EwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3Nv
# ZnQgQ29ycG9yYXRpb24xJjAkBgNVBAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBD
# QSAyMDEwAhMzAAABwT6gg5zgCa/FAAEAAAHBMCIEIAm802bWRnWTU9r6AnB675Lf
# 7470JKFCI9CwsDIhURGNMA0GCSqGSIb3DQEBCwUABIICACOYXX7AqhGXQztYPtyB
# QzLr+YiVQkYynWyM+BiETyI1HgYR6SsURfX4G0jOZBFe41v3nEEAOFmcfsP6Vr0K
# cSgxRl1vNMWsM4o27gI8PQ1H3UJ1YOmR33OH1klbdvgv+UrMHAYkcx40LLBxydmR
# jo3EcFgxTXT9pnxtUemQs/DUYiZZXzkrFuuEVrmstuTQINacVCmUqukTZLZQfoqY
# IEJxXRJYlsLZ7ZtkzJBS+fICYShCmIKCw4o26DDBUWIS5arDKHzQep95ok5Nqq6g
# cMI9SuZONyK4NiKGdK5BQ7b1tpIq2Flx9NYZlMjak2BmDtbR3VWrZTjZcwZCx1XV
# 98eqpgwg+RZxkEeI7MoR/zUk402TORbz0e98Hx6F4MS0Og8C8Rj0XCzyooSmOYUe
# JRd6okDn/+FIUECxSqJOloQ7Ku3CfwRpEaM63+S4IrVYLAeLzMIAosrGLLa2Lvpx
# UtOXAtkFYPWnqFjWUY0zfHpru4bb6H9J7GKCCWoCNB8Y6nwLSIeBpRaCrCXyveex
# hatCAuqqgHzVa6kn+Lsyw/rdOYEoTBHbhDlG9vs9P/uqd7dXt4vIhzyg25suVK6K
# bELgX2+WNhpcbWOEFKGFIO0D4LZ2pRA308Ddz/OYbzpmH+9MHqVzfIGZxvct8xGZ
# wpYry4cHvMK9bDdjgR9IcFVg
# SIG # End signature block
