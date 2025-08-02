
import cadquery as cq
from cadquery.vis import show, style
from os.path import abspath, dirname

OUTPUT_DIR = f'{dirname(abspath(__file__))}'

TOL = 0.1

N_CARTRIDGES = 10
CARTRIDGE_SPACING = 4.0
CARTRIDGE_TH = 1.8

BOX_L = N_CARTRIDGES * CARTRIDGE_SPACING + 8.0
BOX_W = 21.0
BOX_H = 9.0

COVER_TH = 1.8
COVER_H = 13.0

if __name__ == '__main__':

    cartridge = \
        (cq.Workplane('YZ')
            .hLine(5.0)
            .vLine(4.5)
            .hLineTo(7.0)
            .vLine(7.0)
            .hLineTo(0)
            .mirrorY()
            .extrude(1.8)
            .edges('|X')
            .fillet(0.5))

    cartridges = cq.Workplane('XY')
    cx_offset = (CARTRIDGE_SPACING - CARTRIDGE_TH) / 2

    for i in range(N_CARTRIDGES):
        cartridges = cartridges.add(
                        cartridge.translate(
                            (i * CARTRIDGE_SPACING + cx_offset, 0, 0)))

    cx_offset = (BOX_L - N_CARTRIDGES * CARTRIDGE_SPACING) / 2

    box = \
        (cq.Workplane('XY')
            .rect(BOX_L, -BOX_W / 2, centered=(False, False))
            .extrude(BOX_H)
            .cut(cartridges.translate((cx_offset, 0.0, 2.0)))
            .faces('<X')
            .workplane()
            .moveTo(BOX_W / 2, BOX_H / 2)
            .rect(-COVER_TH - TOL, 20.0, centered=False)
            .cutThruAll()
            .moveTo(BOX_W / 2 - COVER_TH - TOL + 0.5, BOX_H * 3 / 4)
            .circle(1.0)
            .cutThruAll()
            .faces('>Z')
            .workplane()
            .moveTo(BOX_L, 0.0)
            .rect(-COVER_TH, -BOX_W / 2, centered=False)
            .cutBlind(-BOX_H / 2)
            .faces('<X')
            .workplane()
            .moveTo(0.0, -BOX_H )
            .rect(BOX_W / 2, BOX_H / 2 + COVER_H, centered=False)
            .extrude(COVER_TH)
            .mirror('XZ', union=True)
            .edges('<Z')
            .chamfer(0.5)
            )

    cover = \
        (cq.Workplane('YZ')
            .rect(BOX_W / 2, COVER_H, centered=False)
            .extrude(BOX_L)
            .moveTo(0, 0)
            .rect(BOX_W / 2 - COVER_TH, COVER_H - COVER_TH, centered=False)
            .cutBlind(BOX_L - COVER_TH)
            .moveTo(BOX_W / 2 - COVER_TH + 0.5, BOX_H / 4)
            .circle(1.0)
            .extrude(BOX_L - COVER_TH)
            .translate((15.0, 0.0, BOX_H / 2))
            .mirror('XZ', union=True)
            .edges('>X')
            # .chamfer(1.0)
            )

    show(style(box, markersize=1, alpha=0.5, color='aquamarine'),
         style(cover, markersize=1, alpha=0.5, color='lightskyblue'))

    box.val().exportStep(OUTPUT_DIR + '/cartridge_storage_box.stp')
    cover.val().exportStep(OUTPUT_DIR + '/cartridge_storage_box_cover.stp')

