#requires -Module PSSVG

$psChevron = Invoke-restMethod https://pssvg.start-automating.com/Examples/PowerShellChevron.svg
$RotateEvery = [Timespan]'00:00:15'

$Variants = '', '4-chevron','animated','4-chevron-animated'

foreach ($variant in $variants) {

svg -ViewBox 1920,1080 @(
    svg.defs @(
        SVG.GoogleFont -FontName "Roboto"
        SVG.marker -id 'marker' -ViewBox 100,100 @(
            svg.polygon -Points (@(
                "30,0"
                "35,0"
                "60,50"
                "15,100"
                "12.5,100"
                "55,50"
            ) -join ' ') -Fill '#4488ff' -Class 'foreground-fill'
        ) -MarkerWidth 75 -MarkerHeight 75 -RefX 50 -RefY 50 -Orient 'auto-start-reverse'        
    )
    
    $psChevron.svg.symbol.OuterXml
    
    
    svg.text -FontSize 192 -TextAnchor 'middle' -DominantBaseline 'middle' -X 50% -Y 50% -Content @(
        SVG.tspan -Content "P" -FontSize .9em
        SVG.tspan -Content "|" -FontSize .6em -Dx -.4em
        SVG.tspan -Content "peScr" -FontSize 1em -Dx -.25em
        SVG.tspan -Content "|" -FontSize .6em -Dx -.4em
        SVG.tspan -Content "pt" -FontSize .9em -Dx -.25em
    ) -Style 'font-family: "Roboto", sans-serif' -Fill '#4488ff' -Class 'foreground-fill'

    
    
    foreach ($circleN in 0..2) {
        $radius = 475 - ($circleN * 5)
        $circleTop    = (1920/2), ((1080/2)-$radius)
        $circleMid    = (1920/2), (1080/2)
        $circleRight  = ((1920/2) + $radius),((1080/2))
        $circleBottom = (1920/2), ((1080/2)+$radius)
        $circleLeft   = ((1920/2) - $radius),((1080/2))
        $rotateEach   = $RotateEvery * (1 + $circleN)

        if ($circleN) { 
            if ($variant -in '', '4-chevron') {
                continue 
            }            
        } 

        $strokeWidth  = 1.25 - ($circleN * .05)
        $Opacity = 1 - ($circleN * .05)
        SVG.ArcPath -Start $circleLeft -End $circleBottom -Sweep -Radius $radius -Large -Opacity $Opacity |
            SVG.ArcPath -Radius $radius -End $circleLeft -Sweep -Stroke '#4488ff' -Class foreground-stroke -fill transparent -markerEnd "url(#marker)" -strokeWidth $strokeWidth -Content @(
                if ($variant -match 'animated') {
                    svg.animateTransform -AttributeName transform -From "360 $circleMid"  -To "0 $circleMid" -dur "$($rotateEach.TotalSeconds)s" -RepeatCount 'indefinite' -AttributeType 'XML' -Type 'rotate'
                }                
            ) -Opacity $Opacity
       
            SVG.ArcPath -Start $circleRight -End $circleTop -Sweep -Radius $radius -Large -Opacity $Opacity |
                SVG.ArcPath -Radius $radius -End $circleRight -Sweep -Stroke '#4488ff' -Class foreground-stroke -fill transparent -markerEnd "url(#marker)" -strokeWidth $strokeWidth -Content @(
                    if ($variant -match 'animated') {
                        svg.animateTransform -AttributeName transform -From "360 $circleMid"  -To "0 $circleMid" -dur "$($rotateEach.TotalSeconds)s" -RepeatCount 'indefinite' -AttributeType 'XML' -Type 'rotate'
                    }
                ) -Opacity $Opacity
        if ($variant -match '4-chevron') {

        SVG.ArcPath -Start $circleTop -End $circleLeft -Sweep -Radius $radius -Large -Opacity $Opacity |
            SVG.ArcPath -Radius $radius -End $circleTop -Sweep -Stroke '#4488ff' -Class foreground-stroke -fill transparent -markerEnd "url(#marker)" -strokeWidth $strokeWidth -Content @(
                if ($variant -match 'animated') {
                    svg.animateTransform -AttributeName transform -From "360 $circleMid"  -To "0 $circleMid" -dur "$($rotateEach.TotalSeconds)s" -RepeatCount 'indefinite' -AttributeType 'XML' -Type 'rotate'
                }
            ) -Opacity $Opacity

        SVG.ArcPath -Start $circleBottom -End $circleRight -Sweep -Radius $radius -Large |
            SVG.ArcPath -Radius $radius -End $circleBottom -Sweep -Stroke '#4488ff' -Class foreground-stroke -fill transparent -markerEnd "url(#marker)" -strokeWidth $strokeWidth -Content @(
                if ($variant -match 'animated') {
                    svg.animateTransform -AttributeName transform -From "360 $circleMid"  -To "0 $circleMid" -dur "$($rotateEach.TotalSeconds)s" -RepeatCount 'indefinite' -AttributeType 'XML' -Type 'rotate'
                }
            )
        }
    }     
) -OutputPath (
    Join-Path ($PSScriptRoot | Split-Path) Assets | Join-Path -ChildPath "PipeScript$(if ($variant) { "-$Variant"}).svg"
)
}