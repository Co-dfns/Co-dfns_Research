⍝ Copyright (c) 2022 Aaron W. Hsu. <arcfide@sacrideo.us>

:Namespace UNET

gfx←#.cdgfx.∆

FWD←{Z←(I0 I1 I2)I←(⍳2),∘⊂¨¨⍳∘⍴¨W←⍉∘⍪¨¨⍺
 CV←{0⌈⊃(⍺⊃Z),←⊂(1 1 0↓¯1 ¯1 0↓{,⍵}⌺3 3⊃(⍺⊃Z)←⊂⍵)+.×⍺⊃W}  ⍝ Conv 3×3, RelU
 CC←{⍵,⍨p↓(-p)↓a⊣p←2÷⍨(⍴a←⍺⊃Z)-⍴⍵}                        ⍝ Copy and Crop
 MX←{{⌈⌿⌈⌿⍵}⌺(2 2⍴2)⊢(⍺⊃Z)←⍵}                             ⍝ Max 2×2, Stride 2
 UP←{0⌈⊃(⍺⊃Z),←⊂({,⍵}⌺2 2⊢0⍪0,[1]2⌿2/[1]⊃(⍺⊃Z)←⊂⍵)+.×⍺⊃W} ⍝ Up, Conv 2×2, Relu
 C1←{1E¯8+z÷[⍳2]+/z←*z-[⍳2]⌈/z←((⍺⊃Z)←⍵)+.×⍺⊃W}           ⍝ 1×1, Relu
 LA←{0=≢⍺:⍵ ⋄ I0 I1 I2 I3 I4 I5←0⌷⍺ ⋄ I3 CC I0 UP⊃CV⌿I1 I2,⊂(1↓⍺)∇I3 MX⊃CV⌿I4 I5,⊂⍵}
 (⊂Z),⊂I0 C1⊃CV⌿I1 I2,⊂I LA ⍵}

E←{-+⌿,⍟(⍺×⍵[;;1])+(~⍺)×⍵[;;0]}

BCK←{Y∆ Y←⍵ ⋄ W X←⍺ ⋄ (I0 I1 I2)I←(⍳2),∘⊂¨¨⍳∘⍴¨X ⋄ Y←(~Y),[1.5]Y
 ∆CV←{w←⍉⍪⌽⊖[2]1 0 2 3⍉⍺⊃W ⋄ x a←⍺⊃X ⋄ x←(¯3↑1,⍴x)⍴x←⍉x ⋄ n m←2↑⍴∆z←⍵×a>0
  (⍺⊃W)←(⍪⍉∆z)+.×⍉↑∘.{⍪x[;⍺+⍳m;⍵+⍳n]}⍨⍳3 ⋄ w+.×⍨{,⍵}⌺3 3⊢0⍪0⍪⍨0,[1]∆z,[1]0}
 ∆CC←{x←⍺⊃X ⋄ ∆z←⍵ ⋄ n m←-2÷⍨2↑(⍴x)-⍴∆z ⋄ n⊖m⌽[1](⍴x)↑∆z}
 ∆MX←{x←⍺⊃X ⋄ ∆z←⍵ ⋄ x(⊢×=)2⌿2/[1]∆z}
 ∆UP←{w←⍉⍪⌽⊖[2]1 0 2 3⍉⍺⊃W ⋄ x a←⍺⊃X ⋄ x←⍉0⍪0,[1]2⌿2/[1]x ⋄ n m←2↑⍴∆z←⍵×a>0
  (⍺⊃W)←(⍪⍉∆z)+.×⍉↑∘.{⍪x[;⍺+⍳m;⍵+⍳n]}⍨⍳2 ⋄ 4÷⍨{+⌿+⌿⍵}⌺(2 2⍴2)⊢w+.×⍨{,⍵}⌺2 2⊢0⍪⍨∆z,[1]0}
 ∆C1←{w←⍺⊃W ⋄ x←⍺⊃X ⋄ Y∆ Y←⍵ ⋄ ∆z←Y∆-Y ⋄ (⍺⊃W)←(⍪⍉∆z)+.×⍉⍪⍉x ⋄ ∆z+.×w}
 ∆LA←{0=≢⍺:⍵ ⋄ I0 I1 I2 I3 I4 I5←0⌷⍺
  ⊃∆CV⌿I5 I4,⊂2÷⍨(I3 ∆CC ⍵)+I3 ∆MX(1↓⍺)∇⊃∆CV⌿I2 I1,⊂I0 ∆UP ⍵↑[2]⍨-2÷⍨⊃⌽⍴⍵}
 _←I ∆LA ⊃∆CV⌿I2 I1,⊂I0 ∆C1 Y∆ Y
 W}

K←{⍺←⊢ ⋄ I B S←⍺⊣3 64 2 ⋄ D←⍵ 
 FD←×⍀I B,(D⍴S),÷S ⋄ KS←2/⍪2 3 3 0 3 3 ⋄ LM←1 2 2 2 2 3 1 1 1 1 1 0
 N←{0=×⌿⍵:⍵⍴0 ⋄ (0.5*⍨2÷×⌿1↓⍵)×(0.5*⍨¯2×⍟?⍵⍴0)×1○○2×?⍵⍴0}
 N¨¨(⍬(3 3)(3 3),¨⍨↓3 2⍴2,FD[2,⍨4⍴1])({↓KS,⍨6 2⍴FD[LM+⍵]}⍤0⍳D)}

RUN1←{img y←⍵ ⋄  X Y∆←⍺ FWD img ⋄ n m←2↑⍴Y∆ ⋄ y←n m↑y↓⍨2÷⍨(⍴y)-n m
 #.ERRORS⍪←(1+⊃⊖#.ERRORS),⎕←y E Y∆ ⋄ #.REFERENCE←y ⋄ #.MASK←Y∆[;;1]
 ∆W←⍺ X BCK Y∆ y}

TRAIN←{⍺←100 ⋄ iter←⍺ ⋄ LR MO←1e¯9 0.99 ⋄ data←⍵ ⎕FTIE 0
 update←{#.WEIGHTS←#.WEIGHTS-LR×#.VELOCITY←⍵+MO×#.VELOCITY}
 _←{update #.WEIGHTS RUN1 ⎕FREAD data ⍵}¨∊iter⍴{1+⍳⍵-⍺}⌿2↑⎕FSIZE data
 0⊣⎕FUNTIE data}

CONVERT←{fns2img←⍺⍺ ⋄ files←⍵⍵ ⋄ out←⍺ ⋄ in←⍵
 0⊣⎕FUNTIE tie⊣⎕FAPPEND∘tie∘fns2imgs⍤1⊢files in⊣tie←out ⎕FCREATE 0}

PNGS2IMGS←{_←gfx.∆.Init ⋄ (256÷⍨+⌿÷≢)∘gfx.LoadImage¨⊆⍵}

ISBI∆FILES←{ls←{⊃⎕NINFO⍠1⊢⍵} ⋄ (ls ⍵,'\images\*.png'),⍪ls ⍵,'\labels\*.png'}

∇PLOT
 gfx.Init
 gfx.{⎕←'Stopped plot.'⊣{_←⎕DL .5 ⋄ ⍺ Plot #.ERRORS}Display{#.STOP}⍬}&⍬
 gfx.{⎕←'Stopped reference.'⊣{_←⎕DL .5 ⋄ ⍺ Image #.REFERENCE}Display{#.STOP}⍬}&⍬
 gfx.{⎕←'Stopped mask.'⊣{_←⎕DL .5 ⋄ ⍺ Image #.MASK}Display{#.STOP}⍬}&⍬
∇

∇INIT
 #.STOP←0
 #.ERRORS←⍉⍪0 15000
 #.WEIGHTS←K 4
 #.VELOCITY←⍴∘0∘⍴¨¨#.WEIGHTS
∇

:EndNamespace