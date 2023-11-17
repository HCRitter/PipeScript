
function Language.CSharp {
<#
    .SYNOPSIS
        C# Language Definition.
    .DESCRIPTION
        Allows PipeScript to Generate C#.
        Multiline comments with /*{}*/ will be treated as blocks of PipeScript.
        Multiline comments can be preceeded or followed by 'empty' syntax, which will be ignored.
        The C# Inline Transpiler will consider the following syntax to be empty:
        * ```String.Empty```
        * ```null```
        * ```""```
        * ```''```
    .EXAMPLE
        .> {
            $CSharpLiteral = '
    namespace TestProgram/*{Get-Random}*/ {
        public static class Program {
            public static void Main(string[] args) {
                string helloMessage = /*{
                    ''"hello"'', ''"hello world"'', ''"hey there"'', ''"howdy"'' | Get-Random
                }*/ string.Empty; 
                System.Console.WriteLine(helloMessage);
            }
        }
    }    
    '
            [OutputFile(".\HelloWorld.ps1.cs")]$CSharpLiteral
        }
        $AddedFile = .> .\HelloWorld.ps1.cs
        $addedType = Add-Type -TypeDefinition (Get-Content $addedFile.FullName -Raw) -PassThru
        $addedType::Main(@())    
    #>
[ValidatePattern('\.cs$')]
param(
                    
                )
$this = $myInvocation.MyCommand
if (-not $this.Self) {
$languageDefinition =
New-Module {
    <#
    .SYNOPSIS
        C# Language Definition.
    .DESCRIPTION
        Allows PipeScript to Generate C#.
        Multiline comments with /*{}*/ will be treated as blocks of PipeScript.
        Multiline comments can be preceeded or followed by 'empty' syntax, which will be ignored.
        The C# Inline Transpiler will consider the following syntax to be empty:
        * ```String.Empty```
        * ```null```
        * ```""```
        * ```''```
    .EXAMPLE
        .> {
            $CSharpLiteral = '
    namespace TestProgram/*{Get-Random}*/ {
        public static class Program {
            public static void Main(string[] args) {
                string helloMessage = /*{
                    ''"hello"'', ''"hello world"'', ''"hey there"'', ''"howdy"'' | Get-Random
                }*/ string.Empty; 
                System.Console.WriteLine(helloMessage);
            }
        }
    }    
    '
            [OutputFile(".\HelloWorld.ps1.cs")]$CSharpLiteral
        }
        $AddedFile = .> .\HelloWorld.ps1.cs
        $addedType = Add-Type -TypeDefinition (Get-Content $addedFile.FullName -Raw) -PassThru
        $addedType::Main(@())    
    #>
    [ValidatePattern('\.cs$')]
    param(
    )
    # We start off by declaring a number of regular expressions:
    $startComment = '/\*' # * Start Comments ```\*```
    $endComment   = '\*/' # * End Comments   ```/*```
    $Whitespace   = '[\s\n\r]{0,}'
    # * IgnoredContext ```String.empty```, ```null```, blank strings and characters
    $IgnoredContext = "(?<ignore>(?>$("String\.empty", "null", '""', "''" -join '|'))\s{0,}){0,1}"
    # * StartPattern     ```$IgnoredContext + $StartComment + '{' + $Whitespace```
    $StartPattern = "(?<PSStart>${IgnoredContext}${startComment}\{$Whitespace)"
    # * EndPattern       ```$whitespace + '}' + $EndComment + $ignoredContext```
    $EndPattern   = "(?<PSEnd>$Whitespace\}${endComment}\s{0,}${IgnoredContext})"
    $Compiler = @($ExecutionContext.SessionState.InvokeCommand.GetCommand('dotnet', 'Application'))[0], 'build'  # To compile C#, we'll use dotnet build 
    $Runner  = @($ExecutionContext.SessionState.InvokeCommand.GetCommand('dotnet', 'Application'))[0], 'run' # Get the first dotnet, if present
    Export-ModuleMember -Variable * -Function * -Alias *
} -AsCustomObject
$languageDefinition.pstypenames.clear()
$languageDefinition.pstypenames.add("Language.CSharp")
$this.psobject.properties.add([PSNoteProperty]::new('Self',$languageDefinition))
}
$this.Self
}



