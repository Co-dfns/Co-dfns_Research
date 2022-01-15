 ppm∆load←{dat←'' ⋄ tie←⍵ ⎕NTIE 0                     
     _←{dat,←⎕NREAD tie 80 1}⍣{3≤lf∘←lf+⍺=⎕UCS 10}lf←0
     k s r←¯1↓¨(¯1⌽dat=⎕UCS 10)⊂dat                   
     d←⎕NREAD tie 83 ¯1                               
     _←⎕NUNTIE tie                                    
     k(⌽⍎s)(⍎r)(1 2 0⍉(3,⍨⌽⍎s)⍴d)}