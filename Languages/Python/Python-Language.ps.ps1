Language function Python {
<#
.SYNOPSIS
    Python Language Definition.
.DESCRIPTION
    Allows PipeScript to generate Python.

    Because Python does not support multiline comment blocks, PipeScript can be written inline inside of multiline string

    PipeScript can be included in a Python string that starts and ends with ```{}```, for example ```"""{}"""```
.Example
    .> {
       $pythonContent = @'
"""{
$msg = "Hello World", "Hey There", "Howdy" | Get-Random
@"
print("$msg")
"@
}"""
'@
        [OutputFile('.\HelloWorld.ps1.py')]$PythonContent
    }

    .> .\HelloWorld.ps1.py
.EXAMPLE
    'print("Hello World")' > .\HelloWorld.py
    Invoke-PipeScript .\HelloWorld.py # Should -Be 'Hello World'
#>
[ValidatePattern('\.py$')]
param()
    # The File Pattern for Python is any `.py` files.
    $FilePattern = '\.py$'
    
    # Python doesn't have multi-line comments per se, but it does have ignored block strings.
    # So any `"""{` will start a block    
    $startComment = '(?>"""\{)'
    # and any `}###` will end a block.
    $endComment   = '(?>\}""")'
    
    $startPattern = "(?<PSStart>${startComment})"    
    $endPattern   = "(?<PSEnd>${endComment})"

    # The interpreter for Python is just "python" (if present)
    $Interpreter  = @($ExecutionContext.SessionState.InvokeCommand.GetCommand('python', 'Application'))[0] 
}