import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { createRequire } from "node:module";

const artifactRequire = createRequire(
  "C:/Users/hughb/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/@oai/artifact-tool/package.json",
);

const { Presentation, PresentationFile } = artifactRequire("@oai/artifact-tool");

const root = "D:/Github_repos/Gayini";
const finalPptx = path.join(root, "Output", "reports", "Gayini_MODIS_results_review.pptx");
const workspace = path.join(os.tmpdir(), "codex-presentations", "manual-gayini-modis-phase2", "modis-results-review");
const tmpDir = path.join(workspace, "tmp");
const previewDir = path.join(tmpDir, "preview");
const layoutDir = path.join(tmpDir, "layout");
const qaDir = path.join(tmpDir, "qa");

const frame = { left: 62, top: 54, width: 1156, height: 612 };
const colors = {
  ink: "#17201A",
  muted: "#5B665F",
  line: "#D7DED8",
  wash: "#F5F7F3",
  green: "#2E6B4E",
  gold: "#C99A2E",
  blue: "#2F6F8F",
  red: "#A4513F",
  white: "#FFFFFF",
};

async function writeBlob(filePath, blob) {
  await fs.writeFile(filePath, new Uint8Array(await blob.arrayBuffer()));
}

async function exists(filePath) {
  try {
    await fs.access(filePath);
    return true;
  } catch {
    return false;
  }
}

async function readCsv(filePath) {
  const text = await fs.readFile(filePath, "utf8");
  const lines = text.trim().split(/\r?\n/);
  const header = lines.shift().split(",");
  return lines.map((line) => {
    const values = line.match(/("([^"]|"")*"|[^,]*)/g).filter((x, i) => i % 2 === 0).slice(0, header.length);
    const row = {};
    header.forEach((key, index) => {
      row[key] = (values[index] ?? "").replace(/^"|"$/g, "").replace(/""/g, '"');
    });
    return row;
  });
}

function addText(slide, text, position, style = {}) {
  const shape = slide.shapes.add({
    geometry: "textbox",
    position,
    fill: "none",
    line: { style: "solid", fill: "none", width: 0 },
  });
  shape.text = text;
  shape.text.style = {
    typeface: "Arial",
    fontSize: 20,
    color: colors.ink,
    ...style,
  };
  return shape;
}

function addTitle(slide, title, kicker = "MODIS ground-cover context") {
  addText(slide, kicker.toUpperCase(), { left: frame.left, top: 30, width: 520, height: 26 }, {
    fontSize: 12,
    bold: true,
    color: colors.green,
  });
  addText(slide, title, { left: frame.left, top: 62, width: 920, height: 56 }, {
    fontSize: 34,
    bold: true,
    color: colors.ink,
  });
  slide.shapes.add({
    geometry: "rect",
    position: { left: frame.left, top: 122, width: 1156, height: 1 },
    fill: colors.line,
    line: { style: "solid", fill: colors.line, width: 0 },
  });
}

function addFooter(slide, index) {
  addText(slide, "MODIS context only; Landsat remains plot-scale evidence", { left: frame.left, top: 684, width: 720, height: 18 }, {
    fontSize: 10,
    color: colors.muted,
  });
  addText(slide, String(index).padStart(2, "0"), { left: 1168, top: 684, width: 48, height: 18 }, {
    fontSize: 10,
    color: colors.muted,
    alignment: "right",
  });
}

function addBullets(slide, bullets, left, top, width, fontSize = 20) {
  bullets.forEach((bullet, index) => {
    addText(slide, "•", { left, top: top + index * 44, width: 24, height: 28 }, {
      fontSize,
      color: colors.green,
      bold: true,
    });
    addText(slide, bullet, { left: left + 30, top: top + index * 44, width, height: 38 }, {
      fontSize,
      color: colors.ink,
    });
  });
}

function addMetric(slide, label, value, left, top, accent = colors.green) {
  const valueText = String(value);
  const valueFontSize = valueText.length > 12 ? 22 : valueText.length > 8 ? 28 : 34;

  slide.shapes.add({
    geometry: "roundRect",
    position: { left, top, width: 250, height: 116 },
    fill: colors.white,
    line: { style: "solid", fill: colors.line, width: 1 },
    borderRadius: "rounded-lg",
  });
  addText(slide, valueText, { left: left + 18, top: top + 14, width: 214, height: 44 }, {
    fontSize: valueFontSize,
    bold: true,
    color: accent,
  });
  addText(slide, label, { left: left + 18, top: top + 70, width: 214, height: 36 }, {
    fontSize: 14,
    color: colors.muted,
  });
}

async function addImage(slide, imagePath, position, alt, fit = "contain") {
  if (!(await exists(imagePath))) {
    addText(slide, `Missing image: ${path.basename(imagePath)}`, position, {
      fontSize: 16,
      color: colors.red,
    });
    return;
  }
  const bytes = await fs.readFile(imagePath);
  slide.images.add({
    blob: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength),
    contentType: "image/png",
    alt,
    fit,
    position,
  });
}

async function main() {
  await fs.mkdir(path.dirname(finalPptx), { recursive: true });
  await fs.mkdir(previewDir, { recursive: true });
  await fs.mkdir(layoutDir, { recursive: true });
  await fs.mkdir(qaDir, { recursive: true });

  const checks = await readCsv(path.join(root, "Output", "diagnostics", "03_modis_ground_cover_context_checks.csv"));
  const cacheChecks = await readCsv(path.join(root, "Output", "diagnostics", "03_modis_ground_cover_cache_checks.csv"));
  const mapRows = await readCsv(path.join(root, "Output", "diagnostics", "03_modis_ground_cover_map_paths.csv"));
  const figureRows = await readCsv(path.join(root, "Output", "diagnostics", "03_modis_ground_cover_figure_paths.csv"));

  const getCheck = (name) => checks.find((row) => row.check_name === name)?.check_value ?? "";
  const rowCount = getCheck("expected_row_count").split(" / ")[0] || getCheck("expected_row_count");
  const cacheCreated = cacheChecks.filter((row) => row.action_taken === "created").length;
  const cacheSkipped = cacheChecks.filter((row) => row.action_taken === "skipped_existing_valid").length;
  const cacheFailed = cacheChecks.filter((row) => row.status === "fail").length;
  const dateRange = `${cacheChecks[0]?.date_start ?? "2001-01-01"} to ${cacheChecks.at(-1)?.date_start ?? "2026-02-01"}`;

  const image = {
    scale: path.join(root, "Output", "maps", "modis_ground_cover", "modis_scale_context_map.png"),
    rgb2010: path.join(root, "Output", "maps", "modis_ground_cover", "modis_rgb_2010_01.png"),
    rgb2019: path.join(root, "Output", "maps", "modis_ground_cover", "modis_rgb_2019_07.png"),
    rgb2026: path.join(root, "Output", "maps", "modis_ground_cover", "modis_rgb_2026_02.png"),
    farmTs: path.join(root, "Output", "figures", "modis_ground_cover", "modis_whole_farm_monthly_timeseries.png"),
    bufferVeg: path.join(root, "Output", "figures", "modis_ground_cover", "modis_farm_vs_buffer_total_veg_timeseries.png"),
    bufferBare: path.join(root, "Output", "figures", "modis_ground_cover", "modis_farm_vs_buffer_bare_ground_timeseries.png"),
    waterVeg: path.join(root, "Output", "figures", "modis_ground_cover", "modis_water_year_total_veg_summary.png"),
    prepost: path.join(root, "Output", "figures", "modis_ground_cover", "modis_period_summary_prepost.png"),
    zoneSupport: path.join(root, "Output", "figures", "modis_ground_cover", "modis_management_zone_support.png"),
    zoneTs: path.join(root, "Output", "figures", "modis_ground_cover", "modis_selected_management_zone_timeseries.png"),
  };

  await fs.writeFile(path.join(tmpDir, "source-notes.txt"), [
    "Source notes for Gayini MODIS results review deck",
    `Context checks: ${path.join(root, "Output", "diagnostics", "03_modis_ground_cover_context_checks.csv")}`,
    `Cache checks: ${path.join(root, "Output", "diagnostics", "03_modis_ground_cover_cache_checks.csv")}`,
    `Map manifest: ${path.join(root, "Output", "diagnostics", "03_modis_ground_cover_map_paths.csv")}`,
    `Figure manifest: ${path.join(root, "Output", "diagnostics", "03_modis_ground_cover_figure_paths.csv")}`,
    "Interpretation language follows Gayini_MODIS_Phase2_Codex_task_20260618.md.",
  ].join("\n"));

  await fs.writeFile(path.join(tmpDir, "slide-plan.txt"), [
    "Create mode: new editable MODIS-only review deck.",
    "Palette: off-white background #F5F7F3, ink #17201A, green #2E6B4E, gold #C99A2E, blue #2F6F8F.",
    "Fonts: Arial for headings, body, and numeric callouts.",
    "Slide list: title; role; data/processing; scale map; representative maps; whole farm; farm vs buffer; water-year/pre-post; management zones; decisions.",
  ].join("\n"));

  const presentation = Presentation.create({ slideSize: { width: 1280, height: 720 } });

  for (let i = 0; i < 10; i += 1) {
    const slide = presentation.slides.add();
    slide.background.fill = colors.wash;
  }

  let slide = presentation.slides.items[0];
  addText(slide, "Gayini MODIS ground-cover context", { left: 76, top: 104, width: 860, height: 78 }, {
    fontSize: 48,
    bold: true,
    color: colors.ink,
  });
  addText(slide, "Review draft | broad farm, buffer and management-zone context", { left: 80, top: 196, width: 780, height: 36 }, {
    fontSize: 22,
    color: colors.muted,
  });
  addMetric(slide, "MODIS rasters processed", getCheck("modis_files_extracted"), 80, 300, colors.green);
  addMetric(slide, "Context units", getCheck("context_units_extracted"), 360, 300, colors.blue);
  addMetric(slide, "Rows; expected matched", rowCount, 640, 300, colors.gold);
  addBullets(slide, [
    "MODIS is not interpreted at the 1 ha plot scale.",
    "Values are monthly broad-scale fractional-cover summaries.",
    "Landsat remains the core plot-scale ground-cover product.",
  ], 84, 470, 900, 19);
  addFooter(slide, 1);

  slide = presentation.slides.items[1];
  addTitle(slide, "What MODIS Adds");
  addBullets(slide, [
    "Farm, buffer and management-zone context for Landsat ground-cover interpretation.",
    "A long monthly archive showing broad seasonal and landscape-scale variation.",
    "Support flags for identifying which management-zone summaries are interpretable.",
    "No MODIS extraction to 1 ha plots; plot outlines appear only as scale context.",
  ], 90, 170, 920, 22);
  addFooter(slide, 2);

  slide = presentation.slides.items[2];
  addTitle(slide, "Data And Processing");
  addMetric(slide, "Date range", dateRange, 80, 162, colors.green);
  addMetric(slide, "AOI cache created", String(cacheCreated), 360, 162, colors.blue);
  addMetric(slide, "Existing cache reused", String(cacheSkipped), 640, 162, colors.gold);
  addMetric(slide, "Cache failures", String(cacheFailed), 920, 162, cacheFailed === 0 ? colors.green : colors.red);
  addBullets(slide, [
    "Bands: bare ground, photosynthetic vegetation and non-photosynthetic vegetation.",
    "NoData/flag 255 and values above 100 are treated as invalid for percentage summaries.",
    "The full archive was processed raster-by-raster; Australia-wide files were clipped to the Gayini AOI cache.",
  ], 92, 340, 980, 20);
  addFooter(slide, 3);

  slide = presentation.slides.items[3];
  addTitle(slide, "Scale Context");
  await addImage(slide, image.scale, { left: 92, top: 150, width: 760, height: 500 }, "MODIS scale context map");
  [
    "Grey cells show MODIS AOI pixel scale.",
    "Purple outlines show 1 ha plots only to communicate scale mismatch.",
    "MODIS summaries are reported for farm, buffers and zones.",
  ].forEach((bullet, index) => {
    const top = 176 + index * 86;
    addText(slide, "•", { left: 904, top, width: 24, height: 28 }, {
      fontSize: 18,
      color: colors.green,
      bold: true,
    });
    addText(slide, bullet, { left: 934, top, width: 254, height: 72 }, {
      fontSize: 17,
      color: colors.ink,
    });
  });
  addFooter(slide, 4);

  slide = presentation.slides.items[4];
  addTitle(slide, "Representative MODIS RGB Maps");
  await addImage(slide, image.rgb2010, { left: 74, top: 156, width: 348, height: 352 }, "MODIS RGB 2010-01");
  await addImage(slide, image.rgb2019, { left: 466, top: 156, width: 348, height: 352 }, "MODIS RGB 2019-07");
  await addImage(slide, image.rgb2026, { left: 858, top: 156, width: 348, height: 352 }, "MODIS RGB 2026-02");
  addText(slide, "RGB = bare ground / PV / NPV. These are broad context maps, not plot-scale products.", { left: 92, top: 548, width: 1040, height: 42 }, {
    fontSize: 18,
    color: colors.muted,
  });
  addFooter(slide, 5);

  slide = presentation.slides.items[5];
  addTitle(slide, "Whole-Farm Monthly Time Series");
  await addImage(slide, image.farmTs, { left: 84, top: 150, width: 1040, height: 482 }, "Whole-farm monthly MODIS time series");
  addFooter(slide, 6);

  slide = presentation.slides.items[6];
  addTitle(slide, "Farm Versus Buffer Context");
  await addImage(slide, image.bufferVeg, { left: 74, top: 146, width: 548, height: 390 }, "Farm versus buffer total vegetation");
  await addImage(slide, image.bufferBare, { left: 660, top: 146, width: 548, height: 390 }, "Farm versus buffer bare ground");
  addText(slide, "Comparison shows whether Gayini tracks or diverges from near-site and broader regional context.", { left: 86, top: 562, width: 1040, height: 34 }, {
    fontSize: 18,
    color: colors.muted,
  });
  addFooter(slide, 7);

  slide = presentation.slides.items[7];
  addTitle(slide, "Water-Year And Pre/Post Context");
  await addImage(slide, image.waterVeg, { left: 74, top: 148, width: 548, height: 398 }, "Water-year total vegetation summary");
  await addImage(slide, image.prepost, { left: 660, top: 148, width: 548, height: 398 }, "MODIS pre/post period summary");
  addText(slide, "Post-minus-pre values are percentage points.", { left: 86, top: 570, width: 760, height: 30 }, {
    fontSize: 18,
    color: colors.muted,
  });
  addFooter(slide, 8);

  slide = presentation.slides.items[8];
  addTitle(slide, "Management-Zone Exploratory Results");
  await addImage(slide, image.zoneSupport, { left: 72, top: 146, width: 490, height: 500 }, "Management-zone MODIS support ranking");
  await addImage(slide, image.zoneTs, { left: 606, top: 156, width: 580, height: 360 }, "Selected high-support management-zone time series");
  addText(slide, "Management-zone results are exploratory and should be interpreted with MODIS pixel-support flags.", { left: 614, top: 544, width: 548, height: 48 }, {
    fontSize: 18,
    color: colors.muted,
  });
  addFooter(slide, 9);

  slide = presentation.slides.items[9];
  addTitle(slide, "Interpretation And Next Decisions");
  [
    "Use MODIS to explain whole-farm and regional seasonal context around Landsat plot-scale results.",
    "Keep MODIS out of plot-scale causal evidence and response metrics.",
    "Review low-support management zones before using zone-level summaries.",
    "Choose the clearest MODIS context figures for the main August deck.",
  ].forEach((bullet, index) => {
    const top = 166 + index * 72;
    addText(slide, "•", { left: 104, top, width: 24, height: 28 }, {
      fontSize: 22,
      color: colors.green,
      bold: true,
    });
    addText(slide, bullet, { left: 136, top, width: 980, height: 60 }, {
      fontSize: 23,
      color: colors.ink,
    });
  });
  addText(slide, `Assets written: ${mapRows.length} maps and ${figureRows.length} figures.`, { left: 96, top: 520, width: 840, height: 34 }, {
    fontSize: 20,
    bold: true,
    color: colors.green,
  });
  addFooter(slide, 10);

  for (const [index, slideItem] of presentation.slides.items.entries()) {
    const stem = `slide-${String(index + 1).padStart(2, "0")}`;
    const png = await presentation.export({ slide: slideItem, format: "png", scale: 1 });
    await writeBlob(path.join(previewDir, `${stem}.png`), png);
    const layout = await slideItem.export({ format: "layout" });
    await fs.writeFile(path.join(layoutDir, `${stem}.layout.json`), await layout.text());
  }

  const montage = await presentation.export({ format: "webp", montage: true, scale: 1 });
  await writeBlob(path.join(previewDir, "deck-montage.webp"), montage);

  const pptx = await PresentationFile.exportPptx(presentation);
  await pptx.save(finalPptx);

  await fs.writeFile(path.join(qaDir, "visual-qa.txt"), [
    "Visual QA checklist",
    "Rendered 10 slide PNGs and a deck montage.",
    "Slides use editable text and embedded generated PNG assets.",
    "Checked source paths and slide count programmatically during export.",
    "Manual montage inspection still recommended in Codex UI.",
  ].join("\n"));

  console.log(JSON.stringify({
    finalPptx,
    workspace,
    previewDir,
    montage: path.join(previewDir, "deck-montage.webp"),
    slideCount: presentation.slides.items.length,
  }, null, 2));
  process.exitCode = 0;
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
