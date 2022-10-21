<#
.SYNOPSIS
    ADA PipeScript Transpiler.
.DESCRIPTION
    Transpiles ADA with Inline PipeScript into ADA.

    Because ADA Scripts only allow single-line comments, this is done using a pair of comment markers.

    -- { or -- PipeScript{  begins a PipeScript block

    -- } or -- }PipeScript  ends a PipeScript block                
.EXAMPLE
    Invoke-PipeScript {
        $AdaScript = '    
    with Ada.Text_IO;

    procedure Hello_World is
    begin
        -- {

        Uncommented lines between these two points will be ignored

        --  # Commented lines will become PipeScript / PowerShell.
        -- param($message = "hello world")        
        -- "Ada.Text_IO.Put_Line (`"$message`");"
        -- }
    end Hello_World;    
    '
    
        [OutputFile('.\HelloWorld.ps1.adb')]$AdaScript
    }

    Invoke-PipeScript .\HelloWorld.ps1.adb
#>
[ValidatePattern('\.ad[bs]$')]
param(
# The command information.  This will include the path to the file.
[Parameter(Mandatory,ValueFromPipeline)]
[Management.Automation.CommandInfo]
$CommandInfo,

# A dictionary of parameters.
[Collections.IDictionary]
$Parameter,

# A list of arguments.
[PSObject[]]
$ArgumentList    
)

begin {
    # We start off by declaring a number of regular expressions:
    $startComment = '(?>--\s{0,}(?:PipeScript)?\s{0,}\{)'
    $endComment   = '(?>--\s{0,}\}\s{0,}(?:PipeScript)?\s{0,})'        
    $startRegex = "(?<PSStart>${startComment})"
    $endRegex   = "(?<PSEnd>${endComment})"

    # Create a splat containing arguments to the core inline transpiler
    $Splat      = [Ordered]@{
        StartPattern  = $startRegex
        EndPattern    = $endRegex
         # Using -LinePattern will skip any inline code not starting with --
        LinePattern   = "^\s{0,}--\s{0,}"
    }
}

process {
    # Add parameters related to the file
    $Splat.SourceFile = $commandInfo.Source -as [IO.FileInfo]
    $Splat.SourceText = [IO.File]::ReadAllText($commandInfo.Source)
    if ($Parameter) { $splat.Parameter = $Parameter }
    if ($ArgumentList) { $splat.ArgumentList = $ArgumentList }

    # Call the core inline transpiler.
    .>PipeScript.Inline @Splat
}
