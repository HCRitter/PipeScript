function Export-Pipescript {
    <#
    .Synopsis
        Builds and Exports using PipeScript
    .Description
        Builds and Exports a path, using PipeScript.
        
        Any Source Generator Files Discovered by PipeScript will be run, which will convert them into source code.
    .EXAMPLE
        Export-PipeScript -Serial   # (PipeScript builds in parallel by default)
    #>
    [Alias('Build-PipeScript','bps','eps','psc')]
    param(
    # One or more input paths.  If no -InputPath is provided, will build all scripts beneath the current directory.
    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('FullName')]
    [string[]]
    $InputPath,

    # If set, will prefer to build in a series, rather than in parallel.
    [switch]
    $Serial,

    # The number of files to build in each batch.
    [int]
    $BatchSize = 11,

    # The throttle limit for parallel jobs.
    [int]
    $ThrottleLimit = 7
    )

    begin {
        function AutoRequiresSimple {
            param(
            [Management.Automation.CommandInfo]
            $CommandInfo
            )

            process {
                if (-not $CommandInfo.ScriptBlock) { return }
                $simpleRequirements = 
                    foreach ($requiredModule in $CommandInfo.ScriptBlock.Ast.ScriptRequirements.RequiredModules) {
                        if ($requiredModule.Name -and 
                            (-not $requiredModule.MaximumVersion) -and
                            (-not $requiredModule.RequiredVersion)
                        ) {
                            $requiredModule.Name
                        }
                    }

                if ($simpleRequirements) {
                    if ($env:GITHUB_WORKSPACE) {
                        $ManifestsInWorkspace = Get-ChildItem -Recurse -Filter *.psd1 |
                            Where-Object {
                                $_.Name -match "^(?>$(@(
                                    foreach ($simplyRequires in $simpleRequirements) {
                                        [Regex]::Escape($simplyRequires)
                                    }
                                ) -join '|')).psd1$"
                            } | Select-String "ModuleVersion"

                        $simpleRequirements = @(
                            foreach ($simplyRequires in $simpleRequirements) {
                                if ($ManifestsInWorkspace.Path -match "^$([Regex]::Escape($simplyRequires))\.psd1$") {
                                    $importedRequirement = Import-Module -Path $ManifestsInWorkspace.Path -Global -PassThru
                                    if ($importedRequirement) {
                                        continue
                                    }
                                }
                                $simplyRequires
                            }
                        )
                    }
                    Invoke-PipeScript "require latest $($simpleRequirements)"
                }                
            }
        }

        filter BuildSingleFile {
            param($buildFile)
            if ((-not $PSBoundParameters['BuildFile']) -and $_) { $buildFile = $_}
            $buildFileInfo = $buildFile.Source -as [IO.FileInfo]
            if (-not $buildFileInfo) { return }
            $TotalInputFileLength += $buildFileInfo.Length

            $buildFileTemplate = $buildFile.Template
            if ($buildFileTemplate -and $buildFile.PipeScriptType -ne 'Template') {
                AutoRequiresSimple -CommandInfo $buildFileTemplate
                try {
                    Invoke-PipeScript $buildFileTemplate.Source
                } catch {
                    $ex = $_
                    Write-Error -ErrorRecord $ex -TargetObject $buildFileInfo
                    if ($env:GITHUB_WORKSPACE -or ($host.Name -eq 'Default Host')) {
                        $fileAndLine = @(@($ex.ScriptStackTrace -split [Environment]::newLine)[-1] -split ',\s',2)[-1]
                        $file, $line = $fileAndLine -split ':\s\D+\s', 2
                        
                        "::error file=$($buildFile.FullName),line=$line::$($ex.Exception.Message)" | Out-Host
                    }
                }
                if ($alreadyBuilt.Count) {
                    $alreadyBuilt[$buildFileTemplate.Source] = $true
                }
            }

            $EventsFromThisBuild = Get-Event |
                Where-Object TimeGenerated -gt $ThisBuildStartedAt |
                Where-Object SourceIdentifier -Like '*PipeScript*'
            AutoRequiresSimple -CommandInfo $buildFile
            $FileBuildStarted = [datetime]::now
            $buildOutput = 
                try {
                    if ($buildFile.PipeScriptType -match 'BuildScript') {
                        if ($buildFile.ScriptBlock.Ast -and $buildFile.ScriptBlock.Ast.Find({param($ast)
                            if ($ast -isnot [Management.Automation.Language.CommandAst]) { return $false }
                            if ('task' -ne $ast.CommandElements[0]) { return $false }
                            return $true
                        }, $true)) {
                            Invoke-PipeScript "require latest InvokeBuild"
                            Invoke-Build -File $buildFile.Source -Result InvokeBuildResult
                        } else {
                            Invoke-PipeScript $buildFile.Source    
                        }
                    } else {
                        Invoke-PipeScript $buildFile.Source
                    }                    
                } catch {
                    $ex = $_
                    Write-Error -ErrorRecord $ex
                    $filesWithErrors += $buildFile.Source -as [IO.FileInfo]
                    $errorsByFile[$buildFile.Source] = $ex
                }

            $EventsFromFileBuild = Get-Event -SourceIdentifier *PipeScript* |
                Where-Object TimeGenerated -gt $FileBuildStarted |
                Where-Object SourceIdentifier -Like '*PipeScript*'

            if ($buildOutput) {
                
                if ($buildOutput -is [IO.FileInfo]) {
                    $TotalOutputFileLength += $buildOutput.Length
                }
                elseif ($buildOutput -as [IO.FileInfo[]]) {
                    foreach ($_ in $buildOutput) {
                        if ($_.Length) {
                            $TotalOutputFileLength += $_.Length
                        }
                    }
                }

                if ($env:GITHUB_WORKSPACE -or ($host.Name -eq 'Default Host')) {
                    $FileBuildEnded = [DateTime]::now
                    "$($buildFile.Source)", "$('=' * $buildFile.Source.Length)", "Output:" -join [Environment]::newLine | Out-Host
                    if ($buildOutput -is [Management.Automation.ErrorRecord]) {
                        $buildOutput | Out-Host
                    } else {
                        $buildOutput.FullName | Out-Host
                    }
                    $totalProcessTime = 0 
                    $timingOfCommands = $EventsFromFileBuild | 
                        Where-Object { $_.MessageData.Command -and $_.MessageData.Duration} |
                        Select-Object -ExpandProperty MessageData | 
                        Group-Object Command |
                        Select-Object -Property @{
                            Name = 'Command'
                            Expression = { $_.Name }
                        }, Count, @{
                            Name= 'Duration'
                            Expression = { 
                                $totalDuration = 0
                                foreach ($duration in $_.Group.Duration) { 
                                    $totalDuration += $duration.TotalMilliseconds
                                }
                                [timespan]::FromMilliseconds($totalDuration)
                            }
                        } | 
                        Sort-Object Duration -Descending
                        
                    $postProcessMessage = @(
                        
                    foreach ($evt in $completionEvents) {
                        $totalProcessTime += $evt.MessageData.TotalMilliseconds
                        $evt.SourceArgs[0]
                        $evt.MessageData
                    }) -join ' '
                    "Built in $($FileBuildEnded - $FileBuildStarted)" | Out-Host
                    "Commands Run:" | Out-Host
                    $timingOfCommands | Out-Host
                    Get-Event -SourceIdentifier PipeScript.PostProcess.Complete -ErrorAction Ignore | Remove-Event
                }

                if ($ExecutionContext.SessionState.InvokeCommand.GetCommand('git', 'Alias')) {
                    $lastCommitMessage = ($buildFileInfo | git log -n 1 | Select-Object -ExpandProperty CommitMessage -First 1)
                    $buildOutput |
                        Add-Member NoteProperty CommitMessage $lastCommitMessage -Force
                }
                
                $buildOutput | 
                    Add-Member NoteProperty BuildSourceFile $buildFileInfo -Force -PassThru
            }
        }

        $filesWithErrors = @()
        $errorsByFile = @{}
        $errorsOfUnknownOrigin = @()

        $startThreadJob = $ExecutionContext.SessionState.InvokeCommand.GetCommand('Start-ThreadJob','Cmdlet')

        if ($startThreadJob) {
            $ugitImported = @(Get-Module) -match '^ugit$'
            $Psd1sToImport = @(
                "'$($MyInvocation.MyCommand.Module.Path -replace '\.psm1', '.psd1')'"
                if ($ugitImported) {
                    "'$((Get-Module ugit).Path -replace '\.psm1', '.psd1')'"
                }
            ) -join ","
            $InitializationScript = [scriptblock]::Create("
                Import-Module $Psd1sToImport
                function AutoRequiresSimple {$function:AutoRequiresSimple}
                filter BuildSingleFile {$function:BuildSingleFile}
            ")
            $ThreadJobScript = {                
                $args | BuildSingleFile
            }
        }
    }

    process {       
        if ($env:GITHUB_WORKSPACE) {
            "::group::Discovering files", "from: $InputPath" | Out-Host
        }
        $filesToBuild = 
            @(if (-not $InputPath) {
                Get-PipeScript -PipeScriptPath $pwd |
                    Where-Object PipeScriptType -Match '(?>Template|BuildScript)' |
                    Sort-Object PipeScriptType, Order, Source
            } else {
                foreach ($inPath in $InputPath) {
                    Get-PipeScript -PipeScriptPath $inPath |
                        Where-Object PipeScriptType -Match '(?>Template|BuildScript)' |
                        Sort-Object PipeScriptType, Order, Source
                }
            })

        if ($env:GITHUB_WORKSPACE) {           
            $filesToBuild.Source -join [Environment]::NewLine | Out-Host           
        }
        
        $buildStarted = [DateTime]::Now
        $alreadyBuilt = [Ordered]@{}
        $filesToBuildCount, $filesToBuildTotal, $filesToBuildID  = 0, $filesToBuild.Length, $(Get-Random)

        if ($env:GITHUB_WORKSPACE) {
            "::group::Building PipeScripts [$FilesToBuildCount / $filesToBuildTotal]" | Out-Host                
        }
        # Keep track of how much is input and output.
        [long]$TotalInputFileLength  = 0 
        [long]$TotalOutputFileLength = 0 
        
        # If we're only building one file, there's no point in parallelization.
        if ($filesToBuild.Length -le 1) { $Serial = $true }

        if (-not $startThreadJob) { continue }
        $buildThreadJobs = [Ordered]@{}         
        $pendingBatch = @()
        foreach ($buildFile in $filesToBuild) {
            $ThisBuildStartedAt = [DateTime]::Now
            Write-Progress "Building PipeScripts [$FilesToBuildCount / $filesToBuildTotal]" "$($buildFile.Source) " -PercentComplete $(
                $FilesToBuildCount++
                $FilesToBuildCount * 100 / $filesToBuildTotal 
            ) -id $filesToBuildID
            
            if (-not $buildFile.Source) { continue }
            if ($alreadyBuilt[$buildFile.Source]) { continue }
            
            if ((-not $Serial) -and $startThreadJob) {
                $pendingBatch += $buildFile
                if ($pendingBatch.Length -ge $BatchSize) {
                    $buildThreadJobs["$pendingBatch"]  = Start-ThreadJob -InitializationScript $InitializationScript -ScriptBlock $ThreadJobScript -ArgumentList $pendingBatch -ThrottleLimit $ThrottleLimit
                    $pendingBatch = @()
                }
                
            } else {
                $buildFile | . BuildSingleFile
            }            
            
            $alreadyBuilt[$buildFile.Source] = $true
        }

        if ($pendingBatch.Length) {
            $buildThreadJobs["$pendingBatch"]  = Start-ThreadJob -InitializationScript $InitializationScript -ScriptBlock $ThreadJobScript -ArgumentList $pendingBatch -ThrottleLimit $ThrottleLimit
            $pendingBatch = @()
        }
        $OriginalJobCount = $buildThreadJobs.Count
        

        while ($buildThreadJobs.Count) {
            $remainingJobCount = ($OriginalJobCount - $buildThreadJobs.Count)
            Write-Progress "Waiting for Builds [$remainingJobCount / $originalJobCount]" " " -PercentComplete $(                
                ($OriginalJobCount - $buildThreadJobs.Count) * 100 / $OriginalJobCount
            ) -id $filesToBuildID
            $completedBuilds = @(foreach ($threadKeyValue in $buildThreadJobs.GetEnumerator()) {
                if ($threadKeyValue.Value.State -in 'Completed','Failed','Stopped') {
                    $threadKeyValue
                }
            })
            if (-not $completedBuilds) {
                Start-Sleep -Milliseconds 7
                continue
            }

            foreach ($completedBuild in $completedBuilds) {

                
                $completedBuildOutput = $completedBuild.Value | Receive-Job *>&1
                

                if ($env:GITHUB_WORKSPACE -or ($host.Name -eq 'Default Host')) {
                    $completedBuildOutput | Out-Host
                }                     
                $sourceFilesFromJob = @(foreach ($buildOutput in $completedBuildOutput) {
                    
                    if ($buildOutput -is [IO.FileInfo]) {
                        $TotalOutputFileLength += $buildOutput.Length
                        if ($buildOutput.BuildSourceFile) {
                            $buildOutput.BuildSourceFile
                        }
                    }
                    elseif ($buildOutput -as [IO.FileInfo[]]) {
                        foreach ($_ in $buildOutput) {
                            if ($_.Length) {
                                $TotalOutputFileLength += $_.Length
                                if ($_.BuildSourceFile) {
                                    $_.BuildSourceFile
                                }
                            }
                        }
                    }
                    elseif ($buildOutput -is [Management.Automation.ErrorRecord]) {
                        $buildSourceFile = $buildOutput.TargetObject
                        if ($buildSourceFile -is [IO.FileInfo]) {
                            if (-not $errorsByFile[$buildSourceFile]) {
                                $errorsByFile[$buildSourceFile] = @()
                            }
                            $errorsByFile[$buildSourceFile] += $buildOutput
                            $buildSourceFile
                        } else {
                            $errorsOfUnknownOrigin += $buildOutput
                        }                        
                    }
                })
                
                foreach ($buildSourceFile in $sourceFilesFromJob) {
                    $TotalInputFileLength += $buildSourceFile.Length
                    if ($errorsByFile[$buildSourceFile]) {
                        $filesWithErrors += $buildSourceFile
                    }
                }
                
                foreach ($buildOutput in $completedBuildOutput) {
                    if ($buildOutput -is [IO.FileInfo]) {
                        $buildOutput
                    }
                }
                $buildThreadJobs.Remove($completedBuild.Key)
            }            
        }
        
        $BuildTime = [DateTime]::Now - $buildStarted
        if ($env:GITHUB_WORKSPACE -or ($host.Name -eq 'Default Host')) {
            "$filesToBuildTotal in $($BuildTime)" | Out-Host
            "::endgroup::Building PipeScripts [$FilesToBuildCount / $filesToBuildTotal] : $($buildFile.Source)" | Out-Host
            if ($TotalInputFileLength) {
                "$([Math]::Round($TotalInputFileLength / 1kb)) kb input"
                "$([Math]::Round($TotalOutputFileLength / 1kb)) kb output",
                "PipeScript Factor: X$([Math]::round([double]$TotalOutputFileLength/[double]$TotalInputFileLength,4))"
            }            
        }
        
        if ($filesWithErrors) {
            "$($filesWithErrors.Length) files with Errors" | Out-Host
            foreach ($fileWithError in $filesWithErrors) {
                "$fileWithError : $($errorsByFile[$fileWithError.FullName] | Out-String)"| Out-Host
            }
        }

        if ($errorsOfUnknownOrigin) {
            "$($errorsOfUnknownOrigin) errors of unknown origin" | Out-Host            
            $errorsOfUnknownOrigin| Out-Host            
        }

        
        Write-Progress "Building PipeScripts [$FilesToBuildCount / $filesToBuildTotal]" "Finished In $($BuildTime) " -Completed -id $filesToBuildID
    }
}
