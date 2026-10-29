/*
 * starch_cell.ijm  --  one pass: crop to the cell, save that image, measure starch
 *                      Fiji / ImageJ 1.x
 *
 * The only file written is the cleared image (<name>_roi.tif). Measurements go
 * to the Results table and the Log window; save those yourself if you want them.
 *
 * HOW TO RUN
 *   1. File > Open...            the 1550X image
 *   2. Outline the symbiont cell with the polygon or freehand tool
 *   3. Plugins > Macros > Run...  this file
 *
 * What it does
 *   - measures the cell area from your outline            (the denominator)
 *   - duplicates the image, clears everything outside     (original untouched)
 *   - saves that cleared image as <name>_roi.tif
 *   - thresholds and measures the starch grains inside it
 *   - pauses so you can delete false positives, then re-measures
 *   - appends one row per grain to Results
 *
 * Run it again on the next cell and Results rows accumulate, so you can do
 * several cells and save Results once at the end.
 *
 * ROI Manager vs Results -- these are deliberately different:
 *   The ROI Manager is RESET at the start of every run. It only ever holds the
 *   grains of the cell you are working on, so reviewing and re-measuring is
 *   unambiguous. Results, by contrast, accumulates across cells and each row
 *   carries its own Cell_um2, so pooled rows stay correctly normalisable.
 *   If you want to keep a cell's ROIs, save them yourself (ROI Manager >
 *   More >> Save) before running the macro on the next cell.
 *
 * Calibration measured from the burned-in scale bars:
 *     1550X : 150 px = 1 um   ->  150.0 px/um,  6.67 nm/px
 *      570X : 112 px = 2 um   ->   56.0 px/um, 17.86 nm/px
 * Do not use this on the 570X series. There the grains are torn by sectioning
 * and span both the brightest and darkest pixels, so thresholding is
 * meaningless and they must be traced by hand.
 *
 * Threshold: fix it once by eye with Image > Adjust > Threshold and keep the
 * same number for every image in the series. It drives the answer -- on
 * pna_LD_control_1550X_0004, 174 gives 18.8% of cell area and 214 gives 12.1%.
 * Do not let it be picked automatically: the grain interiors are clipped at
 * 255 in this series, which biases any automatic estimate high.
 */

// ------------------------------------------------------------------ dialog
Dialog.create("Starch in one cell");
Dialog.addNumber("Scale bar length (pixels)", 150);
Dialog.addNumber("Scale bar value (um)", 1);
Dialog.addNumber("Threshold (lower)", 174);
Dialog.addNumber("Minimum grain area (um^2)", 0.02);
Dialog.addString("Condition label", "control");
Dialog.addString("Saved image suffix", "_roi");
Dialog.addString("Output folder (blank = same folder as the image)", "", 40);
Dialog.addCheckbox("Crop to the cell bounding box", false);
Dialog.addCheckbox("Exclude grains touching the cell outline", false);
Dialog.addCheckbox("Pause to review grains before recording", true);
Dialog.addCheckbox("Clear Results before measuring (start a new series)", false);
Dialog.addCheckbox("Keep the cleared image open", true);
Dialog.show();

barPx    = Dialog.getNumber();
barUm    = Dialog.getNumber();
thr      = Dialog.getNumber();
minA     = Dialog.getNumber();
label    = Dialog.getString();
suffix   = Dialog.getString();
outDir   = Dialog.getString();
doCrop   = Dialog.getCheckbox();
excl     = Dialog.getCheckbox();
doReview = Dialog.getCheckbox();
doClear  = Dialog.getCheckbox();
keepOpen = Dialog.getCheckbox();

// ------------------------------------------------------------------ checks
if (nImages == 0) exit("Open the image first.");
if (selectionType() == -1)
    exit("Outline the symbiont cell first, then run the macro.");

srcID = getImageID();
title = getTitle();
base  = replace(title, "\\.tiff?$", "");

// Where the cleared image goes: the dialog field if given, otherwise the
// folder the image came from, otherwise ask.
dir = outDir;
if (dir == "") dir = getDirectory("image");
if (dir == "") dir = getDirectory("Choose where to save the cleared image");
if (!endsWith(dir, File.separator)) dir = dir + File.separator;
if (!File.isDirectory(dir)) File.makeDirectory(dir);
if (!File.isDirectory(dir)) exit("Cannot write to:\n" + dir);

// Clear Outside fills with the background colour. If that is white you get 255
// outside the cell, indistinguishable from saturated starch, and everything
// downstream is wrong. Force it black.
setForegroundColor(255, 255, 255);
setBackgroundColor(0, 0, 0);
setOption("BlackBackground", true);

// ------------------------------------------- cell area, from your outline
run("Set Scale...", "distance=" + barPx + " known=" + barUm + " unit=um");
getPixelSize(unit, pw, ph);
getStatistics(cellArea, cellMean);
Roi.getBounds(bx, by, bw, bh);

print("\\Clear");
print("source     : " + title);
print("scale      : " + d2s(1/pw, 2) + " px/" + unit + "  (" + d2s(pw*1000, 2) + " nm/px)");
print("cell area  : " + d2s(cellArea, 2) + " " + unit + "^2");
print("cell mean  : " + d2s(cellMean, 1));

// Reset the manager so it holds this cell only, then park the outline at
// index 0 to transfer it to the duplicate.
roiManager("reset");
roiManager("Add");

// -------------------------------------------- duplicate and clear outside
selectImage(srcID);
run("Select None");                       // else Duplicate crops to the bbox
run("Duplicate...", "title=__cleared");
workID = getImageID();
if (bitDepth() != 8) run("8-bit");
run("Set Scale...", "distance=" + barPx + " known=" + barUm + " unit=um");

roiManager("Select", 0);
if (selectionType() == -1) {
    close();
    roiManager("reset");
    exit("The outline would not transfer to the duplicate.");
}
run("Clear Outside");

if (doCrop) {
    run("Select None");
    makeRectangle(bx, by, bw, bh);
    run("Crop");
}
run("Select None");

// drop the cell outline; from here the manager holds starch grains only
roiManager("reset");

// ------------------------------------------------------------ save the image
outName = base + suffix;
saveAs("Tiff", dir + outName + ".tif");
workID = getImageID();
print("saved      : " + dir + outName + ".tif");

// -------------------------------------------------------- measure the starch
// Outside the cell is now 0, well below any sensible threshold, so no
// selection is needed to confine the particle search.
run("Set Measurements...", "area shape feret's redirect=None decimal=4");

if (doClear) run("Clear Results");
nBefore = nResults;

setThreshold(thr, 255);
opts = "size=" + d2s(minA, 4) + "-Infinity circularity=0.00-1.00"
     + " show=Nothing display include add";
if (excl) opts = opts + " exclude";
run("Analyze Particles...", opts);
resetThreshold();

if (nResults == nBefore) {
    print("");
    print("No grains passed the filter. Lower the threshold, or check that the");
    print("outline was around the algal cell.");
    if (!keepOpen) { selectImage(workID); close(); }
    selectImage(srcID); run("Select None");
    exit();
}

// ------------------------------------------------------------------ review
if (doReview) {
    selectImage(workID);
    roiManager("Show All with labels");
    waitForUser("Review the grains",
        "Delete false positives in the ROI Manager (select the entry, press\n"
      + "Delete). The macro then re-measures whatever is left.\n"
      + " \n"
      + "What to remove:\n"
      + "  - lipid bodies and vacuoles: uniform grey, not bright\n"
      + "  - the pyrenoid: darker than starch\n"
      + "  - anything that is clearly membrane or intercristal space\n"
      + " \n"
      + "Merged grains: sorting Results by Solidity finds them, but splitting\n"
      + "them changes the count, not the total area. Leave them unless you\n"
      + "need per-grain sizes.\n"
      + " \n"
      + "Click OK when done.");

    // Discard this cell's provisional rows and re-measure the curated ROIs.
    // Rows from earlier cells (0 .. nBefore-1) are left alone.
    IJ.deleteRows(nBefore, nResults - 1);
    if (roiManager("count") == 0) {
        print("");
        print("All grains were deleted - nothing recorded for this cell.");
        if (!keepOpen) { selectImage(workID); close(); }
        selectImage(srcID); run("Select None");
        exit();
    }
    selectImage(workID);
    roiManager("Deselect");
    roiManager("Measure");
}

// Stamp provenance on the rows from THIS cell only, which is why the loop
// starts at nBefore rather than 0.
total = 0;
for (i = nBefore; i < nResults; i++) {
    total = total + getResult("Area", i);
    setResult("Image",       i, outName + ".tif");
    setResult("Condition",   i, label);
    // numeric, not d2s() strings, so the Results table stays sortable
    setResult("Cell_um2",    i, cellArea);
    setResult("Pct_of_cell", i, 100 * getResult("Area", i) / cellArea);
    setResult("Threshold",   i, thr);
    setResult("Px_per_um",   i, 1/pw);
}
updateResults();

nNew = nResults - nBefore;
pct  = 100 * total / cellArea;
print("threshold  : " + thr + "-255");
print("grains     : " + nNew);
print("starch     : " + d2s(total, 3) + " " + unit + "^2");
print("mean grain : " + d2s(total/nNew, 4) + " " + unit + "^2");
print("STARCH/CELL: " + d2s(pct, 2) + " %");
print("");
print("Results rows " + (nBefore+1) + "-" + nResults + " are this cell.");
print("The ROI Manager holds this cell only and is reset on the next run;");
print("save it now (More >> Save) if you want to keep it.");

// ------------------------------------------------------------------ tidy up
if (!keepOpen) { selectImage(workID); close(); }
selectImage(srcID);
run("Select None");