:Namespace S1

 ∆←#.gfx.∆ ⋄ Img←∆.Image

 cir←{img←⍵
  _←{xy r rgb←⍵
   img∘←rgb⊣@((⊂xy)+i⌿⍨r≥0.5*⍨+⌿¨×⍨r-i←,⍳0⌈(1+2×r r)⌊xy-⍨1↓⍴img)⍤¯1⊢img
   0}⍤1⊢⍺
  img}

 atan2←{x←⍺ ⋄ y←⍵
  x>0:¯3○y÷x
  (x<0)∧y≥0:(¯3○y÷x)+○1
  (x<0)∧y<0:(¯3○y÷x)-○1
  (x=0)∧y>0:○.5
  (x=0)∧y<0:-○.5
  ⎕SIGNAL 11}
  
 step←{w h r s←⍺⍺ ⋄ age pos dir typ←⍵                       ⍝ State
  age+←1                                                    ⍝ We age once per step
  (m⌿dir)←(○¯1)+2×○?0⍴⍨+/m←(typ>0)∧0=25|age                 ⍝ Change direction every 25 steps
  age pos dir typ⍪←z(m⌿pos)(z←0⍴⍨+⌿m)(-typ⌿⍨m)              ⍝ ...and clone sprites
  (m⌿dir)←atan2/(0⌷pos)-⍤1⊢(m←typ<0)⌿pos                    ⍝ Clones always chase the player
  (0⌷dir)←({⊃⍋.5*⍨+/×⍨⍵}⌷0,⍨atan2/)((typ=¯1)⌿pos)-⍤1⊢0⌷pos  ⍝ Player chases closest green clone
  pos←w h|⍤1⌊0.5+pos+s×⍉2 1∘.○dir                           ⍝ Everybody moves s units each step
  age pos dir typ(⌿⍨)←⊂(typ≥0)∨(2×r)≤.5*⍨+/×⍨(0⌷pos)-⍤1⊢pos ⍝ Player eats overlapping clones
  age pos dir typ(⌿⍨)←⊂(typ≥0)∨age<60                       ⍝ Clones die of old age
  cs←(↓pos),r,⍪rgb[2+typ]                                   ⍝ Sprites are circles
  _←⍺ Img cs cir 3 w h⍴255                                  ⍝ Draw State
  age pos dir typ}

 rgb←(255 128 128)(128 255 128)(0 0 255)(0 255 0)(255 0 0)
 time←200 ⋄ ws←1024 1024 75 15
 initial←(3⍴0)(↑(0 0)(0 1023)(1023 0))(○¯.25 ¯.75 .25)(0 1 2)
 run←{ws step ∆.Display{time≤⊃⊃⍺}initial}

:EndNamespace