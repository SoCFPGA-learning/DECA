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
diagram = Diagram(1550, 800, "diagram")

# Add a stylesheet
diagram.add_stylesheet("styles.css", embed=True)

# Create a layout
content = diagram.add(
    Panel(
        width=1550,
        height=800,
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
    Image("./decaboard.png", width=652, height=1462, embed=True)
)

# Right hand side double-header
graphic.add(
    PinLabelGroup(
        x=626,
        y=85,
        body={"width": 110, "height": 20},
        pin_pitch=(0, 28),
        label_start=(260, 0),
        label_pitch=(0, 28),
        scale=(1, 1),
        labels=data.rhs_outer_numbered,
    )
)
graphic.add(
    PinLabelGroup(
        x=600,
        y=85,
        body={"width": 110, "height": 20},
        pin_pitch=(0, 28),
        label_start=(100, 15),
        label_pitch=(0, 28),
        scale=(1, 1),
        labels=data.rhs_inner_numbered,
        leaderline=lline.Curved(direction="vh"),
    )
)

# Left hand side double-header
graphic.add(
    PinLabelGroup(
        x=88,
        y=85,
        body={"width": 110, "height": 20},
        pin_pitch=(0, 28),
        label_start=(100, -15),
        label_pitch=(0, -28),
        scale=(-1, -1),
        labels=data.lhs_inner_numbered,
        leaderline=lline.Curved(direction="vh"),
    )
)
graphic.add(
    PinLabelGroup(
        x=62,
        y=85,
        body={"width": 110, "height": 20},
        pin_pitch=(0, 28),
        label_start=(240, 0),
        label_pitch=(0, 28),
        scale=(-1, 1),
        labels=data.lhs_outer_numbered,
    )
)

# build from cmd:
# >>> python3 -m pinout.manager --export pinout_deca pinout_deca.svg
