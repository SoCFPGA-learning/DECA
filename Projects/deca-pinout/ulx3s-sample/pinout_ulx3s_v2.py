###########################################
#
# ULX3S based on example script to build a
# pinout diagram. Includes basic
# features and convenience classes.
#
###########################################

from pinout.core import Group, Image, Rect
from pinout.components.layout import Diagram, Panel, ClipPath
from pinout.components.pinlabel import PinLabelGroup, PinLabel
from pinout.components.text import TextBlock
from pinout.components import leaderline as lline
from pinout.components.legend import Legend


# Import data for the diagram
import data

# Create a new diagram
diagram = Diagram(1400, 750, "diagram")

# Add a stylesheet
diagram.add_stylesheet("styles.css", embed=True)

# Create a layout
content = diagram.add(
    Panel(
        width=1400,
        height=750,
        inset=(2, 2, 2, 2),
    )
)
panel_main = content.add(
    Panel(
        width=content.inset_width,
        height=content.inset_height,
        inset=(2, 2, 2, 2),
        tag="panel--main",
    )
)


# Create a group to hold the pinout-diagram components.
graphic = panel_main.add(Group(420, 20))

# Add and embed an image
hardware_img = graphic.add(
    Image("./ulx3s_illust_02.png", width=560, height=690, embed=True)
)

# Right hand side double-header
graphic.add(
    PinLabelGroup(
        x=537,
        y=598,
        body={"width": 110, "height": 20},
        pin_pitch=(0, -30),
        label_start=(60, 0),
        label_pitch=(0, -30),
        scale=(1, 1),
        labels=data.rhs_outer_numbered,
    )
)
graphic.add(
    PinLabelGroup(
        x=507,
        y=598,
        body={"width": 110, "height": 20},
        pin_pitch=(0, -30),
        label_start=(260, 15),
        label_pitch=(0, -30),
        scale=(1, 1),
        labels=data.rhs_inner_numbered,
        leaderline=lline.Curved(direction="vh"),
    )
)

# Left hand side double-header
graphic.add(
    PinLabelGroup(
        x=53,
        y=27,
        body={"width": 110, "height": 20},
        pin_pitch=(0, 30),
        label_start=(100, 15),
        label_pitch=(0, -30),
        scale=(-1, -1),
        labels=data.lhs_inner_numbered,
        leaderline=lline.Curved(direction="vh"),
    )
)
graphic.add(
    PinLabelGroup(
        x=23,
        y=27,
        body={"width": 110, "height": 20},
        pin_pitch=(0, 30),
        label_start=(240, 0),
        label_pitch=(0, 30),
        scale=(-1, 1),
        labels=data.lhs_outer_numbered,
    )
)

# build from cmd:
# >>> py -m pinout.manager -e pinout_ulx3s_v2 pinout_ulx3s_v2.svg -o
