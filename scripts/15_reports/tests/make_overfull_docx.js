/* Fixture generator: an A4 landscape page deliberately packed past the spill threshold.
   Used by test_page_fill_fires.py. Not part of the batch.
   Usage: node make_overfull_docx.js <outdir> */
const fs = require('fs'), path = require('path');
const { Document, Packer, Paragraph, TextRun, PageOrientation } = require('docx');

const outdir = process.argv[2];
const lines = [];
// Enough dense text to run content to the bottom margin. The check measures the lowest
// non-white row, so the page must be filled all the way down, not merely be long.
for (let i = 0; i < 46; i++) {
  lines.push(new Paragraph({
    children: [new TextRun({
      text: ('Deliberately over-full fixture line ' + i + '. ').repeat(6),
      font: 'Georgia', size: 20,
    })],
    spacing: { before: 0, after: 0, line: 240 },
  }));
}
const doc = new Document({
  sections: [{
    properties: { page: { size: { orientation: PageOrientation.LANDSCAPE },
                          margin: { top: 60, bottom: 60, left: 60, right: 60 } } },
    children: lines,
  }],
});
Packer.toBuffer(doc).then(b => {
  const p = path.join(outdir, 'FIXTURE_overfull.docx');
  fs.writeFileSync(p, b);
  console.log(p);
});
