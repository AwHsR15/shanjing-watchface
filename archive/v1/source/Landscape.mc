using Toybox.Graphics;
function drawMountain(dc, volcano, dusk) {
    dc.setColor(0x46636b, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[22, 225], [73, 166], [101, 187], [153, 134], [204, 194], [265, 151], [316, 185], [361, 153], [432, 223], [432, 246], [22, 246]]);
    dc.setColor(0x2b464f, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[30, 244], [100, 192], [130, 209], [185, 157], [235, 202], [284, 164], [336, 213], [378, 189], [425, 229], [425, 251], [30, 251]]);
    dc.setColor(0x152a34, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[77, 251], [150, 188], [180, 195], [244, 104], [272, 139], [288, 132], [375, 247]]);
    dc.setColor(dusk ? 0xE6BD8D : 0xe3e9dc, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[169, 211], [244, 104], [259, 125], [243, 119], [221, 156], [226, 133], [207, 163], [208, 147], [188, 183], [190, 169]]);
    dc.setColor(0x8ba8ad, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[244, 104], [272, 139], [288, 132], [302, 154], [289, 147], [293, 166], [272, 151], [256, 173], [265, 149], [246, 163], [254, 140], [235, 160], [245, 130], [227, 151]]);
    dc.setColor(0xceded6, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[212, 176], [229, 157], [218, 179], [215, 197], [200, 218], [204, 196], [189, 212]]);
    dc.setColor(0x557982, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[266, 166], [280, 157], [297, 182], [286, 176], [294, 194], [278, 184], [261, 210], [274, 183]]);
    dc.setColor(0x203a43, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[37, 251], [92, 222], [129, 230], [167, 211], [203, 238], [245, 218], [281, 235], [330, 208], [367, 220], [421, 211], [429, 259], [26, 259]]);
    dc.setColor(0x0d1d25, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[16, 249], [65, 235], [102, 245], [154, 235], [190, 252], [244, 242], [298, 250], [353, 233], [409, 245], [438, 239], [438, 266], [16, 266]]);
    dc.setColor(0x071217, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[48, 222], [44, 232], [46, 232], [40, 240], [45, 240], [45, 248], [51, 248], [51, 240], [56, 240], [50, 232], [52, 232]]);
    dc.setColor(0x071217, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[69, 212], [65, 222], [67, 222], [61, 240], [66, 240], [66, 248], [72, 248], [72, 240], [77, 240], [71, 222], [73, 222]]);
    dc.setColor(0x071217, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[87, 230], [83, 240], [85, 240], [79, 246], [84, 246], [84, 254], [90, 254], [90, 246], [95, 246], [89, 240], [91, 240]]);
    dc.setColor(0x071217, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[361, 225], [357, 235], [359, 235], [353, 244], [358, 244], [358, 252], [364, 252], [364, 244], [369, 244], [363, 235], [365, 235]]);
    dc.setColor(0x071217, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[383, 213], [379, 223], [381, 223], [375, 244], [380, 244], [380, 252], [386, 252], [386, 244], [391, 244], [385, 223], [387, 223]]);
    dc.setColor(0x071217, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[402, 224], [398, 234], [400, 234], [394, 246], [399, 246], [399, 254], [405, 254], [405, 246], [410, 246], [404, 234], [406, 234]]);
    if(volcano) {
        dc.setColor(0xE88355, Graphics.COLOR_TRANSPARENT); dc.fillPolygon([[242,112],[249,119],[241,143],[250,163],[239,188],[243,165],[234,146]]);
    }
}