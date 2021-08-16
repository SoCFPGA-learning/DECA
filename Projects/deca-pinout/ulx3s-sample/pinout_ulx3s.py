###########################################
#
# ULX3S based on example script to build a
# pinout diagram. Includes basic
# features and convenience classes.
#
###########################################

from pinout.core import Group, Image
from pinout.components.layout import Diagram, Panel
from pinout.components.pinlabel import PinLabelGroup, PinLabel
from pinout.components.text import TextBlock
from pinout.components import leaderline as lline
from pinout.components.legend import Legend


# Import data for the diagram
import data

# Create a new diagram
diagram = Diagram(1600, 750, "diagram")

# Add a stylesheet
diagram.add_stylesheet("styles.css", embed=True)

# Create a layout
content = diagram.add(
    Panel(
        width=1600,
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
graphic = panel_main.add(Group(200, 20))

# Add and embed an image
graphic.add(Image("./ulx3s_illust_01.png", width=1200, height=700, embed=True))



graphic.add(
    PinLabelGroup(
        x=59,
        y=32,
        body= {"width":110, "height":20},
        pin_pitch=(0, 30),
        label_start=(30, 0),
        label_pitch=(0, 30),
        scale=(-1, 1),
        labels=data.lhs_pairs_numbered,
    )
)

graphic.add(
    PinLabelGroup(
        x=1141,
        y=603,
        body= {"width":110, "height":20},
        pin_pitch=(0, -30),
        label_start=(30, 0),
        label_pitch=(0, -30),
        scale=(1, 1),
        labels=data.rhs_outer_numbered,
    )
)
graphic.add(
    PinLabelGroup(
        x=1111.5,
        y=603,
        body= {"width":110, "height":20},
        pin_pitch=(0, -30),
        label_start=(30, 0),
        label_pitch=(0, -30),
        scale=(-1, 1),
        labels=data.rhs_inner_numbered,
    )
)

graphic.add(
    PinLabelGroup(
        x=470,
        y=137.5,
        body= {"width":110, "height":20},
        pin_pitch=(30, 0),
        label_start=(50, 30),
        label_pitch=(0, 30),
        scale=(-1, -1),
        labels=[[(" ","comms")]]*3,
        leaderline=lline.Curved(direction="vh"),
    )
)

graphic.add(
    PinLabelGroup(
        x=494.5,
        y=482.5,
        body= {"width":110, "height":20},
        pin_pitch=(30, 0),
        label_start=(74.5, 30),
        label_pitch=(0, 30),
        scale=(-1, -1),
        labels=[[(" ","comms")]]*7,
        leaderline=lline.Curved(direction="vh"),
    )
)

graphic.add(
    PinLabelGroup(
        x=561,
        y=528,
        body= {"width":110, "height":20},
        pin_pitch=(0, 30),
        label_start=(30, 0),
        label_pitch=(0, 30),
        scale=(-1, 1),
        labels=[[(" ","comms")]]*3,
    )
)
graphic.add(
    PinLabelGroup(
        x=591,
        y=528,
        body= {"width":110, "height":20},
        pin_pitch=(0, 30),
        label_start=(30, 0),
        label_pitch=(0, 30),
        scale=(1, 1),
        labels=[[(" ","comms")]]*3,
    )
)