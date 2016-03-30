extensions [table]

globals [
  time
  tool
]


; --- Agents ---
breed [ bases base ]
bases-own [
  food-level
  minerals-level
  health
]

breed [terminators terminator]
terminators-own[dest]

breed [players player]
players-own [
  gather
  hunter
  soldier
  explorer
  in-team-A?
  in-team-B?
  desire intention
  hunger
  not-hungry
  base-food-level
  food-places
  food-patch-level
  food-storage
  minerals-places
  minerals-patch-level
  minerals-storage
  max-food-capacity
  max-minerals-capacity
  inbox
  outbox
  enemy-base
  max-not-hungry
  explore-at
]

patches-own [
  minerals
  food
]

; --- Setup ---
to setup
  clear-all
  set time 0
  let rnd random 500
  load-map
  random-seed rnd
  setup-humans
  setup-bases
  setup-patches                       ;
  reset-ticks
end


; --- Main processing cycle ---
to go
  grow-resources
  update-graphics
  update-beliefs
  update-desires
  update-intentions
  execute-actions
  send-messages
  update-patches

  ask players with [hunger <= 0] [ die ]

  let to-stop false
  ask bases [
    if health <= 0 [
      let opponent-color 0
      if-else color = red [
        set opponent-color "white"
      ] [
        set opponent-color "red"
      ]
      user-message (word "Team " opponent-color " won the game!")
      set to-stop true
    ]
  ]
  if to-stop [ stop ]

  tick
  set time time + 1
end


to load-map
  if length map-name < 1 [
    user-message "Map name not inserted."
    stop
  ]
  import-world (word "./map-" map-name ".csv")
end

to setup-humans
  ;; assemble teams
  repeat team_A_size [ make-player red ]
  repeat team_B_size [ make-player white ]
end

to setup-bases
  ask bases [
    set food-level 0
    set minerals-level 0
    set health 100
  ]
end

to setup-patches
  ask patches [
    if-else pcolor = yellow [
      set minerals 50
    ] [
      if pcolor = brown [
        set food 5000
      ]
    ]
  ]
end

to make-player [player-color]
  create-players 1 [
    set shape "person"
    set color player-color
    if-else player-color = red [
      set in-team-A? true
    ] [
      set in-team-A? false
    ]
    give-skills
    set max-food-capacity (hunter * 100)
    set max-minerals-capacity (gather)
    set not-hungry (random 500) + 500
    set hunger not-hungry
    set food-places (list)
    set food-storage 0
    set minerals-places (list)
    set minerals-storage 0
    set inbox (list)
    set outbox (list)
    set enemy-base (list)
    setxy random max-pxcor random max-pycor
    facexy min-pxcor min-pycor + 1
  ]


end

to give-skills
  let my_l sequence
  setxy random max-pxcor random max-pycor
  facexy min-pxcor min-pycor + 1
  set size 1.6
  set hunter first my_l
  set gather item 1 my_l
  set soldier last my_l
end

to-report sequence
  let a 35 + random (25)
  let b 1 + random (6)
  let c 35 + random (30)
  let my_list (list a b c)
  ;;let my_l shuffle my_list
  report my_list
end

to grow-resources    ;
  ask patches [
    if pcolor = black [
      if random-float 1000 < resource-growth-rate / 10
        [ set pcolor yellow
          set minerals 50
          ]
    ]
    if pcolor = grey [
      if random-float 1000 < resource-growth-rate / 10
        [ set pcolor brown
          set food 5000
           ]
  ] ]
end

; tells wether the patch x1, y1 is closer to the agent position (represented by xa and ya) than the patch at x2, y2
to-report point-distance [x1 y1 x2 y2 xa ya]
  report sqrt ( (x1 - xa) ^ 2 + (y1 - ya) ^ 2 ) < sqrt ( (x2 - xa) ^ 2 + (y2 - ya) ^ 2 )
end

to-report get-food-base-dist
  let closest-food first food-places
  let food-dist distancexy first closest-food last closest-food
  report (food-dist + base-dist)
end

to-report base-dist
  let dist 0
  ask bases with [color = [color] of myself] [
    set dist distance myself
  ]
  report dist
end

to update-graphics
  ask players [
    set label hunger
  ]
end

to update-patches
  ask patches [
    if-else pcolor = yellow and minerals < 1 [
      set pcolor black
    ] [
      if pcolor = brown and food < 1 [
        set pcolor grey
      ]
    ]
  ]
end

; --- Update desires ---
to update-beliefs
  ask players [
    set hunger (hunger - food-decay)

    let not-hungry-list [not-hungry] of players with-max [not-hungry]
    if length not-hungry-list > 0 [
      set max-not-hungry (first not-hungry-list) + 50
    ]

    if length inbox > 0 [
      let minerals-msg filter [first ? = yellow] outbox
      set minerals-msg map [(list item 1 ? last ?)] minerals-msg
      set minerals-places sentence minerals-places minerals-msg

      let food-msg filter [first ? = brown] outbox
      set food-msg map [(list item 1 ? last ?)] food-msg
      set food-places sentence food-places food-msg

      set inbox (list)
    ]

    let i 0
    let to-remove (list)

    set food-places sentence food-places [list pxcor pycor] of patches in-radius vision-radius with [pcolor = brown]
    set food-places remove-duplicates food-places
    set i 0
    set to-remove (list)
    while [i < length food-places] [
      let food-place item i food-places
      if [food] of patch first food-place last food-place < 1 [
        set to-remove sentence to-remove i
      ]
      set i i + 1
    ]
    foreach to-remove [ set food-places remove-item ? food-places ]
    set food-places sort-by [ point-distance first ?1 last ?1 first ?2 last ?2 xcor ycor ] food-places
    if pcolor = brown [
      set food-patch-level [food] of patch-here
    ]

    set minerals-places sentence minerals-places [list pxcor pycor] of patches in-radius vision-radius with [pcolor = yellow]
    set minerals-places remove-duplicates minerals-places
    set i 0
    set to-remove (list)
    while [i < length minerals-places] [
      let minerals-place item i minerals-places
      let current-minerals-level [minerals] of patch first minerals-place last minerals-place
      if current-minerals-level < 1 [
        set to-remove sentence to-remove i
      ]
      set i i + 1
    ]
    foreach to-remove [ set minerals-places remove-item ? minerals-places ]
    set minerals-places sort-by [ point-distance first ?1 last ?1 first ?2 last ?2 xcor ycor ] minerals-places
    if pcolor = yellow [
      set minerals-patch-level [minerals] of patch-here
    ]

    if count bases in-radius 1 with [color = [color] of myself] > 0 [
      let food-level-list [food-level] of bases with [color = [color] of myself]
      if not empty? food-level-list [
        set base-food-level first food-level-list
      ]
    ]

    set outbox ([(list pcolor pxcor pycor)] of patches in-radius vision-radius with [pcolor = yellow or pcolor = brown])

    let new-enemy-base [(list pxcor pycor)] of bases in-radius vision-radius with [color != [color] of myself]    ;find enemy base
    if not empty? enemy-base and first enemy-base != 0 [ set new-enemy-base sentence enemy-base new-enemy-base ]
    set enemy-base remove-duplicates new-enemy-base

    ; set explore-at
    if explore-at = 0 or (round xcor = [pxcor] of explore-at and round ycor = [pycor] of explore-at) [
      let done false
      while [not done] [
        let rndheading random 360
        let explore-patch patch-at-heading-and-distance rndheading ((random max-pxcor - 10) + 10)
        if explore-patch != nobody [
          let other-lst [explore-at] of other players with [color = [color] of myself]
          if not member? explore-patch other-lst [ set done true ]
          if done [ set explore-at explore-patch ]
        ]
      ]
    ]
  ]
end


; --- Update desires ---
to update-desires
  ask players [
    if-else hunger < (base-dist * food-decay) + 1 [
      set desire "eat"
    ] [
      let base-minerals [minerals-level] of bases with [color = [color] of myself]
      if-else (not empty? base-minerals and first base-minerals < 30) or max-not-hungry > base-food-level [
        set desire "collaborate"
      ] [
        set desire "attack"
      ]
    ]
  ]
end


; --- Update intentions ---
to update-intentions
  ask players [
    if-else desire = "eat" [
      if-else base-dist < 1 [
        if-else base-food-level > not-hungry [
          set intention "grab-food"
        ] [
        if-else max-not-hungry * food-decay > base-food-level [
          set intention "get-food"
          ][
          set intention "wait-food"
          ]
        ]
      ] [
        if-else max-not-hungry > base-food-level [
          if-else pcolor = brown and food-patch-level > 0 [
            if-else food-storage < max-food-capacity [
              set intention "pick-up food"
            ] [
              set intention "goto-base"
            ]
          ] [
            if-else food-storage < max-food-capacity [
              set intention "get-food"
            ] [
              set intention "goto-base"
            ]
          ]
        ] [
          set intention "goto-base"
        ]
      ]
    ] [
    ;desire is "collaborate"
    if-else desire = "collaborate"[
      if-else base-dist < 1 [
        if-else minerals-storage > 0 [
          set intention "deposit-minerals"
        ][
        if-else food-storage > 0 [
          set intention "deposit-food"
        ][
        if-else base-food-level < max-not-hungry [ ; case when there's not enough food at base
          if-else length food-places > 0 [
            set intention "get-food"
          ] [
          set intention "explore"
          ]
        ]
        [; case with enough food at base
          if-else length minerals-places > 0 [
            set intention "get-minerals"
          ][
          set intention "explore"
          ]
        ]
        ]
        ]
      ] [ ; case far from base

      if-else food-storage = max-food-capacity or minerals-storage = max-minerals-capacity [
        ; intention to return to base to empty bag ; Define Threshold
        ; QUESTION: can we check other agents' desires to determine whether to pick up food only or also minerals?
        set intention "goto-base"
      ] [
       if-else pcolor = yellow and minerals-patch-level > 0 [
         set intention "pick-up metals"
         ][
         if-else pcolor = brown and food-patch-level > 0[
           set intention "pick-up food"
           ][
           if-else length minerals-places > 0 [
            set intention "get-minerals"
          ][
          set intention "explore"
          ]


           ;if intention != 0[
           ;set intention "reach-goal"
           ;]
           ]
         ]
      ]
      ]
    ]
    [
      if-else desire = "attack"[
        if-else length enemy-base = 0 [
          set intention "find-enemy-base"
        ][
          ; set intention "get-minerals" ;;what else could we set as intention?
          ; set intention "reach-goal"
          if-else first [minerals-level] of bases with [color = [color] of myself] > 20 [
            set intention "send-terminators"
          ] [
            set intention "get-minerals"
          ]
         ]
       ]
      [set intention 0]
      ; no desire ;; idea: what if agents desire to attack (in addition) and that means that they'll look for enemies base and communicate that to soldiers?

    ]
    ]
  ]


  ;list random max-pxcor random max-pycor)
end


; --- Execute actions ---
to execute-actions
    ask players [
    if intention != 0 [
      if-else intention = "grab-food"[
        let new-level (base-food-level - (not-hungry - hunger))
        ask bases-here with [color = [color] of myself] [
          set food-level new-level ;;or just food-level
        ]
        set hunger not-hungry
        ][
        if-else intention = "wait-food"[
          ;;agent will just stay and wait
          ][
          if-else intention = "goto-base"[
            if-else in-team-A? [
              facexy first [xcor] of bases with [color = red] first [ycor] of bases with [color = red]

              ][
              facexy first [xcor] of bases with [color = white] first [ycor] of bases with [color = white]
              ]
              fd 1
            ][
            if-else intention = "deposit-minerals"[
              ask bases-here [
                set minerals-level minerals-level + [minerals-storage] of myself
              ]
              set minerals-storage 0
              ][
              if-else intention = "deposit-food"[
                ask bases-here [
                  set food-level food-level + [food-storage] of myself
                ]
                set food-storage 0
              ][
                if-else intention = "get-food"[
                  let food-place first food-places
                  facexy first food-place last food-place
                  fd 1
                  ][
                  if-else intention = "get-minerals" [
                    let minerals-place first minerals-places
                    facexy first minerals-place last minerals-place
                    fd 1
                    ][
                    if-else intention = "explore" [
                      ; facexy round random-xcor round random-ycor
                      face explore-at
                      fd 1
                      ][
                      if-else intention = "pick-up metals"[
                        set minerals-storage max-minerals-capacity
                        ask patch-here [
                          set minerals (minerals - [minerals-storage] of myself)
                        ]

                        ][
                        if-else intention = "pick-up food"[
                          set food-storage max-food-capacity
                          ask patch-here [
                            set food (food - [food-storage] of myself)
                          ]
                        ][
                          if-else intention = "reach-goal"[
                            let enb first enemy-base
                            facexy first enb last enb
                            fd 1
                          ] [
                            if-else intention = "find-enemy-base"[
                               ; let probstraight 0.5
                               ; ifelse random-float 1 < probstraight [
                               ;   fd 1
                               ; ] [
                               ;   rt random 360
                               ;   lt random 360
                               ;   fd 1
                               ; ]

                               ;facexy round random-xcor round random-ycor
                               ;fd 1

                               face explore-at
                               fd 1
                            ] [
                              if intention = "send-terminators"[

                                if-else in-team-A? [

                                  let team-color red ;[color] of myself
                                  let destination enemy-base
                                  hatch-terminators 1 [
                                    set shape "airplane"
                                    setxy first [xcor] of bases with [color = team-color] first [ycor] of bases with [color = team-color]
                                    set dest first destination

                                    facexy first dest last dest

                                  ]
                                  ask bases with [color = team-color] [
                                    set minerals-level (minerals-level - 20)
                                  ]
                                ][

                                let team-color white ;[color] of myself
                                let destination enemy-base
                                hatch-terminators 1 [
                                  set shape "airplane"
                                  setxy first [xcor] of bases with [color = team-color] first [ycor] of bases with [color = team-color]
                                  set dest first destination

                                  facexy first dest last dest

                                ]
                                ask bases with [color = team-color] [
                                  set minerals-level (minerals-level - 20)
                                ]
                                ]
                            ;]
                          ]
                        ]
                        ]
                      ]
                    ]
                  ]
                ]
              ]
            ]
          ]
        ]
      ]


  ]]]

  ask terminators[
    if-else round xcor = first dest and round ycor = last dest [
      ask bases-here [
        set health (health - 20)
      ]
      die
    ] [ fd 1 ]
  ]

end


to send-messages
  ask players with [length outbox != 0] [
    ask other players with [color = [color] of myself] [
      set inbox sentence inbox outbox
      set inbox remove-duplicates inbox
    ]
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
597
10
1168
602
-1
-1
11.0
1
10
1
1
1
0
0
0
1
0
50
0
50
1
1
1
ticks
30.0

BUTTON
37
30
100
63
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
115
31
178
64
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
22
138
194
171
world-size
world-size
10
100
25
1
1
NIL
HORIZONTAL

SLIDER
22
170
194
203
patches-size
patches-size
5
20
10
1
1
NIL
HORIZONTAL

SLIDER
22
235
194
268
team_A_size
team_A_size
0
10
5
1
1
NIL
HORIZONTAL

SLIDER
22
268
194
301
team_B_size
team_B_size
0
10
5
1
1
NIL
HORIZONTAL

INPUTBOX
30
67
101
127
map-name
2
1
0
String

SLIDER
22
202
194
235
resource-growth-rate
resource-growth-rate
0
100
9
1
1
NIL
HORIZONTAL

SLIDER
14
347
186
380
food-decay
food-decay
1
6
4
1
1
NIL
HORIZONTAL

MONITOR
200
75
312
120
Desire player A
[desire] of player 2
17
1
11

MONITOR
202
284
307
329
Desire player B
[desire] of player (2 + team_A_size)
17
1
11

SLIDER
13
309
185
342
vision-radius
vision-radius
3
30
12
1
1
NIL
HORIZONTAL

SLIDER
16
387
188
420
storage-capacity
storage-capacity
3
100
50
1
1
NIL
HORIZONTAL

MONITOR
201
29
324
74
intention player A
[intention] of player 2
17
1
11

MONITOR
201
126
593
171
Food places player A
[food-places] of player 2
17
1
11

MONITOR
201
172
593
217
Minerals places player A
[minerals-places] of player 2
17
1
11

MONITOR
319
27
436
72
Position player A
[list round xcor round ycor] of player 2
17
1
11

MONITOR
318
76
431
121
Hunger player A
[hunger] of player 2
17
1
11

BUTTON
117
79
180
112
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
438
27
587
72
Food storage player A
[food-storage] of player 2
17
1
11

MONITOR
438
75
589
120
Minerals stor. player A
[minerals-storage] of player 2
17
1
11

MONITOR
202
237
322
282
Intention player B
[intention] of player (2 + team_A_size)
17
1
11

MONITOR
324
236
438
281
Position player B
[list round xcor round ycor] of player (2 + team_A_size)
17
1
11

MONITOR
440
236
587
281
Food storage player B
[food-storage] of player (2 + team_A_size)
17
1
11

MONITOR
323
283
434
328
Hunger player B
[hunger] of player (2 + team_A_size)
17
1
11

MONITOR
441
284
590
329
Minerals stor. player B
[minerals-storage] of player (2 + team_A_size)
17
1
11

MONITOR
202
334
593
379
Food places player B
[food-places] of player (2 + team_A_size)
17
1
11

MONITOR
201
383
592
428
Minerals places player B
[minerals-places] of player (2 + team_A_size)
17
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.3
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
