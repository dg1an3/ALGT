# Clarion Language - Railroad Diagrams

Generated from `clarion_parser.pl` DCG rules.

## control_decl

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n11["qchars"]
    n13(["'"])
    n16([")"])
    n19["control_attrs"]
    n21[/"ENTRY"/]
    n24(["("])
    n27["format_picture"]
    n30([")"])
    n32["control_attrs_with_use"]
    n34[/"BUTTON"/]
    n37(["("])
    n3[/"PROMPT"/]
    n40(["'"])
    n42["qchars"]
    n44(["'"])
    n47([")"])
    n50["control_attrs_with_use"]
    n52[/"STRING"/]
    n55(["("])
    n58["format_picture"]
    n6(["("])
    n61([")"])
    n63["control_attrs_with_use"]
    n65[/"STRING"/]
    n68(["("])
    n71(["'"])
    n73["qchars"]
    n75(["'"])
    n78([")"])
    n81["control_attrs_with_use"]
    n83[/"LIST"/]
    n86["control_attrs_with_use"]
    n9(["'"])
    n0 --> n21 --> n20
    n0 --> n3 --> n2
    n0 --> n34 --> n33
    n0 --> n52 --> n51
    n0 --> n65 --> n64
    n0 --> n83 --> n82
    n10 --> n13 --> n12
    n12 --> n14
    n14 --> n16 --> n15
    n15 --> n17
    n17 --> n19 --> n18
    n18 --> n1
    n2 --> n4
    n20 --> n22
    n22 --> n24 --> n23
    n23 --> n25
    n25 --> n27 --> n26
    n26 --> n28
    n28 --> n30 --> n29
    n29 --> n31
    n31 --> n32 --> n1
    n33 --> n35
    n35 --> n37 --> n36
    n36 --> n38
    n38 --> n40 --> n39
    n39 --> n42 --> n41
    n4 --> n6 --> n5
    n41 --> n44 --> n43
    n43 --> n45
    n45 --> n47 --> n46
    n46 --> n48
    n48 --> n50 --> n49
    n49 --> n1
    n5 --> n7
    n51 --> n53
    n53 --> n55 --> n54
    n54 --> n56
    n56 --> n58 --> n57
    n57 --> n59
    n59 --> n61 --> n60
    n60 --> n62
    n62 --> n63 --> n1
    n64 --> n66
    n66 --> n68 --> n67
    n67 --> n69
    n69 --> n71 --> n70
    n7 --> n9 --> n8
    n70 --> n73 --> n72
    n72 --> n75 --> n74
    n74 --> n76
    n76 --> n78 --> n77
    n77 --> n79
    n79 --> n81 --> n80
    n8 --> n11 --> n10
    n80 --> n1
    n82 --> n84
    n84 --> n86 --> n85
    n85 --> n1
```

## expr

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n2["or_expr"]
    n0 --> n2 --> n1
```

## field_decl

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n3["word"]
    n5["type"]
    n0 --> n3 --> n2
    n2 --> n4
    n4 --> n5 --> n1
```

## map_block

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n3[/"MAP"/]
    n6["map_entries"]
    n8[/"END"/]
    n0 --> n3 --> n2
    n2 --> n4
    n4 --> n6 --> n5
    n5 --> n7
    n7 --> n8 --> n1
```

## map_entry_or_module

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n11["qchars"]
    n13(["'"])
    n16([")"])
    n19["map_entries"]
    n22[/"END"/]
    n24["ident"]
    n27(["("])
    n30["map_param_list"]
    n33([")"])
    n35["map_return_and_attrs"]
    n37["ident"]
    n3[/"MODULE"/]
    n40[/"PROCEDURE"/]
    n43["map_proc_params"]
    n45["map_return_and_attrs"]
    n6(["("])
    n9(["'"])
    n0 --> n24 --> n23
    n0 --> n3 --> n2
    n0 --> n37 --> n36
    n10 --> n13 --> n12
    n12 --> n14
    n14 --> n16 --> n15
    n15 --> n17
    n17 --> n19 --> n18
    n18 --> n20
    n2 --> n4
    n20 --> n22 --> n21
    n21 --> n1
    n23 --> n25
    n25 --> n27 --> n26
    n26 --> n28
    n28 --> n30 --> n29
    n29 --> n31
    n31 --> n33 --> n32
    n32 --> n34
    n34 --> n35 --> n1
    n36 --> n38
    n38 --> n40 --> n39
    n39 --> n41
    n4 --> n6 --> n5
    n41 --> n43 --> n42
    n42 --> n44
    n44 --> n45 --> n1
    n5 --> n7
    n7 --> n9 --> n8
    n8 --> n11 --> n10
```

## procedure

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n12["return_type"]
    n15["local_vars"]
    n18[/"CODE"/]
    n20["statements"]
    n3["ident"]
    n6[/"PROCEDURE"/]
    n9["proc_def_params"]
    n0 --> n3 --> n2
    n10 --> n12 --> n11
    n11 --> n13
    n13 --> n15 --> n14
    n14 --> n16
    n16 --> n18 --> n17
    n17 --> n19
    n19 --> n20 --> n1
    n2 --> n4
    n4 --> n6 --> n5
    n5 --> n7
    n7 --> n9 --> n8
    n8 --> n10
```

## program

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n10([")"])
    n13["top_decls"]
    n16["map_block"]
    n19["procedures"]
    n22[/"PROGRAM"/]
    n25["map_block"]
    n28["top_decls"]
    n31[/"CODE"/]
    n34["statements"]
    n37["procedures"]
    n4[/"MEMBER"/]
    n7(["("])
    n0 --> n2
    n0 --> n20
    n11 --> n13 --> n12
    n12 --> n14
    n14 --> n16 --> n15
    n15 --> n17
    n17 --> n19 --> n18
    n18 --> n1
    n2 --> n4 --> n3
    n20 --> n22 --> n21
    n21 --> n23
    n23 --> n25 --> n24
    n24 --> n26
    n26 --> n28 --> n27
    n27 --> n29
    n29 --> n31 --> n30
    n3 --> n5
    n30 --> n32
    n32 --> n34 --> n33
    n33 --> n35
    n35 --> n37 --> n36
    n36 --> n1
    n5 --> n7 --> n6
    n6 --> n8
    n8 --> n10 --> n9
    n9 --> n11
```

## routine

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n3["ident"]
    n6[/"ROUTINE"/]
    n8["statements"]
    n0 --> n3 --> n2
    n2 --> n4
    n4 --> n6 --> n5
    n5 --> n7
    n7 --> n8 --> n1
```

## statement

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n100["statements"]
    n102[/"END"/]
    n103[/"DISPLAY"/]
    n104[/"BREAK"/]
    n105[/"CYCLE"/]
    n106[/"EXIT"/]
    n108[/"DO"/]
    n110["ident"]
    n112[/"RETURN"/]
    n114["expr"]
    n115[/"RETURN"/]
    n117[/"SELF"/]
    n120(["."])
    n123["word"]
    n126(["="])
    n128["expr"]
    n12["statement"]
    n130[/"PARENT"/]
    n133(["."])
    n136["word"]
    n139(["("])
    n14(["."])
    n142["expr_list"]
    n144([")"])
    n146["word"]
    n149(["."])
    n152["word"]
    n155(["("])
    n158["expr_list"]
    n161([")"])
    n163["ident"]
    n166(["["])
    n169["expr"]
    n16[/"IF"/]
    n172(["]"])
    n175(["="])
    n177["expr"]
    n179["ident"]
    n182(["="])
    n184["expr"]
    n186["ident"]
    n189(["+="])
    n191["expr"]
    n193[/"DELETE"/]
    n196(["("])
    n199["ident"]
    n19["expr"]
    n201([")"])
    n203["word"]
    n206(["("])
    n209["expr_list"]
    n211([")"])
    n22["statements"]
    n25["elsif_else"]
    n27[/"END"/]
    n29[/"LOOP"/]
    n32["ident"]
    n35(["="])
    n38["expr"]
    n3[/"IF"/]
    n41[/"TO"/]
    n44["expr"]
    n47["statements"]
    n49[/"END"/]
    n51[/"LOOP"/]
    n54[/"WHILE"/]
    n57["expr"]
    n60["statements"]
    n62[/"END"/]
    n64[/"LOOP"/]
    n67[/"UNTIL"/]
    n6["expr"]
    n70["expr"]
    n73["statements"]
    n75[/"END"/]
    n77[/"LOOP"/]
    n80["statements"]
    n82[/"END"/]
    n84[/"CASE"/]
    n87["expr"]
    n90["of_blocks"]
    n93["case_else"]
    n95[/"END"/]
    n97[/"ACCEPT"/]
    n9[/"THEN"/]
    n0 --> n103 --> n1
    n0 --> n104 --> n1
    n0 --> n105 --> n1
    n0 --> n106 --> n1
    n0 --> n108 --> n107
    n0 --> n112 --> n111
    n0 --> n115 --> n1
    n0 --> n117 --> n116
    n0 --> n130 --> n129
    n0 --> n146 --> n145
    n0 --> n16 --> n15
    n0 --> n163 --> n162
    n0 --> n179 --> n178
    n0 --> n186 --> n185
    n0 --> n193 --> n192
    n0 --> n203 --> n202
    n0 --> n29 --> n28
    n0 --> n3 --> n2
    n0 --> n51 --> n50
    n0 --> n64 --> n63
    n0 --> n77 --> n76
    n0 --> n84 --> n83
    n0 --> n97 --> n96
    n10 --> n12 --> n11
    n101 --> n102 --> n1
    n107 --> n109
    n109 --> n110 --> n1
    n11 --> n13
    n111 --> n113
    n113 --> n114 --> n1
    n116 --> n118
    n118 --> n120 --> n119
    n119 --> n121
    n121 --> n123 --> n122
    n122 --> n124
    n124 --> n126 --> n125
    n125 --> n127
    n127 --> n128 --> n1
    n129 --> n131
    n13 --> n14 --> n1
    n131 --> n133 --> n132
    n132 --> n134
    n134 --> n136 --> n135
    n135 --> n137
    n137 --> n139 --> n138
    n138 --> n140
    n140 --> n142 --> n141
    n141 --> n143
    n143 --> n144 --> n1
    n145 --> n147
    n147 --> n149 --> n148
    n148 --> n150
    n15 --> n17
    n150 --> n152 --> n151
    n151 --> n153
    n153 --> n155 --> n154
    n154 --> n156
    n156 --> n158 --> n157
    n157 --> n159
    n159 --> n161 --> n160
    n160 --> n1
    n162 --> n164
    n164 --> n166 --> n165
    n165 --> n167
    n167 --> n169 --> n168
    n168 --> n170
    n17 --> n19 --> n18
    n170 --> n172 --> n171
    n171 --> n173
    n173 --> n175 --> n174
    n174 --> n176
    n176 --> n177 --> n1
    n178 --> n180
    n18 --> n20
    n180 --> n182 --> n181
    n181 --> n183
    n183 --> n184 --> n1
    n185 --> n187
    n187 --> n189 --> n188
    n188 --> n190
    n190 --> n191 --> n1
    n192 --> n194
    n194 --> n196 --> n195
    n195 --> n197
    n197 --> n199 --> n198
    n198 --> n200
    n2 --> n4
    n20 --> n22 --> n21
    n200 --> n201 --> n1
    n202 --> n204
    n204 --> n206 --> n205
    n205 --> n207
    n207 --> n209 --> n208
    n208 --> n210
    n21 --> n23
    n210 --> n211 --> n1
    n23 --> n25 --> n24
    n24 --> n26
    n26 --> n27 --> n1
    n28 --> n30
    n30 --> n32 --> n31
    n31 --> n33
    n33 --> n35 --> n34
    n34 --> n36
    n36 --> n38 --> n37
    n37 --> n39
    n39 --> n41 --> n40
    n4 --> n6 --> n5
    n40 --> n42
    n42 --> n44 --> n43
    n43 --> n45
    n45 --> n47 --> n46
    n46 --> n48
    n48 --> n49 --> n1
    n5 --> n7
    n50 --> n52
    n52 --> n54 --> n53
    n53 --> n55
    n55 --> n57 --> n56
    n56 --> n58
    n58 --> n60 --> n59
    n59 --> n61
    n61 --> n62 --> n1
    n63 --> n65
    n65 --> n67 --> n66
    n66 --> n68
    n68 --> n70 --> n69
    n69 --> n71
    n7 --> n9 --> n8
    n71 --> n73 --> n72
    n72 --> n74
    n74 --> n75 --> n1
    n76 --> n78
    n78 --> n80 --> n79
    n79 --> n81
    n8 --> n10
    n81 --> n82 --> n1
    n83 --> n85
    n85 --> n87 --> n86
    n86 --> n88
    n88 --> n90 --> n89
    n89 --> n91
    n91 --> n93 --> n92
    n92 --> n94
    n94 --> n95 --> n1
    n96 --> n98
    n98 --> n100 --> n99
    n99 --> n101
```

## top_decl_item

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n100[/"DIM"/]
    n103(["("])
    n106["number"]
    n108([")"])
    n10["file_attrs"]
    n110["ident"]
    n113["type"]
    n116(["("])
    n119["number"]
    n121([")"])
    n13["key_decls"]
    n16["record_block"]
    n19[/"END"/]
    n21["ident"]
    n24[/"GROUP"/]
    n28["group_attrs"]
    n31["field_list"]
    n33[/"END"/]
    n35["ident"]
    n38[/"QUEUE"/]
    n3["ident"]
    n42["field_list"]
    n44[/"END"/]
    n46["word"]
    n49[/"CLASS"/]
    n53["class_parent"]
    n56["class_attrs"]
    n59["class_members"]
    n61[/"END"/]
    n63["ident"]
    n66[/"WINDOW"/]
    n6[/"FILE"/]
    n70(["("])
    n73(["'"])
    n75["qchars"]
    n77(["'"])
    n80([")"])
    n83["window_attrs"]
    n86["control_list"]
    n89[/"END"/]
    n91["ident"]
    n94["type"]
    n97([","])
    n0 --> n110 --> n109
    n0 --> n21 --> n20
    n0 --> n3 --> n2
    n0 --> n35 --> n34
    n0 --> n46 --> n45
    n0 --> n63 --> n62
    n0 --> n91 --> n90
    n101 --> n103 --> n102
    n102 --> n104
    n104 --> n106 --> n105
    n105 --> n107
    n107 --> n108 --> n1
    n109 --> n111
    n11 --> n13 --> n12
    n111 --> n113 --> n112
    n112 --> n114
    n114 --> n1
    n114 --> n116 --> n115
    n115 --> n117
    n117 --> n119 --> n118
    n118 --> n120
    n12 --> n14
    n120 --> n121 --> n1
    n14 --> n16 --> n15
    n15 --> n17
    n17 --> n19 --> n18
    n18 --> n1
    n2 --> n4
    n20 --> n22
    n22 --> n24 --> n23
    n23 --> n25
    n25 --> n26
    n26 --> n28 --> n27
    n27 --> n29
    n29 --> n31 --> n30
    n30 --> n32
    n32 --> n33 --> n1
    n34 --> n36
    n36 --> n38 --> n37
    n37 --> n39
    n39 --> n40
    n4 --> n6 --> n5
    n40 --> n42 --> n41
    n41 --> n43
    n43 --> n44 --> n1
    n45 --> n47
    n47 --> n49 --> n48
    n48 --> n50
    n5 --> n7
    n50 --> n51
    n51 --> n53 --> n52
    n52 --> n54
    n54 --> n56 --> n55
    n55 --> n57
    n57 --> n59 --> n58
    n58 --> n60
    n60 --> n61 --> n1
    n62 --> n64
    n64 --> n66 --> n65
    n65 --> n67
    n67 --> n68
    n68 --> n70 --> n69
    n69 --> n71
    n7 --> n8
    n71 --> n73 --> n72
    n72 --> n75 --> n74
    n74 --> n77 --> n76
    n76 --> n78
    n78 --> n80 --> n79
    n79 --> n81
    n8 --> n10 --> n9
    n81 --> n83 --> n82
    n82 --> n84
    n84 --> n86 --> n85
    n85 --> n87
    n87 --> n89 --> n88
    n88 --> n1
    n9 --> n11
    n90 --> n92
    n92 --> n94 --> n93
    n93 --> n95
    n95 --> n97 --> n96
    n96 --> n98
    n98 --> n100 --> n99
    n99 --> n101
```

## type

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n10[/"DECIMAL"/]
    n13(["("])
    n16["number"]
    n19([","])
    n22["number"]
    n24([")"])
    n26[/"DECIMAL"/]
    n29(["("])
    n2[/"LONG"/]
    n32["number"]
    n34([")"])
    n35[/"DECIMAL"/]
    n37[/"PDECIMAL"/]
    n3[/"SHORT"/]
    n40(["("])
    n43["number"]
    n46([","])
    n49["number"]
    n4[/"BYTE"/]
    n51([")"])
    n53[/"PDECIMAL"/]
    n56(["("])
    n59["number"]
    n5[/"REAL"/]
    n61([")"])
    n62[/"PDECIMAL"/]
    n64[/"CSTRING"/]
    n67(["("])
    n6[/"SREAL"/]
    n70["number"]
    n72([")"])
    n73[/"CSTRING"/]
    n75[/"PSTRING"/]
    n78(["("])
    n7[/"DATE"/]
    n81["number"]
    n83([")"])
    n84[/"PSTRING"/]
    n86[/"STRING"/]
    n89(["("])
    n8[/"TIME"/]
    n92["number"]
    n94([")"])
    n95[/"STRING"/]
    n0 --> n10 --> n9
    n0 --> n2 --> n1
    n0 --> n26 --> n25
    n0 --> n3 --> n1
    n0 --> n35 --> n1
    n0 --> n37 --> n36
    n0 --> n4 --> n1
    n0 --> n5 --> n1
    n0 --> n53 --> n52
    n0 --> n6 --> n1
    n0 --> n62 --> n1
    n0 --> n64 --> n63
    n0 --> n7 --> n1
    n0 --> n73 --> n1
    n0 --> n75 --> n74
    n0 --> n8 --> n1
    n0 --> n84 --> n1
    n0 --> n86 --> n85
    n0 --> n95 --> n1
    n11 --> n13 --> n12
    n12 --> n14
    n14 --> n16 --> n15
    n15 --> n17
    n17 --> n19 --> n18
    n18 --> n20
    n20 --> n22 --> n21
    n21 --> n23
    n23 --> n24 --> n1
    n25 --> n27
    n27 --> n29 --> n28
    n28 --> n30
    n30 --> n32 --> n31
    n31 --> n33
    n33 --> n34 --> n1
    n36 --> n38
    n38 --> n40 --> n39
    n39 --> n41
    n41 --> n43 --> n42
    n42 --> n44
    n44 --> n46 --> n45
    n45 --> n47
    n47 --> n49 --> n48
    n48 --> n50
    n50 --> n51 --> n1
    n52 --> n54
    n54 --> n56 --> n55
    n55 --> n57
    n57 --> n59 --> n58
    n58 --> n60
    n60 --> n61 --> n1
    n63 --> n65
    n65 --> n67 --> n66
    n66 --> n68
    n68 --> n70 --> n69
    n69 --> n71
    n71 --> n72 --> n1
    n74 --> n76
    n76 --> n78 --> n77
    n77 --> n79
    n79 --> n81 --> n80
    n80 --> n82
    n82 --> n83 --> n1
    n85 --> n87
    n87 --> n89 --> n88
    n88 --> n90
    n9 --> n11
    n90 --> n92 --> n91
    n91 --> n93
    n93 --> n94 --> n1
```

## window_attr

```mermaid
flowchart LR
    n0(((" ")))
    n1(((" ")))
    n12([","])
    n15["opt_number"]
    n18([","])
    n21["number"]
    n24([","])
    n27["number"]
    n29([")"])
    n30[/"CENTER"/]
    n3[/"AT"/]
    n6(["("])
    n9["opt_number"]
    n0 --> n3 --> n2
    n0 --> n30 --> n1
    n10 --> n12 --> n11
    n11 --> n13
    n13 --> n15 --> n14
    n14 --> n16
    n16 --> n18 --> n17
    n17 --> n19
    n19 --> n21 --> n20
    n2 --> n4
    n20 --> n22
    n22 --> n24 --> n23
    n23 --> n25
    n25 --> n27 --> n26
    n26 --> n28
    n28 --> n29 --> n1
    n4 --> n6 --> n5
    n5 --> n7
    n7 --> n9 --> n8
    n8 --> n10
```

