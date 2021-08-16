legend = [
    ("Pin number", "pinid"),
    ("GP single-ended", "gpsingle"),
    ("GN single-ended", "gnsingle"),
    ("FPGA site", "site"),
    ("Analog", "analog"),
    ("Communication", "comms"),
    ("Ground", "gnd"),
    ("GPIO", "gpio"),
    ("Touch", "touch"),
    ("Power", "pwr"),
    ("PWM", "pwm"),
]

# Pinlabels
gnd = ("GND", "gnd")
pwr = ("+2.5/3.3V", "pwr")

##############################
# LHS
lhs_pairs = (
    [[pwr]]
    + [[gnd]]
    + [[(f"GP{i} | GN{i}", "gpio")] for i in range(0, 7)]
    + [[pwr]]
    + [[gnd]]
    + [[(f"GP{i} | GN{i}", "gpio")] for i in range(7, 14)]
    + [[gnd]]
    + [[pwr]]
)

lhs_pairs_numbered = [
    [(f"{i * 2 + 2} | {i * 2 + 1}", "pinid", {"body": {"width": 55, "height": 20}})]
    + data
    for i, data in enumerate(lhs_pairs)
]
# lhs_pairs_numbered = [[(f"({i+j}) " + label[0],  label[1])] for i, row in enumerate(lhs_pairs) for j, label in enumerate(row) ]

lhs_outer = (
    [[pwr]]
    + [[gnd]]
    + [[(f"GP{i}", "gpsingle")] for i in range(0, 7)]
    + [[pwr]]
    + [[gnd]]
    + [[(f"GP{i}", "gpsingle")] for i in range(7, 14)]
    + [[gnd]]
    + [[pwr]]
)
lhs_outer_numbered = [
    [
        (
            f"{i * 2 + 2 }",
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
    + [[(f"GN{i}", "gnsingle")] for i in range(0, 7)]
    + [[pwr]]
    + [[gnd]]
    + [[(f"GN{i}", "gnsingle")] for i in range(7, 14)]
    + [[gnd]]
    + [[pwr]]
)
lhs_inner_numbered = [
    [
        (
            f"{i * 2 + 1 }",
            "pinid",
            {"body": {"width": 30, "height": 20}},
        )
    ]
    + row
    for i, row in enumerate(lhs_inner)
]


##############################
# RHS

rhs_pairs = (
    [[pwr]]
    + [[gnd]]
    + [[(f"GN{i} | GP{i}", "gpio")] for i in range(14, 21)]
    + [[pwr]]
    + [[gnd]]
    + [[(f"GN{i} | GP{i}", "gpio")] for i in range(21, 28)]
    + [[gnd]]
    + [[pwr]]
)
rhs_pairs_numbered = [
    [
        (
            f"{i * 2 + 1 + len(lhs_pairs_numbered)*2} | {i * 2 + 2 + len(lhs_pairs_numbered)*2}",
            "pinid",
            {"body": {"width": 55, "height": 20}},
        )
    ]
    + data
    for i, data in enumerate(rhs_pairs)
]

rhs_outer = (
    [[pwr]]
    + [[gnd]]
    + [[(f"GP{i}", "gpsingle")] for i in range(14, 21)]
    + [[pwr]]
    + [[gnd]]
    + [[(f"GP{i}", "gpsingle")] for i in range(21, 28)]
    + [[gnd]]
    + [[pwr]]
)
rhs_outer_numbered = [
    [
        (
            f"{i * 2 + 2 + len(lhs_pairs_numbered)*2}",
            "pinid",
            {"body": {"width": 30, "height": 20}},
        )
    ]
    + row
    for i, row in enumerate(rhs_outer)
]

rhs_inner = (
    [[pwr]]
    + [[gnd]]
    + [[(f"GN{i}", "gnsingle")] for i in range(14, 21)]
    + [[pwr]]
    + [[gnd]]
    + [[(f"GN{i}", "gnsingle")] for i in range(21, 28)]
    + [[gnd]]
    + [[pwr]]
)
rhs_inner_numbered = [
    [
        (
            f"{i * 2 + 1 + len(lhs_pairs_numbered)*2}",
            "pinid",
            {"body": {"width": 30, "height": 20}},
        )
    ]
    + row
    for i, row in enumerate(rhs_inner)
]


# Text

title = "<tspan class='h1'>ULX3S Pinout</tspan>"

description = """Created with Python tool kit to assist with 
documentation of electronic hardware. 
More info at <tspan class='italic strong'>pinout.readthedocs.io</tspan>"""
