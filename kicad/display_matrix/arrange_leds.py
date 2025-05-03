import pcbnew
import math


def mm2nm(mm):
    return int(mm * 1_000_000)

OX = mm2nm(100.0)
OY = mm2nm(100.0)

board = pcbnew.GetBoard()

for footprint in board.GetFootprints():
    ref = footprint.GetReference()

    if ref.startswith('D'):
        footprint.SetOrientationDegrees(-45.0)
        
        for field in footprint.GetFields():
            field_name = field.GetName().lower()

            if field_name in ['reference', 'value']:
                field.SetVisible(False)


        id_ = int(ref[1:], 10) - 1
        row = id_ // 15
        col = id_ % 15

        footprint.SetX(OX + mm2nm(col * 1.0))
        footprint.SetY(OY + mm2nm(row * 1.0))



pcbnew.Refresh()
