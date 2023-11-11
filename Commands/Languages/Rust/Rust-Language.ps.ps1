Language function Rust {
    <#
    .SYNOPSIS
        Rust Language Definition
    .DESCRIPTION
        Defines Rust within PipeScript.

        This allows Rust to be templated.
    .EXAMPLE
        Invoke-PipeScript -ScriptBlock {
            $HelloWorldRustString = '    
            fn main() {
                let msg = /*{param($msg = ''hello world'') "`"$msg`""}*/ ;
                println!("{}",msg);
            }
            '
            $HelloWorldRust = HelloWorld_Rust.rs template $HelloWorldRustString
            "$HelloWorldRust"
        }
    .EXAMPLE
        Invoke-PipeScript -ScriptBlock {
            $HelloWorldRust = HelloWorld_Rust.rs template '    
            $HelloWorld = {param([Alias(''msg'')]$message = "Hello world") "`"$message`""}
            fn main() {
                let msg = /*{param($msg = ''hello world'') "`"$msg`""}*/ ;
                println!("{}",msg);
            }
            '
        
            $HelloWorldRust.Evaluate('hi')
            $HelloWorldRust.Save(@{Message='Hello'})
        }
    .EXAMPLE
        '    
        fn main() {
            let msg = /*{param($msg = ''hello world'') "`"$msg`""}*/ ;
            println!("{}",msg);
        }
        ' | Set-Content .\HelloWorld_Rust.ps.rs

        Invoke-PipeScript .\HelloWorld_Rust.ps.rs
    .EXAMPLE
        $HelloWorld = {param([Alias('msg')]$message = "Hello world") "`"$message`""}
        "    
        fn main() {
            let msg = /*{$HelloWorld}*/ ;
            println!(`"{}`",msg);
        }
        " | Set-Content .\HelloWorld_Rust.ps1.rs

        Invoke-PipeScript .\HelloWorld_Rust.ps1.rs -Parameter @{message='hi'}
    #>
    [ValidatePattern('\.rs$')]
    [Alias('Rust-Language','Language-Rust')]
    param()

    # We start off by declaring a number of regular expressions:
    $startComment = '/\*' # * Start Comments ```\*```
    $endComment   = '\*/' # * End Comments   ```/*```
    $Whitespace   = '[\s\n\r]{0,}'
    # * StartPattern  ```$IgnoredContext + $StartComment + '{' + $Whitespace```
    $StartPattern = "(?<PSStart>${startComment}\{$Whitespace)"
    # * EndPattern    ```$whitespace + '}' + $EndComment + $ignoredContext```
    $EndPattern   = "(?<PSEnd>$Whitespace\}${endComment})"
}