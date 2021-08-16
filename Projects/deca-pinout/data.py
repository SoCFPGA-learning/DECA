legend = [
    ("Pin number", "pinid"),
    ("GPIO", "gpio"),
    ("Analog", "analog"),
    ("Ground", "gnd"),
    ("Power", "pwr"),
    ("Pin location", "gpsingle"),
]

# Pinlabels
gnd = ("GND", "gnd")
pwr = ("3.3V", "pwr")

##############################
# LHS

lhs_outer = (
    [[pwr]]
    + [[gnd]]
    + [[(f"GP{i}", "gpsingle")] for i in range(0, 19)]
    + [[gnd]]
    + [[pwr]]
)
lhs_outer_numbered = [
    [
        (
            f"{i * 2 + 1 }",
            "pinid",
            {"body": {"width": 30, "height": 20}},
        )
    ]
    + row
    for i, row in enumerate(lhs_outer)
]


lhs_inner = (
    [[pwr]]
    + [[gnd]]
    + [[(f"GN{i}", "gnsingle")] for i in range(0, 19)]
    + [[gnd]]
    + [[pwr]]
)
lhs_inner_numbered = [
    [
        (
            f"{i * 2 + 2 }",
            "pinid",
            {"body": {"width": 30, "height": 20}},
        )
    ]
    + row
    for i, row in enumerate(lhs_inner)
]


##############################
# RHS


rhs_outer_numbered = [
    [
        ("2", "pinid",{"body": {"width": 30, "height": 20}}),
        ("GND", "gnd",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("4", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D1", "gpio",{"body": {"width": 40, "height": 20}}),
        ("Y18", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("6", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D3", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AA17", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("8", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D5", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AA19", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("10", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D7", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB20", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("12", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D9", "gpio",{"body": {"width": 40, "height": 20}}),
        ("Y16", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("14", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D11", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB18", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("16", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D13", "gpio",{"body": {"width": 40, "height": 20}}),
        ("W17", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("18", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D15", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AA16", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("20", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D17", "gpio",{"body": {"width": 40, "height": 20}}),
        ("W16", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("22", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D19", "gpio",{"body": {"width": 40, "height": 20}}),
        ("W15", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("24", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D21", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AA15", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("26", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D23", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AA14", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("28", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D25", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AA13", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("30", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D27", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AA12", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("32", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D29", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AA11", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("34", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D31", "gpio",{"body": {"width": 40, "height": 20}}),
        ("Y13", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("36", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D33", "gpio",{"body": {"width": 40, "height": 20}}),
        ("W13", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("38", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D35", "gpio",{"body": {"width": 40, "height": 20}}),
        ("W11", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("40", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D37", "gpio",{"body": {"width": 40, "height": 20}}),
        ("V11", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("42", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D39", "gpio",{"body": {"width": 40, "height": 20}}),
        ("V14", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("44", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D41", "gpio",{"body": {"width": 40, "height": 20}}),
        ("W14", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("46", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D43", "gpio",{"body": {"width": 40, "height": 20}}),
        ("R13", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],

]



rhs_inner_numbered = [
    [
        ("1", "pinid",{"body": {"width": 30, "height": 20}}),
        ("GND", "gnd",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("3", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D0", "gpio",{"body": {"width": 40, "height": 20}}),
        ("W18", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("5", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D2", "gpio",{"body": {"width": 40, "height": 20}}),
        ("Y19", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("7", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D4", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AA20", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("9", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D6", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB21", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("11", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D8", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB19", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("13", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D10", "gpio",{"body": {"width": 40, "height": 20}}),
        ("V16", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("15", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D12", "gpio",{"body": {"width": 40, "height": 20}}),
        ("V15", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("17", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D14", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB17", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("19", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D16", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB16", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("21", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D18", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB15", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("23", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D20", "gpio",{"body": {"width": 40, "height": 20}}),
        ("Y14", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("25", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D22", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB14", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("27", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D24", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB13", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("29", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D26", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB12", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("31", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D28", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB11", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("33", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D30", "gpio",{"body": {"width": 40, "height": 20}}),
        ("AB10", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("35", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D32", "gpio",{"body": {"width": 40, "height": 20}}),
        ("Y11", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("37", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D34", "gpio",{"body": {"width": 40, "height": 20}}),
        ("W12", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("39", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D36", "gpio",{"body": {"width": 40, "height": 20}}),
        ("V12", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("41", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D38", "gpio",{"body": {"width": 40, "height": 20}}),
        ("V13", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("43", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D40", "gpio",{"body": {"width": 40, "height": 20}}),
        ("Y17", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],
    [
        ("45", "pinid",{"body": {"width": 30, "height": 20}}),
        ("0D42", "gpio",{"body": {"width": 40, "height": 20}}),
        ("U15", "gpsingle",{"body": {"width": 40, "height": 20}}),
    ],

]

# Text

title = "<tspan class='h1'>DECA Pinout</tspan>"

description = """Created with Python tool kit to assist with 
documentation of electronic hardware. 
More info at <tspan class='italic strong'>pinout.readthedocs.io</tspan>"""

P8 = "<tspan class='h1'>P8 conn.</tspan>"

P9 = "<tspan class='h1'>P9 conn.</tspan>"
