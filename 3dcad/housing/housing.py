import cadquery as cq
try:
    from xvis import show, style
except ImportError:
    from cadquery.vis import show, style

from cadquery.occ_impl.shapes import edgesToWires
from os.path import abspath, dirname

from kiutils.board import Board, GrArc, GrLine


OUTPUT_DIR = f'{dirname(abspath(__file__))}'

TOL = 0.1
PCB_TOL = 0.3
PCB_TH = 1.6
TH = 1.8

BOTTOM_H = 4.0
MIDDLE_H = 7.0
TOP_H = 3.0
HOUSING_H = BOTTOM_H + MIDDLE_H + TOP_H
MIDDLE_OFFSET = BOTTOM_H + MIDDLE_H

DISP_FILTER_SX = 19.0
DISP_FILTER_SY = 12.0
DISP_FILTER_TH = 0.2
DISP_FILTER_H_OFFSET = 1.0

BUTTON_D = 5.0
BUTTONS_OFFSET = 0.5

if __name__ == '__main__':

    edges = []
    board = Board.from_file('./kicad/power_supply/power_supply.kicad_pcb')
    for item in board.graphicItems:
        if item.layer == 'Edge.Cuts':
            if isinstance(item, GrArc):
                edges.append(
                    cq.Edge.makeThreePointArc(
                        (item.start.X, item.start.Y),
                        (item.mid.X, item.mid.Y),
                        (item.end.X, item.end.Y)))
            elif isinstance(item, GrLine):
                edges.append(
                    cq.Edge.makeLine(
                        (item.start.X, item.start.Y),
                        (item.end.X, item.end.Y)))

    wire = edgesToWires(edges, tol=0.01)[0]
    pcb_outline = \
        (cq.Workplane('XY')
            .add(wire))

    bb = pcb_outline.val().BoundingBox()
    pcb_outline = \
        (pcb_outline
            .translate((-bb.xmin - (bb.xmax - bb.xmin) / 2,
                       -bb.ymin - (bb.ymax - bb.ymin) / 2, 0.0))
            .rotate((0, 0, 0), (0, 0, 1), 180.0))

    # Power supply PCB reference model
    def load_power_supply_pcb():
        pcb = cq.importers.importStep(OUTPUT_DIR + '/refs/power_supply.step')
        bb = pcb.val().BoundingBox()
        pcb = \
            (pcb
                .translate((-bb.xmin - (bb.xmax - bb.xmin) / 2,
                            -bb.ymin - (bb.ymax - bb.ymin) / 2,
                            (BOTTOM_H + 0.01) - 1.6)))
        return pcb


    # Base board PCB reference model
    def load_base_board_pcb():
        pcb = cq.importers.importStep(OUTPUT_DIR + '/refs/base_board2.step')
        bb = pcb.val().BoundingBox()
        pcb = \
            (pcb
                .translate((-bb.xmin - (bb.xmax - bb.xmin) / 2,
                            -bb.ymin - (bb.ymax - bb.ymin) / 2,
                            (MIDDLE_OFFSET + 0.01) - 1.6)))
        return pcb


    class RadiusSelector(cq.Selector):

        def __init__(self, rmin, rmax):
            self.rmin = rmin
            self.rmax = rmax

        def filter(self, objs):
            res = []
            for obj in objs:
                try:
                    if self.rmin <= obj.radius() <= self.rmax:
                        res.append(obj)
                except:
                    pass
            return res


    SCREW_SPACE = 4.0
    XDIM = bb.xlen + TH * 2
    YDIM = bb.ylen + TH * 2 + SCREW_SPACE

    screws_xy = \
        (
            (16.5, 10.0),
            (-16.5, 10.0),
            (-16.5, -14.5),
            (16.5, -14.5),
        )

    key_chain_xy = (-15.0, 8.5)

    FCUT_DEPTH = SCREW_SPACE + 0.5

    front_cutout = \
        (cq.Workplane('XY')
            .moveTo(0.0, FCUT_DEPTH + (-(YDIM - SCREW_SPACE) / 2 - SCREW_SPACE))
            .hLine(XDIM / 2 - SCREW_SPACE - 6.0)
            .line(SCREW_SPACE, -FCUT_DEPTH)
            .hLineTo(XDIM / 2 + 1)
            .vLine(-1.0)
            .hLineTo(0.0)
            .close()
            .extrude(HOUSING_H)
            .edges('|Z')
            .edges('>>X[1] or >>X[2]')
            .fillet(5.0)
            .mirror('YZ', union=True)
        )


    housing_whole = \
        (cq.Workplane('XY')
            .moveTo(0.0, -(YDIM - SCREW_SPACE) / 2 - SCREW_SPACE)
            .rect(XDIM, YDIM, centered=(True, False))
            .extrude(HOUSING_H)

            # Screw holes
            .faces('>Z')
            .workplane()
            .pushPoints(screws_xy)
            .circle((2.4) / 2)
            .cutBlind(-(HOUSING_H - 1.0))
            
            # Heat inserts bores
            .faces('>Z')
            .workplane(offset=-(HOUSING_H - 1.0))
            .pushPoints(screws_xy)
            .circle(3.5 / 2)
            .cutBlind(3.0)

            # Screw heads bores
            .faces('>Z')
            .workplane()
            .pushPoints(screws_xy)
            .circle(3.8 / 2)
            .cutBlind(-2.0)

            .cut(front_cutout)

            # Vertical fillets
            .edges('|Z and <X and >Y')
            .fillet(4.0)
            .edges('|Z and (<Y or >X)')
            .fillet(4.0)

            # Chamfers
            .faces('>X or <X or >Y or <Y or <<X[1] or >>X[1]')
            .edges('>Z or <Z')
            .chamfer(0.6)
        )

    housing_bottom = \
        (housing_whole
            .split(cq.Face.makePlane(basePnt=(0, 0, BOTTOM_H)))
            .solids('<Z')
            .faces('>Z')
            .workplane()
            .add(pcb_outline.translate((0, 0, BOTTOM_H)))
            .wires()
            .toPending()
            .offset2D(PCB_TOL)
            .cutBlind(-PCB_TH)
        )

    usb_port_cutout = \
        (cq.Workplane('XZ')
            .moveTo(6.7, 0.0)
            .rect(1.5, 1.5, centered=(True, False))
            .extrude(20.0)
            .edges('|Y and >Z')
            .chamfer(0.5)
            .moveTo(-0.5, 0.0)
            .rect(9.0, 3.6, centered=(True, False))
            .extrude(20.0)
            .edges('|Y and >Z')
            .chamfer(1.0)
            .rotate((0, 0, 0), (0, 0, 1), 180.0)
            .translate((0.0, 0.0, BOTTOM_H))
        )

    speaker_grill_cutout = \
        (cq.Workplane('YZ')
            .pushPoints(((0, 0), (0, -1.5), (0, -3), (0, 1.5), (0, 3)))
            .slot2D(7.0, 0.8)
            .extrude(10.0, both=True)
            .rotate((0, 0, 0), (1, 0, 0), 45.0)
            .intersect((cq.Workplane('YZ')
                        # .circle(5.0 / 2)
                        .rect(5.0, 4.0)
                        .extrude(10.0, both=True)
                        .edges('|X')
                        .fillet(0.5)))
            .translate((-20.0, -1.5, 7.0))
        )


    STRAP_TH = 3.0

    strap_cutout = \
        (cq.Workplane('XY')
            .vLine(10.0)
            .hLine(-STRAP_TH)
            .vLine(-10.0 - STRAP_TH)
            .hLine(15.0)
            .vLine(STRAP_TH)
            .close()
            .extrude(10.0)
            .edges('|Z and <X and <Y')
            .fillet(5.0)
            .edges('|Z')
            .edges('>>Y[1]')
            .edges('<X')
            .fillet(2.5)
            .edges('<Z')
            .fillet(STRAP_TH / 2 - 0.01)
            .translate((14.3, 6.8, BOTTOM_H + 1.0))
        )

    housing_middle = \
        (housing_whole
            .split(cq.Face.makePlane(basePnt=(0, 0, BOTTOM_H)))
            .solids('>Z')
            .split(cq.Face.makePlane(basePnt=(0, 0, MIDDLE_OFFSET)))
            .solids('<Z')
            .workplane()
            .add(pcb_outline.translate((0, 0, MIDDLE_OFFSET)))
            .wires()
            .toPending()
            .offset2D(-0.2)
            .cutThruAll()
            
            .workplane()
            .add(pcb_outline.translate((0, 0, MIDDLE_OFFSET)))
            .wires()
            .toPending()
            .offset2D(PCB_TOL)
            .cutBlind(-PCB_TH)
            .cut(usb_port_cutout)
            .cut(speaker_grill_cutout)

            .cut(strap_cutout)
            .cut(strap_cutout.mirror('YZ'))
        )


    buttons_xy = \
        (
            (-13.42, -1.315),
            (-13.42, -8.065),
            ( 13.68, -1.315),
            ( 13.68, -8.065),
        )

    disp_center_xy = (0.2, -4.8)

    button = \
        (cq.Workplane('XZ')
            .hLine(BUTTON_D / 2 + 0.6)
            .lineTo(BUTTON_D / 2, 0.6)
            .vLineTo(2.5)
            .radiusArc((0.0, 3.0), -4.0)
            .close()
            .revolve()
            .edges('>>Z[4]')
            .fillet(1.0)
            .faces('<Z')
            .workplane()
            .circle(2.5 / 2)
            .cutBlind(-0.3))

    buttons = \
        (cq.Workplane('XY')
            .pushPoints(buttons_xy)
            .eachpoint(button)
            .translate((0, 0, MIDDLE_OFFSET + 1.8)))


    housing_top_blind = \
        (housing_whole
            .split(cq.Face.makePlane(basePnt=(0, 0, MIDDLE_OFFSET)))
            .solids('>Z')

            # Cartridge slot cutout
            .moveTo(0.0, 6.0)
            .rect(11.6, 7.2, centered=True)
            .cutThruAll()

            # PCB-shape hollow out
            .faces('>Z')
            .workplane().tag('z_top')
            .add(pcb_outline.translate((0, 0, MIDDLE_OFFSET)))
            .wires()
            .toPending()
            .offset2D(-0.2)
            .cutBlind(PCB_TH)

            # Button holes
            .pushPoints(buttons_xy)
            .circle(BUTTON_D / 2 + TOL * 2)
            .cutThruAll()
            .workplaneFromTagged('z_top')
            .workplane(offset=PCB_TH).tag('z_btn')
            .pushPoints(buttons_xy)
            .circle(BUTTON_D / 2 + 0.7)
            .cutBlind(BUTTONS_OFFSET)
            # Button holes inner chamfers 
            .edges(RadiusSelector(BUTTON_D / 2 + TOL, BUTTON_D / 2 + TOL * 3))
            .edges('<Z')
            .chamfer(0.49)

            # Display filter recess
            .workplaneFromTagged('z_btn')
            .moveTo(*disp_center_xy)
            .rect(DISP_FILTER_SX + TOL, DISP_FILTER_SY + TOL, centered=True)
            # .cutBlind(DISP_FILTER_TH + DISP_FILTER_H_OFFSET)
            .cutBlind(DISP_FILTER_H_OFFSET)
        )

    housing_top = \
        (housing_top_blind
            # Display cutout
            .faces('>Z')
            .workplane()
            .moveTo(*disp_center_xy)
            .rect(15.0, 10.0, centered=True)
            .cutThruAll()
        )


    display_filter = \
        (cq.Workplane('XY')
            .rect(DISP_FILTER_SX, DISP_FILTER_SY, centered=True)
            .extrude(DISP_FILTER_TH)
            .translate((0.2, -4.8,
                        MIDDLE_OFFSET + 1.6 + DISP_FILTER_H_OFFSET)))



    show(
         # style(housing_whole, color='steelblue', alpha=0.8),
         # style(front_cutout, color='red', alpha=0.8),
         # style(housing_top, color='cyan', alpha=0.3, markersize=1),
         style(housing_top_blind, color='cyan', alpha=0.3, markersize=1),
         style(buttons, color='red', alpha=1.0, markersize=1),
         style(housing_middle, color='steelblue', alpha=0.3, markersize=1),
         style(housing_bottom, color='cyan', alpha=0.3, markersize=1),
         # style(display_filter, color='gray', alpha=0.3, markersize=1),
         style(load_power_supply_pcb(), color='green', alpha=1.0, markersize=1),
         style(load_base_board_pcb(), color='green', alpha=1.0, markersize=1),
         )

    housing_bottom.val().exportStep(OUTPUT_DIR + '/housing_bottom.stp')
    housing_middle.val().exportStep(OUTPUT_DIR + '/housing_middle.stp')
    housing_top.val().exportStep(OUTPUT_DIR + '/housing_top.stp')
    housing_top_blind.val().exportStep(OUTPUT_DIR + '/housing_top_blind.stp')
    button.val().exportStep(OUTPUT_DIR + '/button.stp')
