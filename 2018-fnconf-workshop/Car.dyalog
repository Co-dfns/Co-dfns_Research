:Namespace H1∆Car

 cir ← {img←⍵ ⋄ img⊣{xy r rgb←⍵ ⋄ img∘←rgb⊣@((⊂xy)+i⌿⍨r≥0.5*⍨+⌿¨×⍨r-i←,⍳0⌈(1+2×r r)⌊xy-⍨1↓⍴img)⍤¯1⊢img ⋄ 0}⍤1⊢⍺}
 rec ← {img←⍵ ⋄ img⊣{xy wh rgb←⍵ ⋄ img∘←rgb⊣@((⊂xy)+⍳0⌈wh⌊xy-⍨1↓⍴img)⍤¯1⊢img ⋄ 0}⍤1⊢⍺}                          

 body←2 3⍴(0 30)(200 50)(255 0 0)(50 0)(100 30)(255 0 0)
 wheels←2 3⍴(25 50)25(0 0 0)(125 50)25(0 0 0)
 car←{img←⍵ ⋄ ⍺←0 0 ⋄ x y←⍺ ⋄ mx my←0⌈200 105⌊⍺-⍨1↓⍴img ⋄ img[;i;j]←wheels cir body rec img[;i←x+⍳mx;j←y+⍳my] ⋄ img}

 img←3 500 300⍴255 ⋄ img[0 1;;250+⍳10]←0
 img←(337 200)(15)(0 255 0)cir(350 225)(5 25)(150 75 0)rec img
 
 step←{_←⍺ #.gfx.∆.Image ⍵ 150 car img ⋄ _←⎕DL ⍵⍵ ⋄ ⍵+⍺⍺}
 run←{⍺←0 ⋄ ⍵ step ⍺ #.gfx.∆.Display {⍺=490} 0}

:EndNamespace
