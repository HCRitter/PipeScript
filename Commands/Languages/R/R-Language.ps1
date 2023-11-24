
function Language.R {
<#
.SYNOPSIS
    R Language Definition.
.DESCRIPTION
    Allows PipeScript to generate R.
    Because R Scripts only allow single-line comments, this is done using a pair of comment markers.
    # { or # PipeScript{  begins a PipeScript block
    # } or # }PipeScript  ends a PipeScript block
    ~~~r    
    # {
    Uncommented lines between these two points will be ignored
    #  # Commented lines will become PipeScript / PowerShell.
    # param($message = "hello world")
    # "puts `"$message`""
    # }
    ~~~
.EXAMPLE
    Invoke-PipeScript {
        $rScript = '    
    # {
    Uncommented lines between these two points will be ignored
    #  # Commented lines will become PipeScript / PowerShell.
    # param($message = "hello world")
    # "print(`"$message`")"
    # }
    '
    
        [OutputFile('.\HelloWorld.ps1.r')]$rScript
    }
    Invoke-PipeScript .\HelloWorld.ps1.r
#>
[ValidatePattern('\.r$')]
param(
                    
                )
$this = $myInvocation.MyCommand
if (-not $this.Self) {
$languageDefinition = New-Module {
    $LanguageName = 'R'
    $startComment = '(?>(?<IsSingleLine>\#)\s{0,}(?:PipeScript)?\s{0,}\{)'
$endComment   = '(?>\#\s{0,}\}\s{0,}(?:PipeScript)?\s{0,})'
$startPattern = "(?<PSStart>${startComment})"
$endPattern   = "(?<PSEnd>${endComment})"
$LinePattern   = "^\s{0,}\#\s{0,}"
    Export-ModuleMember -Variable * -Function * -Alias *
} -AsCustomObject
$languageDefinition.pstypenames.clear()
$languageDefinition.pstypenames.add("Language")
$languageDefinition.pstypenames.add("Language.R")
$this.psobject.properties.add([PSNoteProperty]::new('Self',$languageDefinition))
}
$this.Self
}



