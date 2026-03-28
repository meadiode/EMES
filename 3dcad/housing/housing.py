import cadquery as cq
try:
    from xvis import show, style
except ImportError:
    from cadquery.vis import show, style

from cadquery.occ_impl.shapes import edgesToWires
from os.path import abspath, dirname

from kiutils.board import Board, GrArc, GrLine


OUTPUT_DIR = f'{dirname(abspath(__file__))}'


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


class Housing:

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
    BUTTONS_OFFSET = 0.2

    SCREW_SPACE = 4.0
    FCUT_DEPTH = SCREW_SPACE + 0.5
    STRAP_TH = 3.0

    SCREWS_XY = \
        (
            (16.5, 10.0),
            (-16.5, 10.0),
            (-16.5, -14.5),
            (16.5, -14.5),
        )

    BUTTONS_XY = \
        (
            (-13.42, -1.315),
            (-13.42, -8.065),
            ( 13.68, -1.315),
            ( 13.68, -8.065),
        )

    DISP_CENTER_XY = (0.2, -4.8)


    def __init__(self, blind_top, heatserts):
        self.blind_top = blind_top
        self.heatserts = heatserts

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
        
        pcb_outline = (
            cq.Workplane('XY')
                .add(wire))

        bb = pcb_outline.val().BoundingBox()
        self.pcb_outline = (
            pcb_outline
                .translate((-bb.xmin - (bb.xmax - bb.xmin) / 2,
                           -bb.ymin - (bb.ymax - bb.ymin) / 2, 0.0))
                .rotate((0, 0, 0), (0, 0, 1), 180.0))

        self.XDIM = bb.xlen + self.TH * 2
        self.YDIM = bb.ylen + self.TH * 2 + self.SCREW_SPACE


    # Power supply PCB reference model
    def load_power_supply_pcb(self):
        pcb = cq.importers.importStep(OUTPUT_DIR + '/refs/power_supply.step')
        bb = pcb.val().BoundingBox()
        pcb = (
            pcb
                .translate((-bb.xmin - (bb.xmax - bb.xmin) / 2,
                            -bb.ymin - (bb.ymax - bb.ymin) / 2,
                            (self.BOTTOM_H + 0.01) - 1.6)))
        self.ps_pcb = pcb
        return pcb


    # Base board PCB reference model
    def load_base_board_pcb(self):
        pcb = cq.importers.importStep(OUTPUT_DIR + '/refs/base_board2.step')
        bb = pcb.val().BoundingBox()
        pcb = (
            pcb
                .translate((-bb.xmin - (bb.xmax - bb.xmin) / 2,
                            -bb.ymin - (bb.ymax - bb.ymin) / 2,
                            (self.MIDDLE_OFFSET + 0.01) - 1.6)))
        self.bb_pcb = pcb
        return pcb


    def build_whole_solid(self):
        front_cutout = (
            cq.Workplane('XY')
                .moveTo(0.0, self.FCUT_DEPTH + (-(self.YDIM - self.SCREW_SPACE) / 2 - self.SCREW_SPACE))
                .hLine(self.XDIM / 2 - self.SCREW_SPACE - 6.0)
                .line(self.SCREW_SPACE, -self.FCUT_DEPTH)
                .hLineTo(self.XDIM / 2 + 1)
                .vLine(-1.0)
                .hLineTo(0.0)
                .close()
                .extrude(self.HOUSING_H)
                .edges('|Z')
                .edges('>>X[1] or >>X[2]')
                .fillet(5.0)
                .mirror('YZ', union=True)
            )

        screw_cutout = (
            cq.Workplane('XY')
                .circle(3.8 / 2)
                .extrude(2.0)
                .faces('>Z')
                .workplane()
                .circle(2.4 / 2)
                .extrude(self.TOP_H - 2 + self.MIDDLE_H)
                .rotate((0, 0, 0), (1, 0, 0), 180.0)
                .translate((0, 0, self.HOUSING_H))
        )

        if self.heatserts:
            screw_cutout = (
                screw_cutout
                    .faces('<Z')
                    .workplane()
                    .circle(3.5 / 2)
                    .extrude(3.0)
            )
        else: # tap pilot hole
            screw_cutout = (
                screw_cutout
                    .faces('<Z')
                    .workplane()
                    .circle(1.6 / 2)
                    .extrude(3.5)
                    .edges('<Z')
                    .chamfer(0.4)
            )

        screws = (
            cq.Workplane('XY')
                .pushPoints(self.SCREWS_XY)
                .eachpoint(screw_cutout)
        )

        self.housing_whole = (
            cq.Workplane('XY')
                .moveTo(0.0, -(self.YDIM - self.SCREW_SPACE) / 2 - self.SCREW_SPACE)
                .rect(self.XDIM, self.YDIM, centered=(True, False))
                .extrude(self.HOUSING_H)

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

                .cut(screws)
            )

        return self.housing_whole


    def build_bottom(self):
        if not hasattr(self, 'housing_whole'):
            self.build_whole_solid()

        self.housing_bottom = (
            self.housing_whole
                .split(cq.Face.makePlane(basePnt=(0, 0, self.BOTTOM_H)))
                .solids('<Z')
                .faces('>Z')
                .workplane()
                .add(self.pcb_outline.translate((0, 0, self.BOTTOM_H)))
                .wires()
                .toPending()
                .offset2D(self.PCB_TOL)
                .cutBlind(-self.PCB_TH)
            )
        return self.housing_bottom


    def build_middle(self):
        usb_port_cutout = (
            cq.Workplane('XZ')
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
                .translate((0.0, 0.0, self.BOTTOM_H))
            )

        speaker_grill_cutout = (
            cq.Workplane('YZ')
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

        strap_cutout = \
            (cq.Workplane('XY')
                .vLine(10.0)
                .hLine(-self.STRAP_TH)
                .vLine(-10.0 - self.STRAP_TH)
                .hLine(15.0)
                .vLine(self.STRAP_TH)
                .close()
                .extrude(10.0)
                .edges('|Z and <X and <Y')
                .fillet(5.0)
                .edges('|Z')
                .edges('>>Y[1]')
                .edges('<X')
                .fillet(2.5)
                .edges('<Z')
                .fillet(self.STRAP_TH / 2 - 0.01)
                .translate((14.3, 6.8, self.BOTTOM_H + 1.0))
            )

        if not hasattr(self, 'housing_whole'):
            self.build_whole_solid()

        self.housing_middle = \
            (self.housing_whole
                .split(cq.Face.makePlane(basePnt=(0, 0, self.BOTTOM_H)))
                .solids('>Z')
                .split(cq.Face.makePlane(basePnt=(0, 0, self.MIDDLE_OFFSET)))
                .solids('<Z')
                .workplane()
                .add(self.pcb_outline.translate((0, 0, self.MIDDLE_OFFSET)))
                .wires()
                .toPending()
                .offset2D(-0.2)
                .cutThruAll()
                
                .workplane()
                .add(self.pcb_outline.translate((0, 0, self.MIDDLE_OFFSET)))
                .wires()
                .toPending()
                .offset2D(self.PCB_TOL)
                .cutBlind(-self.PCB_TH)
                .cut(usb_port_cutout)
                .cut(speaker_grill_cutout)

                .cut(strap_cutout)
                .cut(strap_cutout.mirror('YZ'))
            )

        return self.housing_middle


    def build_top(self):
        if not hasattr(self, 'housing_whole'):
            self.build_whole_solid()

        self.housing_top = (
            self.housing_whole
                .split(cq.Face.makePlane(basePnt=(0, 0, self.MIDDLE_OFFSET)))
                .solids('>Z')

                # Cartridge slot cutout
                .moveTo(0.0, 6.0)
                .rect(11.6, 7.2, centered=True)
                .cutThruAll()

                # PCB-shape hollow out
                .faces('>Z')
                .workplane().tag('z_top')
                .add(self.pcb_outline.translate((0, 0, self.MIDDLE_OFFSET)))
                .wires()
                .toPending()
                .offset2D(-0.2)
                .cutBlind(self.PCB_TH)

                # Button holes
                .pushPoints(self.BUTTONS_XY)
                .circle(self.BUTTON_D / 2 + self.TOL * 2)
                .cutThruAll()
                .workplaneFromTagged('z_top')
                .workplane(offset=self.PCB_TH).tag('z_btn')
                .pushPoints(self.BUTTONS_XY)
                .circle(self.BUTTON_D / 2 + 0.7)
                .cutBlind(self.BUTTONS_OFFSET)
                # Button holes inner chamfers 
                .edges(RadiusSelector(self.BUTTON_D / 2 + self.TOL,
                                      self.BUTTON_D / 2 + self.TOL * 3))
                .edges('<Z')
                .chamfer(0.49)

                # Display filter recess
                .workplaneFromTagged('z_btn')
                .moveTo(*self.DISP_CENTER_XY)
                .rect(self.DISP_FILTER_SX + self.TOL, self.DISP_FILTER_SY + self.TOL, centered=True)
                .cutBlind(self.DISP_FILTER_H_OFFSET)
            )

        if not self.blind_top:
            self.housing_top = (
                self.housing_top
                    # Display cutout
                    .faces('>Z')
                    .workplane()
                    .moveTo(*self.DISP_CENTER_XY)
                    .rect(15.0, 10.0, centered=True)
                    .cutThruAll()
                )

        return self.housing_top


    def build_button(self):
        self.button = (
            cq.Workplane('XZ')
                .hLine(self.BUTTON_D / 2 + 0.6)
                .lineTo(self.BUTTON_D / 2, 0.6)
                .vLineTo(2.5)
                .radiusArc((0.0, 3.0), -4.0)
                .close()
                .revolve()
                .edges('>>Z[4]')
                .fillet(1.0)
                # .faces('<Z')
                # .workplane()
                # .circle(2.5 / 2)
                # .cutBlind(-0.3)
                )

        return self.button


    def build_buttons(self):
        if not hasattr(self, 'button'):
            self.build_button()

        self.buttons = (
            cq.Workplane('XY')
                .pushPoints(self.BUTTONS_XY)
                .eachpoint(self.button)
                .translate((0, 0, self.MIDDLE_OFFSET + 1.8)))

        return self.buttons


    def build_display_filter(self):
        self.display_filter = (
            cq.Workplane('XY')
                .rect(self.DISP_FILTER_SX, self.DISP_FILTER_SY, centered=True)
                .extrude(self.DISP_FILTER_TH)
                .translate((0.2, -4.8,
                            self.MIDDLE_OFFSET + 1.6 + self.DISP_FILTER_H_OFFSET)))

        return self.display_filter


    def build_all(self):
        self.build_top()
        self.build_middle()
        self.build_bottom()
        self.build_buttons()
        if not self.blind_top:
            self.build_display_filter()


if __name__ == '__main__':
    hs_fdm = Housing(blind_top=True, heatserts=True)
    hs_fdm.build_all()

    show(
         # style(hs_fdm.build_whole_solid(), color='cyan', alpha=0.3, markersize=1),
         # style(hs_fdm.build_bottom(), color='cyan', alpha=0.3, markersize=1),
         style(hs_fdm.housing_top, color='cyan', alpha=0.3, markersize=1),
         style(hs_fdm.buttons, color='red', alpha=0.1, markersize=1),
         style(hs_fdm.housing_middle, color='steelblue', alpha=0.3, markersize=1),
         style(hs_fdm.housing_bottom, color='cyan', alpha=0.3, markersize=1),
         # # style(display_filter, color='gray', alpha=0.3, markersize=1),
         # style(load_power_supply_pcb(), color='green', alpha=1.0, markersize=1),
         style(hs_fdm.load_base_board_pcb(), color='green', alpha=1.0, markersize=1),
         )

    # housing_bottom.val().exportStep(OUTPUT_DIR + '/housing_bottom.stp')
    # housing_middle.val().exportStep(OUTPUT_DIR + '/housing_middle.stp')
    # housing_top.val().exportStep(OUTPUT_DIR + '/housing_top.stp')
    # housing_top_blind.val().exportStep(OUTPUT_DIR + '/housing_top_blind.stp')
    # button.val().exportStep(OUTPUT_DIR + '/button.stp')
